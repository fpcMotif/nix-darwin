import { BunServices } from '@effect/platform-bun'
import { describe, expect, test } from 'bun:test'
import { ConfigProvider, Effect, Exit, Layer, Runtime } from 'effect'
import { Command } from 'effect/cli'
import { HttpClient, HttpClientResponse } from 'effect/http'
import { ChildProcess, ChildProcessSpawner } from 'effect/process'
import { spawnSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, realpathSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'

import { checkTraits, jevTraits } from './JevTraits.ts'

const TRAIT = '---\npaths: ["src/**"]\nwhen:\n  - fetch\n---\nEvery fetch call passes an AbortSignal timeout.\n'

type Sent = {
  authorization: string | undefined
  body: {
    model: string
    state: { change: { path: string; kind: string; code: string } }
    questions: Record<string, { type: string; instructions: { trait: string }; criteria: Record<string, string> }>
  }
}

function typesafe(reply: { status?: number; violation?: number } = {}) {
  const sent: Sent[] = []
  const client = HttpClient.make(request =>
    Effect.sync(() => {
      const body = request.body._tag === 'Uint8Array' ? new TextDecoder().decode(request.body.body) : '{}'
      const parsed = JSON.parse(body) as Sent['body']
      sent.push({ authorization: request.headers.authorization, body: parsed })
      const violation = reply.violation ?? 0.02
      const answers = Object.fromEntries(
        Object.keys(parsed.questions).map(id => [
          id,
          {
            type: 'choice',
            choice: violation > 0.5 ? 'violation' : 'compliant',
            probabilities: { compliant: 0.97 - violation, violation, 'not-applicable': 0.02, inconclusive: 0.01 },
            confidence: 0.9,
          },
        ]),
      )
      const text = JSON.stringify({ model: 'jev-1.13.0', answers, usage: { input_tokens: 300, output_tokens: 20 } })
      return HttpClientResponse.fromWeb(request, new Response(text, { status: reply.status ?? 200 }))
    }),
  )
  return { sent, layer: Layer.succeed(HttpClient.HttpClient, client) }
}

const withKey = ConfigProvider.layer(ConfigProvider.fromUnknown({ TYPESAFE_API_KEY: 'test-key' }))
const withoutKey = ConfigProvider.layer(ConfigProvider.fromUnknown({}))

const emptyKeychain = Layer.effect(
  ChildProcessSpawner.ChildProcessSpawner,
  Effect.gen(function* () {
    const real = yield* ChildProcessSpawner.ChildProcessSpawner
    return ChildProcessSpawner.make(command =>
      ChildProcess.isStandardCommand(command) && command.command === 'security'
        ? real.spawn(ChildProcess.make('false', []))
        : real.spawn(command),
    )
  }),
)

function run<A, E>(
  program: Effect.Effect<A, E, any>,
  http: Layer.Layer<HttpClient.HttpClient>,
  config = withKey,
): Promise<Exit.Exit<A, E>> {
  return Effect.runPromiseExit(
    program.pipe(
      Effect.provide(emptyKeychain),
      Effect.provide(Layer.mergeAll(http, config)),
      Effect.provide(BunServices.layer),
    ) as Effect.Effect<A, E>,
  )
}

function value<A, E>(exit: Exit.Exit<A, E>): A {
  if (Exit.isFailure(exit)) throw new Error(`expected success, got ${String(exit.cause)}`)
  return exit.value
}

function git(root: string, ...args: string[]) {
  const ran = spawnSync('git', args, { cwd: root, encoding: 'utf8' })
  if (ran.status !== 0) throw new Error(ran.stderr)
}

function write(root: string, files: Record<string, string>) {
  for (const [rel, text] of Object.entries(files)) {
    mkdirSync(dirname(join(root, rel)), { recursive: true })
    writeFileSync(join(root, rel), text)
  }
}

function repo(staged: Record<string, string>): string {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'jev-traits-')))
  git(root, 'init', '-q')
  git(root, 'config', 'user.email', 'test@example.com')
  git(root, 'config', 'user.name', 'test')
  write(root, { '.agents/traits/project/fetch_timeout.md': TRAIT, 'src/api.ts': 'export {}\n' })
  git(root, 'add', '.')
  git(root, 'commit', '-q', '-m', 'base')
  write(root, staged)
  git(root, 'add', '.')
  return root
}

const FETCH = { 'src/api.ts': 'export {}\nconst res = await fetch(url)\n' }

