import type { EngineInterface, FsEntry, PluginOptions, Register, ToolCallInput } from 'claude-code'

import {
  dirOf,
  editArgs,
  failureText,
  formatReport,
  judged,
  KEYCHAIN_SERVICE,
  plural,
  relativeTo,
  reviewFrom,
  settingsFrom,
  SKIP,
  TARGETS,
  targetArgs,
  targetFrom,
  traitFile,
  TRAITS_DIR,
} from './check'
import type { ChangeKind, Judgment, Review, Target } from './check'

const CHECK_TOOL = 'mcp__jev-traits__check_traits'

const EDIT_TIMEOUT_MS = 6_000
const CHECK_TIMEOUT_MS = 8_000
const LS_TIMEOUT_MS = 5_000
const MAX_EDIT_CHARS = 48_000

const KEY_HELP = [
  'jev-traits found no TypeSafe API key. Store it once, by hand, in the macOS Keychain (jev-lint reads the same item):',
  '',
  `  security add-generic-password -U -a "$USER" -s ${KEYCHAIN_SERVICE} -w`,
  '',
  'The command prompts for the key, so it stays out of your shell history and this chat. Then run /traits again.',
  'Lookup order: the typesafe_api_key option (kept in secure storage, once the plugin is installed from a marketplace),',
  `then the Keychain item ${KEYCHAIN_SERVICE}, then TYPESAFE_API_KEY as a fallback for machines without the item, such as CI.`,
  'Do not keep the key in a .env file.',
].join('\n')

type Entry = { readonly at: number; readonly line: string }
const history: Entry[] = []
type ApiKey = { readonly key: string; readonly source: string }
let cachedKey: ApiKey | undefined
let lastKeyMissAt = -Infinity

async function findRoot($: EngineInterface, from: string): Promise<string | undefined> {
  for (let dir = from; ; dir = dirOf(dir)) {
    if (await $.fs.exists(`${dir}/${TRAITS_DIR}`)) return dir
    if (dir === '/') return undefined
  }
}

async function listDir($: EngineInterface, path: string): Promise<FsEntry[]> {
  return $.fs.list(path).catch((): FsEntry[] => [])
}

// The CLI exits 2 without a key even when no trait exists, so an empty store
// must not reach it.
async function hasTraits($: EngineInterface, root: string): Promise<boolean> {
  const base = `${root}/${TRAITS_DIR}`
  const isTrait = (entry: FsEntry) => entry.kind === 'file' && entry.name.endsWith('.md')
  const entries = await listDir($, base)
  if (entries.some(isTrait)) return true
  for (const group of entries)
    if ((group.kind === 'dir' || group.isLink) && !group.name.startsWith('.'))
      if ((await listDir($, `${base}/${group.name}`)).some(isTrait)) return true
  return false
}

async function apiKey($: EngineInterface, options: PluginOptions): Promise<ApiKey | undefined> {
  const option = typeof options.typesafe_api_key === 'string' ? options.typesafe_api_key.trim() : ''
  if (option) return { key: option, source: 'the typesafe_api_key plugin option' }
  if (cachedKey) return cachedKey
  if (Date.now() - lastKeyMissAt < 30_000) return undefined
  const keychain = await $.process
    .run(['security', 'find-generic-password', '-s', KEYCHAIN_SERVICE, '-w'], { timeoutMs: 3000 })
    .catch(() => undefined)
  const fromKeychain = keychain?.exitCode === 0 ? keychain.stdout.trim() : ''
  if (fromKeychain) return (cachedKey = { key: fromKeychain, source: `the Keychain item ${KEYCHAIN_SERVICE}` })
  // The Keychain wins so a key that direnv, mise or bun loads from a plaintext
  // .env cannot override it; the env var only serves machines without the item.
  const fromEnv = (await $.env.get('TYPESAFE_API_KEY'))?.trim()
  if (fromEnv) return (cachedKey = { key: fromEnv, source: 'TYPESAFE_API_KEY (fallback, no Keychain item)' })
  lastKeyMissAt = Date.now()
  return undefined
}

function forgetKey() {
  cachedKey = undefined
  lastKeyMissAt = -Infinity
}

