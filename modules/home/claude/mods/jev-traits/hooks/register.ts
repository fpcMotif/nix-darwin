import type { EngineInterface, FsEntry, PluginOptions, Register, Timer, ToolCallInput } from 'claude-code'

import {
  diffArgs,
  diffChanges,
  formatReport,
  isCheckable,
  jobsFor,
  judgmentsFrom,
  MAX_IN_FLIGHT,
  plural,
  requestBody,
  SKIP,
  TARGETS,
  targetFrom,
  UNTRACKED_ARGS,
  untrackedPaths,
  workFor,
} from './check'
import type { Job, Target } from './check'
import { chunk, ENDPOINT, headOf, KEYCHAIN_SERVICE, settingsFrom } from './jev'
import type { Change, ChangeKind, Judgment, Review, Settings, SystemOneReply, Work } from './jev'
import { appliesTo, dirOf, parseTrait, relativeTo, TRAITS_DIR } from './traits'
import type { Trait } from './traits'

const CHECK_TOOL = 'mcp__jev-traits__check_traits'

const EDIT_TIMEOUT_MS = 6_000
const CHECK_TIMEOUT_MS = 8_000
const MAX_EDIT_CHUNKS = 4

const KEY_HELP = [
  'jev-traits found no TypeSafe API key. Store it once, by hand, in the macOS Keychain (jev-lint reads the same item):',
  '',
  `  security add-generic-password -U -a "$USER" -s ${KEYCHAIN_SERVICE} -w`,
  '',
  'The command prompts for the key, so it stays out of your shell history and this chat. Then run /traits again.',
  'Or export TYPESAFE_API_KEY before starting Claude Code, or set the typesafe_api_key option',
  '(kept in secure storage) once the plugin is installed from a marketplace.',
].join('\n')

type Entry = { readonly at: number; readonly line: string }
const history: Entry[] = []
const parsedTraits = new Map<string, { stamp: string; trait: Trait }>()
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

async function loadTrait($: EngineInterface, group: string, path: string, entry: FsEntry): Promise<Trait> {
  const stamp = `${entry.size}:${entry.mtimeMs}`
  const known = parsedTraits.get(path)
  if (known?.stamp === stamp) return known.trait
  const trait = parseTrait(`${group}/${entry.name.slice(0, -'.md'.length)}`, path, await $.fs.read(path))
  parsedTraits.set(path, { stamp, trait })
  return trait
}

async function loadTraits($: EngineInterface, root: string): Promise<Trait[]> {
  const base = `${root}/${TRAITS_DIR}`
  const groups = (await listDir($, base)).filter(
    entry => (entry.kind === 'dir' || entry.isLink) && !entry.name.startsWith('.'),
  )
  const traits: Trait[] = []
  for (const group of groups) {
    const files = (await listDir($, `${base}/${group.name}`)).filter(
      entry => entry.kind === 'file' && entry.name.endsWith('.md'),
    )
    for (const file of files) traits.push(await loadTrait($, group.name, `${base}/${group.name}/${file.name}`, file))
  }
  return traits.sort((a, b) => a.id.localeCompare(b.id))
}

async function apiKey($: EngineInterface, options: PluginOptions): Promise<ApiKey | undefined> {
  const option = typeof options.typesafe_api_key === 'string' ? options.typesafe_api_key.trim() : ''
  if (option) return { key: option, source: 'the typesafe_api_key plugin option' }
  if (cachedKey) return cachedKey
  if (Date.now() - lastKeyMissAt < 30_000) return undefined
  const fromEnv = (await $.env.get('TYPESAFE_API_KEY'))?.trim()
  if (fromEnv) return (cachedKey = { key: fromEnv, source: 'TYPESAFE_API_KEY' })
  const keychain = await $.process
    .run(['security', 'find-generic-password', '-s', KEYCHAIN_SERVICE, '-w'], { timeoutMs: 3000 })
    .catch(() => undefined)
  const fromKeychain = keychain?.exitCode === 0 ? keychain.stdout.trim() : ''
  if (fromKeychain) return (cachedKey = { key: fromKeychain, source: `the Keychain item ${KEYCHAIN_SERVICE}` })
  lastKeyMissAt = Date.now()
  return undefined
}