describe('checkTraits', () => {
  test('asks Jev about a staged diff and reports a likely violation as a fix', async () => {
    const root = repo(FETCH)
    const api = typesafe({ violation: 0.88 })
    const outcome = value(await run(checkTraits({ target: 'staged', files: [], path: root }), api.layer))

    expect(api.sent.length).toBe(1)
    expect(api.sent[0]?.authorization).toBe('Bearer test-key')
    const body = api.sent[0]?.body
    expect(body?.model).toBe('jev-latest')
    expect(body?.state.change.path).toBe('src/api.ts')
    expect(body?.state.change.kind).toBe('diff')
    expect(body?.state.change.code).toContain('+const res = await fetch(url)')
    const asked = Object.values(body?.questions ?? {})
    expect(asked.length).toBe(1)
    expect(asked[0]?.type).toBe('choice')
    expect(asked[0]?.instructions.trait).toBe('Every fetch call passes an AbortSignal timeout.')
    expect(Object.keys(asked[0]?.criteria ?? {})).toEqual(['compliant', 'violation', 'not-applicable', 'inconclusive'])

    expect(outcome.fixes).toBe(1)
    expect(outcome.text).toContain('jev-traits staged: violations')
    expect(outcome.text).toContain('src/api.ts\n  fix    project/fetch_timeout  p(violation) 0.88')
  })

  test('passes clean staged code', async () => {
    const root = repo(FETCH)
    const outcome = value(await run(checkTraits({ target: 'staged', files: [], path: root }), typesafe().layer))

    expect(outcome.fixes).toBe(0)
    expect(outcome.text).toContain('jev-traits staged: pass')
  })

  test('retries an overloaded TypeSafe, then reports the file as not checked', async () => {
    const root = repo(FETCH)
    const api = typesafe({ status: 529 })
    const outcome = value(await run(checkTraits({ target: 'staged', files: [], path: root }), api.layer))

    expect(api.sent.length).toBe(3)
    expect(outcome.fixes).toBe(0)
    expect(outcome.text).toContain('jev-traits staged: inconclusive')
    expect(outcome.text).toContain('Not checked: src/api.ts (TypeSafe 529)')
  })

  test('finds the repository from a folder inside it, and says when there is none', async () => {
    const root = repo(FETCH)
    const api = typesafe({ violation: 0.88 })
    const inside = value(await run(checkTraits({ target: 'staged', files: [], path: join(root, 'src') }), api.layer))
    expect(inside.fixes).toBe(1)

    const outside = realpathSync(mkdtempSync(join(tmpdir(), 'jev-traits-none-')))
    const none = value(await run(checkTraits({ target: 'staged', files: [], path: outside }), api.layer))
    expect(none.text).toBe(
      `No .agents/traits folder at or above ${outside}. Add a trait as .agents/traits/project/<name>.md first.`,
    )
  })

  test('checks whole files given by absolute path', async () => {
    const root = repo({})
    write(root, FETCH)
    const api = typesafe({ violation: 0.88 })
    const outcome = value(await run(checkTraits({ target: 'files', files: [join(root, 'src/api.ts')] }), api.layer))

    expect(api.sent[0]?.body.state.change).toEqual({ path: 'src/api.ts', kind: 'file', code: FETCH['src/api.ts'] })
    expect(outcome.text).toContain('jev-traits files: violations')
  })

  test('without a key it asks nothing and explains how to store one', async () => {
    const root = repo(FETCH)
    const api = typesafe()
    const outcome = value(await run(checkTraits({ target: 'staged', files: [], path: root }), api.layer, withoutKey))

    expect(api.sent.length).toBe(0)
    expect(outcome.text).toContain('security add-generic-password -U -a "$USER" -s typesafe-api-key -w')
  })
})

describe('jev-traits check', () => {
  const cli = Command.runWith(jevTraits, { version: '0.0.0' })

  test('exits 1 on a likely violation', async () => {
    const root = repo(FETCH)
    const exit = await run(cli(['check', 'staged', '--path', root]), typesafe({ violation: 0.88 }).layer)

    expect(Exit.isFailure(exit)).toBe(true)
    const error = Exit.isFailure(exit) ? exit.cause.reasons[0] : undefined
    const failure = error?._tag === 'Fail' ? error.error : undefined
    expect(Runtime.getErrorExitCode(failure)).toBe(1)
    expect(Runtime.getErrorReported(failure)).toBe(false)
  })

  test('exits 0 on a pass and when the check cannot run', async () => {
    const root = repo(FETCH)
    expect(Exit.isSuccess(await run(cli(['check', 'staged', '--path', root]), typesafe().layer))).toBe(true)
    expect(Exit.isSuccess(await run(cli(['check', '--path', root]), typesafe({ status: 401 }).layer))).toBe(true)
  })
})