// Home Manager sets TRAITS_BIN to the store path, since a GUI-launched Claude
// Code may not have the Nix profile on PATH.
async function traitsBin($: EngineInterface): Promise<string> {
  return (await $.env.get('TRAITS_BIN'))?.trim() || 'traits'
}

type Run = { readonly ok: true; readonly review: Review } | { readonly ok: false; readonly message: string }

async function runTraits(
  $: EngineInterface,
  root: string,
  args: readonly string[],
  init: { key?: string; stdin?: string; timeoutMs: number },
): Promise<Run> {
  const startedAt = Date.now()
  const ran = await $.process
    .run([await traitsBin($), ...args], {
      cwd: root,
      timeoutMs: init.timeoutMs,
      ...(init.key === undefined ? {} : { env: { TYPESAFE_API_KEY: init.key } }),
      ...(init.stdin === undefined ? {} : { stdin: init.stdin }),
    })
    .catch((error: unknown) => errorText(error))
  if (typeof ran === 'string')
    return /time/i.test(ran)
      ? { ok: false, message: `traits did not finish within ${init.timeoutMs / 1000} s` }
      : { ok: false, message: `could not run traits: ${ran}` }
  if (ran.exitCode !== 0 && ran.exitCode !== 1) {
    if (/\b401\b|unauthori[sz]ed/i.test(ran.stderr)) forgetKey()
    return { ok: false, message: failureText(ran.stderr) }
  }
  try {
    return { ok: true, review: reviewFrom(root, ran.stdout, Date.now() - startedAt) }
  } catch {
    return { ok: false, message: 'traits printed no JSON report' }
  }
}

const errorText = (error: unknown) => (error instanceof Error ? error.message : String(error))
const shortPath = (path: string) => (path.length > 44 ? `…${path.slice(-43)}` : path)

type EditedChange = { readonly path: string; readonly kind: ChangeKind; readonly code: string }

function editedChange(e: ToolCallInput): EditedChange | undefined {
  if (e.tool === 'Edit') return { path: e.file_path, kind: 'edit', code: e.new_string }
  if (e.tool === 'Write') return { path: e.file_path, kind: 'write', code: e.content }
  if (e.tool === 'NotebookEdit' && e.edit_mode !== 'delete')
    return { path: e.notebook_path, kind: 'edit', code: e.new_source }
  return undefined
}

function flaggedByTrait(result: Review): Judgment[] {
  const worst = new Map<string, Judgment>()
  for (const judgment of result.judgments) {
    if (judgment.verdict !== 'fix' && judgment.verdict !== 'check') continue
    const seen = worst.get(judgment.trait.id)
    if (!seen || seen.probabilities.violation < judgment.probabilities.violation) worst.set(judgment.trait.id, judgment)
  }
  return [...worst.values()].sort((a, b) => b.probabilities.violation - a.probabilities.violation)
}

function editStatus(rel: string, result: Review): string {
  const flagged = flaggedByTrait(result)
  const fixes = flagged.filter(j => j.verdict === 'fix').length
  const checks = flagged.length - fixes
  const head = fixes > 0 ? `jev ⚠ ${fixes} to fix` : checks > 0 ? `jev ? ${checks} to double-check` : 'jev ✓'
  return `${head} · ${shortPath(rel)} · ${plural(judged(result), 'judgment')} · ${result.ms} ms`
}

function feedbackFor(rel: string, kind: ChangeKind, result: Review): string | undefined {
  const flagged = flaggedByTrait(result)
  if (flagged.length === 0) return undefined
  const line = (j: Judgment) =>
    `  - ${j.trait.id} (p=${j.probabilities.violation.toFixed(2)}): ${j.trait.title} [${traitFile(j.trait.id)}]`
  const fixes = flagged.filter(j => j.verdict === 'fix')
  const checks = flagged.filter(j => j.verdict === 'check')
  const scope = kind === 'write' ? 'the whole file this write produced' : 'the code this edit added'
  return [
    `jev-traits checked ${scope} at ${rel} against the repository's traits.`,
    ...(fixes.length > 0 ? ['Likely violations, fix these:', ...fixes.map(line)] : []),
    ...(checks.length > 0 ? ['Possible violations, double-check and keep the code if it is fine:', ...checks.map(line)] : []),
    'These are fast model judgments and can be wrong: read the trait file before changing code.',
  ].join('\n')
}

