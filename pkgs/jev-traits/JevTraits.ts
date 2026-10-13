import { Clock, Config, Console, Data, Effect, FileSystem, Option, Path, Redacted, Result, Runtime, Schedule, Stream } from 'effect'
import { Argument, Command, Flag } from 'effect/cli'
import { HttpClient, HttpClientRequest } from 'effect/http'
import { ChildProcess, ChildProcessSpawner } from 'effect/process'

import {
  diffArgs,
  diffChanges,
  formatReport,
  isCheckable,
  jobsFor,
  judgmentsFrom,
  MAX_IN_FLIGHT,
  requestBody,
  targetFrom,
  UNTRACKED_ARGS,
  untrackedPaths,
  workFor,
} from '../../modules/home/claude/mods/jev-traits/hooks/check.ts'
import type { Job, Target } from '../../modules/home/claude/mods/jev-traits/hooks/check.ts'
import { ENDPOINT, KEYCHAIN_SERVICE, settingsFrom } from '../../modules/home/claude/mods/jev-traits/hooks/jev.ts'
import type { Change, Review, Settings, SystemOneReply, Work } from '../../modules/home/claude/mods/jev-traits/hooks/jev.ts'
import { dirOf, parseTrait, relativeTo, TRAITS_DIR } from '../../modules/home/claude/mods/jev-traits/hooks/traits.ts'
import type { Trait } from '../../modules/home/claude/mods/jev-traits/hooks/traits.ts'

const REQUEST_TIMEOUT_MS = 20_000
const RETRIES = 2
const TRANSIENT_STATUSES = new Set([408, 429, 500, 502, 503, 504, 529])

const KEY_HELP = [
  'jev-traits found no TypeSafe API key. Store it once, by hand, in the macOS Keychain (the jev-traits mod reads the same item):',
  '',
  `  security add-generic-password -U -a "$USER" -s ${KEYCHAIN_SERVICE} -w`,
  '',
  'The command prompts for the key, so it stays out of your shell history. Or export TYPESAFE_API_KEY.',
].join('\n')

export type CheckInput = {
  readonly target: Target
  readonly files: readonly string[]
  readonly trait?: string | undefined
  readonly path?: string | undefined
}
export type Outcome = { readonly text: string; readonly fixes: number }

class TypeSafeError extends Data.TaggedError('TypeSafeError')<{ readonly message: string; readonly transient: boolean }> {}

class ViolationsFound extends Data.TaggedError('ViolationsFound')<{ readonly fixes: number }> {
  readonly [Runtime.errorReported] = false
}

const errorText = (error: unknown) => (error instanceof Error ? error.message : String(error))
const said = (text: string): Outcome => ({ text, fixes: 0 })

const run = (command: string, args: readonly string[], cwd?: string) =>
  Effect.scoped(
    Effect.gen(function* () {
      const spawner = yield* ChildProcessSpawner.ChildProcessSpawner
      const handle = yield* spawner.spawn(ChildProcess.make(command, args, { cwd, stdin: 'ignore', extendEnv: true }))
      const [stdout, stderr, exitCode] = yield* Effect.all(
        [
          handle.stdout.pipe(Stream.decodeText(), Stream.mkString),
          handle.stderr.pipe(Stream.decodeText(), Stream.mkString),
          handle.exitCode,
        ],
        { concurrency: 'unbounded' },
      )
      return { stdout, stderr, exitCode: Number(exitCode) }
    }),
  )

const git = Effect.fn('jev-traits.git')(function* (root: string, args: readonly string[]) {
  const ran = yield* run('git', args, root)
  if (ran.exitCode !== 0) return yield* Effect.fail(new Error(`git ${args[0]} failed: ${ran.stderr.trim().split('\n')[0] ?? ''}`))
  return ran.stdout
})

const findRoot = Effect.fn('jev-traits.findRoot')(function* (from: string) {
  const fs = yield* FileSystem.FileSystem
  for (let dir = from; ; dir = dirOf(dir)) {
    if (yield* fs.exists(`${dir}/${TRAITS_DIR}`).pipe(Effect.orElseSucceed(() => false))) return dir
    if (dir === '/') return undefined
  }
})