function forgetKey() {
  cachedKey = undefined
  lastKeyMissAt = -Infinity
}

async function review(
  $: EngineInterface,
  key: string,
  settings: Settings,
  work: readonly Work[],
  timeoutMs: number,
): Promise<Review> {
  const startedAt = Date.now()
  const jobs = jobsFor(work)
  const judgments: Judgment[] = []
  const errors: { path: string; message: string }[] = []
  let model: string | undefined
  let inputTokens = 0

  let timer: Timer | undefined
  const deadline = new Promise<'timeout'>(resolve => {
    timer = $.clock.after(timeoutMs, () => resolve('timeout'))
  })

  const ask = async (job: Job) => {
    const request = $.http.fetch(ENDPOINT, {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody(settings, job)),
    })
    const response = await Promise.race([request, deadline])
    if (response === 'timeout') throw new Error(`TypeSafe timed out after ${timeoutMs} ms`)
    if (response.status === 401) {
      forgetKey()
      throw new Error('TypeSafe rejected the API key (401), see /traits')
    }
    if (!response.ok) throw new Error(`TypeSafe ${response.status}`)
    const reply = JSON.parse(response.text) as SystemOneReply
    model = reply.model ?? model
    inputTokens += reply.usage?.input_tokens ?? 0
    judgments.push(...judgmentsFrom(reply, job, settings))
  }

  let next = 0
  const worker = async () => {
    while (next < jobs.length) {
      const job = jobs[next++]
      if (!job) return
      await ask(job).catch((error: unknown) => {
        errors.push({ path: job.change.path, message: errorText(error) })
      })
    }
  }
  try {
    await Promise.all(Array.from({ length: Math.min(MAX_IN_FLIGHT, jobs.length) }, worker))
  } finally {
    timer?.cancel()
  }
  return { judgments, errors, model, requests: jobs.length, inputTokens, ms: Date.now() - startedAt }
}

const errorText = (error: unknown) => (error instanceof Error ? error.message : String(error))
const shortPath = (path: string) => (path.length > 44 ? `…${path.slice(-43)}` : path)