function report($: EngineInterface, line: string) {
  history.push({ at: Date.now(), line })
  history.splice(0, Math.max(0, history.length - 50))
  $.ui.status(line)
}

async function checkEdit($: EngineInterface, options: PluginOptions, e: ToolCallInput): Promise<string | undefined> {
  const edited = editedChange(e)
  if (!edited || !edited.code.trim()) return undefined
  const root = await findRoot($, dirOf(edited.path))
  if (!root) return undefined
  const rel = relativeTo(root, edited.path)
  if (SKIP.test(rel)) return undefined
  if (!(await hasTraits($, root))) return undefined
  if (edited.code.length > MAX_EDIT_CHARS) {
    report($, `jev: ${shortPath(rel)} is too large to check per edit; use /traits check`)
    return undefined
  }
  const key = await apiKey($, options)
  if (!key) {
    report($, 'jev: no TypeSafe API key; run /traits')
    return undefined
  }
  const ran = await runTraits($, root, editArgs(rel, edited.kind, settingsFrom(options)), {
    key: key.key,
    stdin: edited.code,
    timeoutMs: EDIT_TIMEOUT_MS,
  })
  if (!ran.ok) {
    report($, `jev: ${ran.message}; ${shortPath(rel)} not checked`)
    return undefined
  }
  if (judged(ran.review) === 0) {
    report($, `jev · ${shortPath(rel)}: no trait applies`)
    return undefined
  }
  report($, editStatus(rel, ran.review))
  return feedbackFor(rel, edited.kind, ran.review)
}

async function checkTarget(
  $: EngineInterface,
  options: PluginOptions,
  target: Target,
  files: readonly string[],
  traitId?: string,
  path?: string,
): Promise<string> {
  const sessionRoot = await $.session.root()
  const start = path
    ? path.startsWith('/') ? path : `${sessionRoot}/${path}`
    : (files.find(file => file.startsWith('/')) ?? sessionRoot)
  const root = await findRoot($, start)
  if (!root) return `No ${TRAITS_DIR} folder at or above ${start}. Add a trait as ${TRAITS_DIR}/<name>.md first.`
  if (!(await hasTraits($, root))) return `No traits in ${root}/${TRAITS_DIR}.`
  const key = await apiKey($, options)
  if (!key) return KEY_HELP
  const settings = settingsFrom(options)
  const ran = await runTraits($, root, targetArgs(root, target, files, settings, traitId), {
    key: key.key,
    timeoutMs: CHECK_TIMEOUT_MS,
  })
  if (!ran.ok) return `jev-traits ${target}: not checked, ${ran.message}.`
  if (judged(ran.review) === 0)
    return `jev-traits ${target}: nothing to check (${ran.review.files > 0 ? 'no trait applies to the changes' : 'no changes'}).`
  return formatReport(target, settings, ran.review)
}

async function storedTraits($: EngineInterface, root: string): Promise<string[]> {
  const ran = await $.process
    .run([await traitsBin($), 'ls', '--json'], { cwd: root, timeoutMs: LS_TIMEOUT_MS })
    .catch((error: unknown) => errorText(error))
  if (typeof ran === 'string') return [`  traits ls failed: ${ran}`]
  if (ran.exitCode !== 0) return [`  traits ls failed: ${failureText(ran.stderr)}`]
  try {
    const traits = JSON.parse(ran.stdout) as { name: string; path: string }[]
    return traits.map(trait => `  ${trait.name}: ${relativeTo(root, trait.path)}`)
  } catch {
    return ['  traits ls printed no JSON list']
  }
}