const loadTraits = Effect.fn('jev-traits.loadTraits')(function* (root: string) {
  const fs = yield* FileSystem.FileSystem
  const base = `${root}/${TRAITS_DIR}`
  const isA = (type: FileSystem.File.Type, path: string) =>
    fs.stat(path).pipe(
      Effect.map(info => info.type === type),
      Effect.orElseSucceed(() => false),
    )
  const traits: Trait[] = []
  for (const group of yield* fs.readDirectory(base)) {
    if (group.startsWith('.') || !(yield* isA('Directory', `${base}/${group}`))) continue
    for (const name of yield* fs.readDirectory(`${base}/${group}`)) {
      const path = `${base}/${group}/${name}`
      if (!name.endsWith('.md') || !(yield* isA('File', path))) continue
      traits.push(parseTrait(`${group}/${name.slice(0, -'.md'.length)}`, path, yield* fs.readFileString(path)))
    }
  }
  return traits.sort((a, b) => a.id.localeCompare(b.id))
})

const apiKey = Effect.gen(function* () {
  const fromEnv = yield* Config.option(Config.String('TYPESAFE_API_KEY'))
  const env = Option.getOrElse(fromEnv, () => '').trim()
  if (env) return Option.some(Redacted.make(env))
  const keychain = yield* run('security', ['find-generic-password', '-s', KEYCHAIN_SERVICE, '-w']).pipe(Effect.option)
  const stored = Option.isSome(keychain) && keychain.value.exitCode === 0 ? keychain.value.stdout.trim() : ''
  return stored ? Option.some(Redacted.make(stored)) : Option.none()
})

const gather = Effect.fn('jev-traits.gather')(function* (root: string, target: Target, files: readonly string[]) {
  const fs = yield* FileSystem.FileSystem
  const changes: Change[] = []
  const skipped: string[] = []
  const readWhole = (rel: string) =>
    fs.readFileString(`${root}/${rel}`).pipe(
      Effect.option,
      Effect.map(text => {
        const code = Option.getOrUndefined(text)
        if (isCheckable(code)) changes.push({ path: rel, kind: 'file', code })
        else skipped.push(rel)
      }),
    )
  if (target === 'files')
    for (const file of files) yield* readWhole(relativeTo(root, file.startsWith('/') ? file : `${root}/${file}`))
  if (target === 'staged' || target === 'changed') changes.push(...diffChanges(yield* git(root, diffArgs(true))))
  if (target === 'unstaged' || target === 'changed') changes.push(...diffChanges(yield* git(root, diffArgs(false))))
  if (target === 'untracked' || target === 'changed')
    for (const rel of untrackedPaths(yield* git(root, UNTRACKED_ARGS))) yield* readWhole(rel)
  return { changes, skipped }
})

const ask = (client: HttpClient.HttpClient, key: Redacted.Redacted, settings: Settings, job: Job) =>
  client
    .execute(
      HttpClientRequest.post(ENDPOINT).pipe(
        HttpClientRequest.bearerToken(key),
        HttpClientRequest.bodyJsonUnsafe(requestBody(settings, job)),
      ),
    )
    .pipe(
      Effect.flatMap(response =>
        Effect.gen(function* () {
          if (response.status === 401)
            return yield* new TypeSafeError({ message: 'TypeSafe rejected the API key (401)', transient: false })
          if (response.status >= 300)
            return yield* new TypeSafeError({
              message: `TypeSafe ${response.status}`,
              transient: TRANSIENT_STATUSES.has(response.status),
            })
          return yield* response.json
        }),
      ),
      Effect.mapError(error =>
        error instanceof TypeSafeError ? error : new TypeSafeError({ message: `TypeSafe: ${error.message}`, transient: true }),
      ),
      Effect.timeoutOrElse({
        duration: REQUEST_TIMEOUT_MS,
        orElse: () =>
          Effect.fail(new TypeSafeError({ message: `TypeSafe timed out after ${REQUEST_TIMEOUT_MS} ms`, transient: true })),
      }),
      Effect.retry({ times: RETRIES, schedule: Schedule.exponential('500 millis'), while: error => error.transient }),
      Effect.flatMap(answer =>
        Effect.try({
          try: () => {
            const reply = answer as SystemOneReply
            return { reply, judgments: judgmentsFrom(reply, job, settings) }
          },
          catch: error => new TypeSafeError({ message: errorText(error), transient: false }),
        }),
      ),
    )