function editedChange(e: ToolCallInput): Change | undefined {
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

function editStatus(rel: string, result: Review, asked: number): string {
  const first = result.errors[0]
  if (first && result.judgments.length === 0) return `jev: ${first.message}; ${shortPath(rel)} unchecked`
  const flagged = flaggedByTrait(result)
  const fixes = flagged.filter(j => j.verdict === 'fix').length
  const checks = flagged.length - fixes
  const head = fixes > 0 ? `jev ⚠ ${fixes} to fix` : checks > 0 ? `jev ? ${checks} to double-check` : 'jev ✓'
  return `${head} · ${shortPath(rel)} · ${plural(asked, 'trait')} · ${result.ms} ms${result.errors.length > 0 ? ' · partial' : ''}`
}

function feedbackFor(root: string, rel: string, kind: ChangeKind, result: Review): string | undefined {
  const flagged = flaggedByTrait(result)
  if (flagged.length === 0) return undefined
  const line = (j: Judgment) =>
    `  - ${j.trait.id} (p=${j.probabilities.violation.toFixed(2)}): ${j.trait.title} [${relativeTo(root, j.trait.path)}]`
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

async function gather(
  $: EngineInterface,
  root: string,
  target: Target,
  files: readonly string[],
): Promise<{ changes: Change[]; skipped: string[] }> {
  const changes: Change[] = []
  const skipped: string[] = []
  const git = async (args: string[]) => {
    const ran = await $.process.run(['git', ...args], { cwd: root, timeoutMs: 15_000 })
    if (ran.exitCode !== 0) throw new Error(`git ${args[0]} failed: ${ran.stderr.trim().split('\n')[0] ?? ''}`)
    return ran.stdout
  }
  const readWhole = async (rel: string) => {
    const text = await $.fs.read(`${root}/${rel}`).catch(() => undefined)
    if (isCheckable(text)) changes.push({ path: rel, kind: 'file', code: text })
    else skipped.push(rel)
  }
  if (target === 'files')
    for (const file of files) await readWhole(relativeTo(root, file.startsWith('/') ? file : `${root}/${file}`))
  if (target === 'staged' || target === 'changed') changes.push(...diffChanges(await git(diffArgs(true))))
  if (target === 'unstaged' || target === 'changed') changes.push(...diffChanges(await git(diffArgs(false))))
  if (target === 'untracked' || target === 'changed')
    for (const rel of untrackedPaths(await git(UNTRACKED_ARGS))) await readWhole(rel)
  return { changes, skipped }
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
  const traits = await loadTraits($, root)
  if (traits.length === 0) return undefined
  const chunks = chunk({ ...edited, path: rel })
  if (chunks.length > MAX_EDIT_CHUNKS) {
    report($, `jev: ${shortPath(rel)} is too large to check per edit; use /traits check`)
    return undefined
  }
  const work: Work[] = chunks
    .map(change => ({ change, traits: traits.filter(trait => appliesTo(trait, rel, change.code)) }))
    .filter(item => item.traits.length > 0)
  if (work.length === 0) {
    report($, `jev · ${shortPath(rel)}: no trait applies`)
    return undefined
  }
  const key = await apiKey($, options)
  if (!key) {
    report($, 'jev: no TypeSafe API key; run /traits')
    return undefined
  }
  const written = edited.kind === 'edit' ? await $.fs.read(edited.path).catch(() => undefined) : undefined
  const head = typeof written === 'string' ? headOf(written) : undefined
  const judged = head ? work.map(item => ({ ...item, change: { ...item.change, head } })) : work
  const result = await review($, key.key, settingsFrom(options), judged, EDIT_TIMEOUT_MS)
  const asked = new Set(work.flatMap(item => item.traits.map(trait => trait.id))).size
  report($, editStatus(rel, result, asked))
  return feedbackFor(root, rel, edited.kind, result)
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
  if (!root) return `No ${TRAITS_DIR} folder at or above ${start}. Add a trait as ${TRAITS_DIR}/project/<name>.md first.`
  const all = await loadTraits($, root)
  const traits = traitId ? all.filter(trait => trait.id === traitId) : all
  if (traits.length === 0) return traitId ? `No trait ${traitId} in ${root}/${TRAITS_DIR}.` : `No traits in ${root}/${TRAITS_DIR}.`
  const key = await apiKey($, options)
  if (!key) return KEY_HELP
  const { changes, skipped } = await gather($, root, target, files)
  const work = workFor(changes, traits)
  if (work.length === 0)
    return `jev-traits ${target}: nothing to check (${changes.length > 0 ? 'no trait applies to the changes' : 'no changes'}).`
  const result = await review($, key.key, settingsFrom(options), work, CHECK_TIMEOUT_MS)
  return formatReport(root, target, result, skipped)
}

async function summary($: EngineInterface, options: PluginOptions): Promise<string> {
  const settings = settingsFrom(options)
  forgetKey()
  const key = await apiKey($, options)
  const sessionRoot = await $.session.root()
  const root = await findRoot($, sessionRoot)
  const traits: Trait[] = root ? await loadTraits($, root) : []
  const describe = (trait: Trait) =>
    `  ${trait.id}: ${trait.title}` +
    (trait.paths.length > 0 ? ` [paths: ${trait.paths.join(', ')}]` : '') +
    (trait.when.length > 0 ? ` [when: ${plural(trait.when.length, 'pattern')}]` : '')
  return [
    `jev-traits · ${settings.model} · fix ≥ ${settings.fix} · double-check ≥ ${settings.check} · pass ≥ ${settings.pass}` +
      ` · edits ${options.check_edits === false ? 'not checked' : 'checked'}`,
    key ? `Key: from ${key.source}.` : KEY_HELP,
    root
      ? `Traits: ${traits.length} in ${root}/${TRAITS_DIR}`
      : `Traits: no ${TRAITS_DIR} folder at or above ${sessionRoot}. Add one as ${TRAITS_DIR}/project/<name>.md.`,
    ...traits.map(describe),
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
        "Checks code against this repository's traits (.agents/traits/<group>/*.md) with TypeSafe Jev. " +
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
            description: 'Paths relative to the folder holding .agents/, or absolute; for target files',
          },
          trait: { type: 'string', description: 'Check one trait only, as group/name (for example project/no_default_exports)' },
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