async function summary($: EngineInterface, options: PluginOptions): Promise<string> {
  const settings = settingsFrom(options)
  forgetKey()
  const key = await apiKey($, options)
  const sessionRoot = await $.session.root()
  const root = await findRoot($, sessionRoot)
  const traits = root && (await hasTraits($, root)) ? await storedTraits($, root) : []
  return [
    `jev-traits · ${settings.model} · fix ≥ ${settings.fix} · double-check ≥ ${settings.check} · pass ≥ ${settings.pass}` +
      ` · edits ${options.check_edits === false ? 'not checked' : 'checked'}`,
    key ? `Key: from ${key.source}.` : KEY_HELP,
    root
      ? `Traits: ${traits.length} in ${root}/${TRAITS_DIR}`
      : `Traits: no ${TRAITS_DIR} folder at or above ${sessionRoot}. Add one as ${TRAITS_DIR}/<name>.md.`,
    ...traits,
    ...(history.length > 0
      ? ['Recent checks:', ...history.slice(-10).map(entry => `  ${new Date(entry.at).toTimeString().slice(0, 8)}  ${entry.line}`)]
      : []),
    'Run /traits check [changed|staged|unstaged|untracked|<files…>] to check work in progress.',
  ].join('\n')
}

export const register: Register = (on, options: PluginOptions) => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'traits',
      description: 'Show jev-traits status, or check changes against the repository traits',
      argumentHint: '[check [changed|staged|unstaged|untracked|<files…>]]',
    })
    await $.tool.register({
      name: 'check_traits',
      description:
        "Checks code against this repository's traits (.agents/traits/*.md and .agents/traits/<group>/*.md) with the traits CLI and TypeSafe Jev. " +
        'Use it before committing (target staged), after adding or revising a trait, or to audit files. ' +
        'Findings are fast model judgments: read the trait and the code before changing anything, ' +
        'and report unsure results as unsure, never as passes.',
      inputSchema: {
        type: 'object',
        properties: {
          target: {
            type: 'string',
            enum: [...TARGETS],
            description: 'changed = staged + unstaged + untracked; files = the whole files listed in `files`',
          },
          files: {
            type: 'array',
            items: { type: 'string' },
            description: 'Paths or globs relative to the folder holding .agents/, or absolute; for target files',
          },
          trait: {
            type: 'string',
            description: 'Check one trait only, by name, or group/name for a grouped trait (for example project/no_default_exports)',
          },
          path: {
            type: 'string',
            description:
              'A folder or file inside the repository to check, absolute or relative to the session folder. ' +
              'Needed when the session was opened above the repository; defaults to the session folder.',
          },
        },
        required: ['target'],
      },
      isDeferred: false,
    })
    return next(e)
  })

  on('tool.call', { tool: ['Edit', 'Write', 'NotebookEdit'] }, async ($, e, next) => {
    const ran = await next(e)
    if (options.check_edits === false || ran.deny !== undefined || ran.isError) return ran
    if ((ran.result as { staged?: boolean } | undefined)?.staged) return ran
    const feedback = await checkEdit($, options, e).catch((error: unknown) => {
      report($, `jev: ${errorText(error)}; edit not checked`)
      return undefined
    })
    return feedback ? { ...ran, context: [...(ran.context ?? []), feedback] } : ran
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: CHECK_TOOL }, async ($, e) => {
    const input = e as unknown as { target?: unknown; files?: unknown; trait?: unknown; path?: unknown }
    const target = TARGETS.find(one => one === input.target) ?? 'changed'
    const files = Array.isArray(input.files) ? input.files.filter((f): f is string => typeof f === 'string') : []
    const trait = typeof input.trait === 'string' && input.trait ? input.trait : undefined
    const path = typeof input.path === 'string' && input.path ? input.path : undefined
    const text = await checkTarget($, options, target, files, trait, path).catch(
      (error: unknown) => `jev-traits could not check: ${errorText(error)}`,
    )
    return { result: text }
  }).catch(() => ({ result: 'jev-traits could not check: the check did not finish in time.' }))

  on('command.run', { command: 'traits' }, async ($, e) => {
    const [sub, ...rest] = e.args.trim().split(/\s+/).filter(Boolean)
    if (sub !== 'check') return { text: await summary($, options) }
    const { target, files } = targetFrom(rest)
    const text = await checkTarget($, options, target, files).catch(
      (error: unknown) => `jev-traits could not check: ${errorText(error)}`,
    )
    return { text }
  })
}
