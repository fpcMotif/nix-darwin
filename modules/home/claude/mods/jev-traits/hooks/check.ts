import { batches, chunk, probabilitiesOf, question, verdictFor } from './jev'
import type { Change, Judgment, Probabilities, Review, Settings, SystemOneReply, Work } from './jev'
import { appliesTo, relativeTo, TRAITS_DIR } from './traits'
import type { Trait } from './traits'

export const TARGETS = ['changed', 'staged', 'unstaged', 'untracked', 'files'] as const
export type Target = (typeof TARGETS)[number]

export const MAX_FILE_CHARS = 200_000
export const MAX_UNTRACKED = 200
export const MAX_IN_FLIGHT = 8
export const SKIP = new RegExp(
  `(^|/)(\\.git|node_modules|${TRAITS_DIR.replace('.', '\\.')})/|` +
    '(^|/)(package-lock\\.json|bun\\.lockb?|pnpm-lock\\.yaml|yarn\\.lock|Cargo\\.lock|uv\\.lock|poetry\\.lock)$',
)

export const UNTRACKED_ARGS = ['ls-files', '--others', '--exclude-standard', '-z']

export function diffArgs(staged: boolean): string[] {
  const args = ['diff', '--relative', '--no-color', '--no-ext-diff', '--no-textconv', '--no-renames']
  return staged ? [...args, '--cached'] : args
}

export function targetFrom(args: readonly string[]): { target: Target; files: string[] } {
  const named = TARGETS.find(one => one === args[0] && one !== 'files')
  if (named) return { target: named, files: [] }
  return args.length > 0 ? { target: 'files', files: [...args] } : { target: 'changed', files: [] }
}

export function diffChanges(text: string): Change[] {
  const changes: Change[] = []
  for (const section of text.split(/^(?=diff --git )/m)) {
    const path = /^\+\+\+ b\/(.+)$/m.exec(section)?.[1]
    if (path && /^\+(?!\+\+ )/m.test(section)) changes.push({ path, kind: 'diff', code: section })
  }
  return changes
}

export function untrackedPaths(text: string): string[] {
  return text.split('\0').filter(Boolean).slice(0, MAX_UNTRACKED)
}

export function isCheckable(text: unknown): text is string {
  return typeof text === 'string' && !text.includes('\u0000') && text.length <= MAX_FILE_CHARS
}

export function workFor(changes: readonly Change[], traits: readonly Trait[]): Work[] {
  return changes
    .filter(change => !SKIP.test(change.path))
    .flatMap(chunk)
    .map(change => ({ change, traits: traits.filter(trait => appliesTo(trait, change.path, change.code)) }))
    .filter(item => item.traits.length > 0)
}

export type Job = { readonly change: Change; readonly traits: Trait[] }

export function jobsFor(work: readonly Work[]): Job[] {
  return work.flatMap(item => batches(item.traits).map(traits => ({ change: item.change, traits })))
}

export function requestBody(settings: Settings, job: Job) {
  const questions = Object.fromEntries(job.traits.map((trait, i) => [`t${i}`, question(trait, job.change.kind)]))
  return { model: settings.model, state: { change: job.change }, questions }
}

export function judgmentsFrom(reply: SystemOneReply, job: Job, settings: Settings): Judgment[] {
  const answered = job.traits.map((trait, i) => ({ trait, probabilities: probabilitiesOf(reply.answers?.[`t${i}`]) }))
  if (answered.some(one => !one.probabilities)) throw new Error('TypeSafe returned an incomplete answer')
  return answered.map(({ trait, probabilities }) => {
    const p = probabilities as Probabilities
    return { trait, change: job.change, probabilities: p, verdict: verdictFor(p, settings) }
  })
}

export const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? '' : 's'}`

const VERDICT_ORDER = { fix: 0, check: 1, unsure: 2, pass: 3 } as const

export function formatReport(root: string, target: Target, result: Review, skipped: readonly string[]): string {
  const flagged = result.judgments
    .filter(j => j.verdict === 'fix' || j.verdict === 'check')
    .sort(
      (a, b) =>
        a.change.path.localeCompare(b.change.path) ||
        (a.change.excerpt?.index ?? 0) - (b.change.excerpt?.index ?? 0) ||
        VERDICT_ORDER[a.verdict] - VERDICT_ORDER[b.verdict],
    )
  const unsure = result.judgments.filter(j => j.verdict === 'unsure')
  const status =
    flagged.length > 0 ? 'violations' : unsure.length > 0 || result.errors.length > 0 ? 'inconclusive' : 'pass'
  const files = new Set([...result.judgments.map(j => j.change.path), ...result.errors.map(e => e.path)])
  const lines = [
    `jev-traits ${target}: ${status} · ${plural(result.judgments.length, 'judgment')} over ${plural(files.size, 'file')}` +
      ` · ${plural(result.requests, 'request')} · ${result.ms} ms${result.model ? ` · ${result.model}` : ''}`,
  ]
  let heading = ''
  for (const j of flagged) {
    const excerpt = j.change.excerpt ? ` [excerpt ${j.change.excerpt.index}/${j.change.excerpt.total}]` : ''
    if (`${j.change.path}${excerpt}` !== heading) {
      heading = `${j.change.path}${excerpt}`
      lines.push(heading)
    }
    lines.push(`  ${j.verdict.padEnd(6)} ${j.trait.id}  p(violation) ${j.probabilities.violation.toFixed(2)}: ${j.trait.title}`)
  }
  if (unsure.length > 0) {
    lines.push('Unsure, Jev lacked context:')
    const byPath = new Map<string, Judgment[]>()
    for (const j of unsure) byPath.set(j.change.path, [...(byPath.get(j.change.path) ?? []), j])
    for (const [path, judgments] of [...byPath].sort(([a], [b]) => a.localeCompare(b)))
      lines.push(`  ${path}: ${judgments.length} (${[...new Set(judgments.map(j => j.trait.id))].sort().join(', ')})`)
  }
  for (const path of new Set(result.errors.map(e => `${e.path} (${e.message})`))) lines.push(`Not checked: ${path}`)
  if (skipped.length > 0) lines.push(`Skipped, binary or too large: ${skipped.join(', ')}`)
  if (flagged.length > 0 || unsure.length > 0) {
    const traitFiles = new Set([...flagged, ...unsure].map(j => relativeTo(root, j.trait.path)))
    lines.push(`Trait files: ${[...traitFiles].join(', ')}`)
    lines.push(
      'These are fast model judgments. Read the trait and the code before changing anything, and report unsure results as unsure, not as passes.',
    )
  }
  return lines.join('\n')
}