const review = Effect.fn('jev-traits.review')(function* (key: Redacted.Redacted, settings: Settings, work: readonly Work[]) {
  const client = yield* HttpClient.HttpClient
  const startedAt = yield* Clock.currentTimeMillis
  const jobs = jobsFor(work)
  const answered = yield* Effect.forEach(jobs, job => Effect.result(ask(client, key, settings, job)), {
    concurrency: MAX_IN_FLIGHT,
  })
  const result: { -readonly [K in keyof Review]: Review[K] } = {
    judgments: [],
    errors: [],
    model: undefined,
    requests: jobs.length,
    inputTokens: 0,
    ms: 0,
  }
  answered.forEach((one, i) => {
    if (Result.isFailure(one)) {
      result.errors.push({ path: jobs[i]?.change.path ?? '', message: one.failure.message })
      return
    }
    result.model = one.success.reply.model ?? result.model
    result.inputTokens += one.success.reply.usage?.input_tokens ?? 0
    result.judgments.push(...one.success.judgments)
  })
  result.ms = (yield* Clock.currentTimeMillis) - startedAt
  return result
})

export const checkTraits = Effect.fn('jev-traits.check')(function* (input: CheckInput) {
  const path = yield* Path.Path
  const start = path.resolve(input.path ?? input.files.find(file => path.isAbsolute(file)) ?? '.')
  const root = yield* findRoot(start)
  if (!root) return said(`No ${TRAITS_DIR} folder at or above ${start}. Add a trait as ${TRAITS_DIR}/project/<name>.md first.`)
  const all = yield* loadTraits(root)
  const traits = input.trait ? all.filter(trait => trait.id === input.trait) : all
  if (traits.length === 0)
    return said(input.trait ? `No trait ${input.trait} in ${root}/${TRAITS_DIR}.` : `No traits in ${root}/${TRAITS_DIR}.`)
  const key = yield* apiKey
  if (Option.isNone(key)) return said(KEY_HELP)
  const { changes, skipped } = yield* gather(root, input.target, input.files)
  const work = workFor(changes, traits)
  if (work.length === 0)
    return said(
      `jev-traits ${input.target}: nothing to check (${changes.length > 0 ? 'no trait applies to the changes' : 'no changes'}).`,
    )
  const result = yield* review(key.value, settingsFrom({}), work)
  return {
    text: formatReport(root, input.target, result, skipped),
    fixes: result.judgments.filter(judgment => judgment.verdict === 'fix').length,
  }
})

const check = Command.make(
  'check',
  {
    targets: Argument.String('target').pipe(
      Argument.withDescription('changed (the default), staged, unstaged or untracked; or files to check whole'),
      Argument.variadic(),
    ),
    path: Flag.String('path').pipe(
      Flag.withDescription('A folder or file inside the repository; defaults to the current folder'),
      Flag.optional,
    ),
    trait: Flag.String('trait').pipe(Flag.withDescription('Check one trait only, as group/name'), Flag.optional),
  },
  Effect.fn('jev-traits.check.command')(function* ({ targets, path, trait }) {
    const paths = yield* Path.Path
    const { target, files } = targetFrom(targets)
    const outcome = yield* checkTraits({
      target,
      files: files.map(file => paths.resolve(file)),
      path: Option.getOrUndefined(path),
      trait: Option.getOrUndefined(trait),
    }).pipe(Effect.catch(error => Effect.succeed(said(`jev-traits could not check: ${errorText(error)}`))))
    yield* Console.log(outcome.text)
    if (outcome.fixes > 0) return yield* new ViolationsFound({ fixes: outcome.fixes })
  }),
).pipe(
  Command.withDescription(
    'Check work in progress against the traits; exits 1 when Jev finds a likely violation, 0 otherwise (also when the check cannot run)',
  ),
)

export const jevTraits = Command.make('jev-traits').pipe(
  Command.withDescription("Check code against the repository's traits (.agents/traits) with TypeSafe Jev"),
  Command.withSubcommands([check]),
)
