export const TRAITS_DIR = '.agents/traits'
export const KEYCHAIN_SERVICE = 'typesafe-api-key'
export const DEFAULT_MODEL = 'jev-latest'

export const TARGETS = ['changed', 'staged', 'unstaged', 'untracked', 'files'] as const
export type Target = (typeof TARGETS)[number]

export const SKIP = new RegExp(
  `(^|/)(\\.git|node_modules|${TRAITS_DIR.replace('.', '\\.')})/|` +
    '(^|/)(package-lock\\.json|bun\\.lockb?|pnpm-lock\\.yaml|yarn\\.lock|Cargo\\.lock|uv\\.lock|poetry\\.lock)$',
)

export type ChangeKind = 'edit' | 'write'
export type Verdict = 'fix' | 'check' | 'unsure' | 'pass'
export type Probabilities = {
  readonly compliant: number
  readonly violation: number
  readonly 'not-applicable': number
  readonly inconclusive: number
}
export type Judgment = {
  readonly trait: { readonly id: string; readonly title: string }
  readonly path: string
  readonly line?: number
  readonly probabilities: Probabilities
  readonly verdict: Verdict
}
export type Review = {
  readonly judgments: Judgment[]
  readonly verdicts: Readonly<Record<Verdict, number>>
  readonly files: number
  readonly requests: number
  readonly ms: number
}
export type Settings = {
  readonly model: string
  readonly fix: number
  readonly check: number
  readonly pass: number
}

export const dirOf = (path: string) => path.slice(0, Math.max(path.lastIndexOf('/'), 0)) || '/'

export const relativeTo = (root: string, path: string) =>
  path.startsWith(`${root}/`) ? path.slice(root.length + 1) : path

export const traitFile = (id: string) => `${TRAITS_DIR}/${id}.md`

export function settingsFrom(options: Readonly<Record<string, unknown>>): Settings {
  const fraction = (value: unknown, fallback: number) =>
    typeof value === 'number' && value >= 0 && value <= 1 ? value : fallback
  return {
    model: typeof options.model === 'string' && options.model.trim() ? options.model.trim() : DEFAULT_MODEL,
    fix: fraction(options.fix_threshold, 0.8),
    check: fraction(options.check_threshold, 0.5),
    pass: fraction(options.pass_threshold, 0.9),
  }
}

// A traits.ts that exports a fixed decision-model Layer rejects --model, so the
// default model is left to the CLI.
export function settingsArgs(settings: Settings): string[] {
  return [
    ...(settings.model === DEFAULT_MODEL ? [] : ['--model', settings.model]),
    '--fix-threshold', String(settings.fix),
    '--check-threshold', String(settings.check),
    '--pass-threshold', String(settings.pass),
    '--fail-on', 'never',
    '--json',
    '--quiet',
  ]
}

export function editArgs(rel: string, kind: ChangeKind, settings: Settings): string[] {
  return ['check', '--stdin', '--stdin-filepath', rel, '--kind', kind, ...settingsArgs(settings)]
}

export function targetArgs(
  root: string,
  target: Target,
  files: readonly string[],
  settings: Settings,
  traitId?: string,
): string[] {
  const selection =
    target === 'files'
      ? files.flatMap(file => ['--include', file.startsWith('/') ? file : `${root}/${file}`])
      : ['--target', target]
  return ['check', '--path', root, ...selection, ...(traitId ? ['--trait', traitId] : []), ...settingsArgs(settings)]
}

export function targetFrom(args: readonly string[]): { target: Target; files: string[] } {
  const named = TARGETS.find(one => one === args[0] && one !== 'files')
  if (named) return { target: named, files: [] }
  return args.length > 0 ? { target: 'files', files: [...args] } : { target: 'changed', files: [] }
}

type CliFinding = {
  trait: { name: string; purpose?: string }
  source: { location?: { _tag: string; path?: string; startLine?: number } }
  assessment: { probabilities: Probabilities; verdict: Verdict }
}
type CliReport = {
  findings: CliFinding[]
  summary: { files: number; requests: number; verdicts: Record<Verdict, number> }
}

export function reviewFrom(root: string, stdout: string, ms: number): Review {
  const report = JSON.parse(stdout) as CliReport
  return {
    judgments: report.findings.map(finding => {
      const location = finding.source.location
      const file = location?._tag === 'File' ? location : undefined
      return {
        trait: { id: finding.trait.name, title: finding.trait.purpose ?? finding.trait.name },
        path: file?.path ? relativeTo(root, file.path) : '(generated)',
        ...(file?.startLine === undefined ? {} : { line: file.startLine }),
        probabilities: finding.assessment.probabilities,
        verdict: finding.assessment.verdict,
      }
    }),
    verdicts: report.summary.verdicts,
    files: report.summary.files,
    requests: report.summary.requests,
    ms,
  }
}

export const judged = (review: Review) =>
  review.verdicts.fix + review.verdicts.check + review.verdicts.unsure + review.verdicts.pass

export function failureText(stderr: string): string {
  const line = stderr.split('\n').map(text => text.trim()).find(Boolean) ?? 'traits failed'
  return line.length > 200 ? `${line.slice(0, 199)}…` : line
}

export const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? '' : 's'}`

const VERDICT_ORDER = { fix: 0, check: 1, unsure: 2, pass: 3 } as const

export function formatReport(target: Target, settings: Settings, result: Review): string {
  const flagged = result.judgments
    .filter(j => j.verdict === 'fix' || j.verdict === 'check')
    .sort(
      (a, b) =>
        a.path.localeCompare(b.path) || (a.line ?? 0) - (b.line ?? 0) || VERDICT_ORDER[a.verdict] - VERDICT_ORDER[b.verdict],
    )
  const unsure = result.judgments.filter(j => j.verdict === 'unsure')
  const status = flagged.length > 0 ? 'violations' : unsure.length > 0 ? 'inconclusive' : 'pass'
  const lines = [
    `jev-traits ${target}: ${status} · ${plural(judged(result), 'judgment')} over ${plural(result.files, 'file')}` +
      ` · ${plural(result.requests, 'request')} · ${result.ms} ms · ${settings.model}`,
  ]
  let heading = ''
  for (const j of flagged) {
    const at = j.line === undefined ? j.path : `${j.path}:${j.line}`
    if (at !== heading) {
      heading = at
      lines.push(heading)
    }
    lines.push(`  ${j.verdict.padEnd(6)} ${j.trait.id}  p(violation) ${j.probabilities.violation.toFixed(2)}: ${j.trait.title}`)
  }
  if (unsure.length > 0) {
    lines.push('Unsure, Jev lacked context:')
    const byPath = new Map<string, Judgment[]>()
    for (const j of unsure) byPath.set(j.path, [...(byPath.get(j.path) ?? []), j])
    for (const [path, judgments] of [...byPath].sort(([a], [b]) => a.localeCompare(b)))
      lines.push(`  ${path}: ${judgments.length} (${[...new Set(judgments.map(j => j.trait.id))].sort().join(', ')})`)
  }
  if (flagged.length > 0 || unsure.length > 0) {
    const traitFiles = new Set([...flagged, ...unsure].map(j => traitFile(j.trait.id)))
    lines.push(`Trait files: ${[...traitFiles].join(', ')}`)
    lines.push(
      'These are fast model judgments. Read the trait and the code before changing anything, and report unsure results as unsure, not as passes.',
    )
  }
  return lines.join('\n')
}
