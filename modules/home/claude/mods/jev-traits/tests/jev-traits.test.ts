import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

const TRAITS = '/repo/.agents/traits'
const KEYED = { options: { typesafe_api_key: 'test-key' } }

type Verdict = 'fix' | 'check' | 'unsure' | 'pass'
type Spawn = { argv: string[]; cwd?: string; env?: Record<string, string>; stdin?: string; timeoutMs?: number }
type Answer =
  | { exitCode: number; stdout?: string; stderr?: string }
  | { reject: string }

type CliSkip = { path: string; trait: string; reason: 'too-large'; startLine: number; bytes: number; maxBytes: number }

const TOO_LARGE: CliSkip = {
  path: '/repo/src/big.ts',
  trait: 'project/fetch_timeout',
  reason: 'too-large',
  startLine: 201,
  bytes: 300000,
  maxBytes: 120000,
}

function cliReport(
  verdicts: readonly { verdict: Verdict; violation: number; path?: string }[],
  skipped: readonly CliSkip[] = [],
) {
  const findings = verdicts
    .filter(one => one.verdict !== 'pass')
    .map(one => ({
      trait: {
        name: 'project/fetch_timeout',
        subject: 'the code in the change',
        requirement: 'Every fetch call passes an AbortSignal timeout.',
        purpose: 'Every fetch call passes an AbortSignal timeout.',
      },
      source: { text: 'fetch(url)', location: { _tag: 'File', path: `/repo/${one.path ?? 'src/api.ts'}`, startLine: 1 } },
      assessment: {
        classification: one.violation > 0.5 ? 'violation' : 'inconclusive',
        probabilities: { compliant: 0.05, violation: one.violation, 'not-applicable': 0.05, inconclusive: 0.9 - one.violation },
        verdict: one.verdict,
      },
    }))
  const count = (verdict: Verdict) => verdicts.filter(one => one.verdict === verdict).length
  return JSON.stringify({
    findings,
    skipped,
    summary: {
      files: 1,
      traits: 1,
      requests: verdicts.length,
      skipped: skipped.length,
      verdicts: { fix: count('fix'), check: count('check'), unsure: count('unsure'), pass: count('pass') },
    },
  })
}

const CLEAN: Answer = { exitCode: 0, stdout: cliReport([{ verdict: 'pass', violation: 0.02 }]) }

type Keys = { readonly env?: string; readonly keychain?: string }

function world(on: On, answer = CLEAN, traitFiles = ['fetch_timeout.md'], sessionRoot = '/repo', keys: Keys = {}) {
  const spawns: Spawn[] = []
  const statuses: (string | undefined)[] = []
  mock.clock(on)
  mock.env(on, keys.env === undefined ? {} : { TYPESAFE_API_KEY: keys.env })
  on('session.root', () => ({ value: sessionRoot }))
  on('fs.exists', (_, e) => ({ value: e.path === TRAITS }))
  on('fs.list', (_, e) => {
    if (e.path === TRAITS) return { value: [{ name: 'project', kind: 'dir', size: 0, mtimeMs: 0, isLink: false }] }
    if (e.path === `${TRAITS}/project`)
      return { value: traitFiles.map(name => ({ name, kind: 'file', size: 10, mtimeMs: 1, isLink: false })) }
    return { value: [] }
  })
  on('process.run', (_, e) => {
    if (e.argv[0] === 'security')
      return keys.keychain === undefined
        ? { value: { exitCode: 44, stdout: '', stderr: 'not found', isStdoutTruncated: false, isStderrTruncated: false } }
        : { value: { exitCode: 0, stdout: `${keys.keychain}\n`, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
    spawns.push({ argv: [...e.argv], ...e.init })
    if ('reject' in answer) return { deny: answer.reject }
    return {
      value: {
        exitCode: answer.exitCode,
        stdout: answer.stdout ?? '',
        stderr: answer.stderr ?? '',
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }
  })
  on('ui.status', (_, e) => {
    statuses.push(e.text)
    return { value: undefined }
  })
  on('tool.call', { tool: 'Edit' }, ($, e) => ({
    result: {
      filePath: e.file_path,
      oldString: e.old_string,
      newString: e.new_string,
      originalFile: null,
      structuredPatch: [],
      userModified: false,
      replaceAll: false,
    },
    text: 'The file was updated.',
  }))
  return { spawns, statuses }
}

const edit = (new_string: string, file_path = '/repo/src/api.ts') =>
  ({ tool: 'Edit', file_path, old_string: 'TODO', new_string }) as const

const flagValue = (argv: readonly string[], flag: string) => argv[argv.indexOf(flag) + 1]

describe('per-edit check', () => {
  test('sends the edit to traits on stdin with the configured flags', KEYED, async ($, on) => {
    const { spawns } = world(on)
    await $.tool.call(edit('const res = await fetch(url)'))

    expect(spawns.length).toBe(1)
    const [spawn] = spawns
    expect(spawn?.argv.slice(0, 6)).toEqual(['traits', 'check', '--stdin', '--stdin-filepath', 'src/api.ts', '--kind'])
    expect(flagValue(spawn?.argv ?? [], '--kind')).toBe('edit')
    expect(spawn?.argv).toContain('--json')
    expect(flagValue(spawn?.argv ?? [], '--fail-on')).toBe('never')
    expect(flagValue(spawn?.argv ?? [], '--fix-threshold')).toBe('0.8')
    expect(flagValue(spawn?.argv ?? [], '--check-threshold')).toBe('0.5')
    expect(flagValue(spawn?.argv ?? [], '--pass-threshold')).toBe('0.9')
    expect(spawn?.argv).not.toContain('--model')
    expect(spawn?.stdin).toBe('const res = await fetch(url)')
    expect(spawn?.cwd).toBe('/repo')
    expect(spawn?.timeoutMs).toBe(6000)
  })

  test('maps a custom model and thresholds to flags', { options: { ...KEYED.options, model: 'jev-1.13.0', fix_threshold: 0.7, check_threshold: 0.4, pass_threshold: 0.95 } }, async ($, on) => {
    const { spawns } = world(on)
    await $.tool.call(edit('const res = await fetch(url)'))

    const argv = spawns[0]?.argv ?? []
    expect(flagValue(argv, '--model')).toBe('jev-1.13.0')
    expect(flagValue(argv, '--fix-threshold')).toBe('0.7')
    expect(flagValue(argv, '--check-threshold')).toBe('0.4')
    expect(flagValue(argv, '--pass-threshold')).toBe('0.95')
  })

  test('passes the key to traits through the environment only', KEYED, async ($, on) => {
    const { spawns } = world(on)
    await $.tool.call(edit('const res = await fetch(url)'))

    expect(spawns[0]?.env).toEqual({ TYPESAFE_API_KEY: 'test-key' })
    expect(spawns[0]?.argv.join(' ')).not.toContain('test-key')
    expect(spawns[0]?.stdin).not.toContain('test-key')
  })

  test('adds a likely violation after the edit result', KEYED, async ($, on) => {
    const { statuses } = world(on, { exitCode: 0, stdout: cliReport([{ verdict: 'fix', violation: 0.93 }]) })
    const ran = await $.tool.call(edit('const res = await fetch(url)'))

    expect(ran.text).toBe('The file was updated.')
    const feedback = ran.context?.join('\n') ?? ''
    expect(feedback).toContain('Likely violations, fix these:')
    expect(feedback).toContain('project/fetch_timeout (p=0.93)')
    expect(feedback).toContain('.agents/traits/project/fetch_timeout.md')
    expect(statuses.at(-1)).toContain('jev ⚠ 1 to fix · src/api.ts')
  })

  test('lets a clean edit through unchanged', KEYED, async ($, on) => {
    const { statuses } = world(on)
    const ran = await $.tool.call(edit('await fetch(url, { signal: AbortSignal.timeout(5000) })'))

    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toContain('jev ✓ · src/api.ts · 1 judgment ·')
  })

  test('says so when traits skipped the edit as too large', KEYED, async ($, on) => {
    const { statuses } = world(on, { exitCode: 0, stdout: cliReport([], [{ ...TOO_LARGE, path: '/repo/src/api.ts' }]) })
    const ran = await $.tool.call(edit('await fetch(url)'))

    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toBe('jev · src/api.ts: 1 skipped as too large; use /traits check')
  })

  test('counts too-large skips in the edit status', KEYED, async ($, on) => {
    const { statuses } = world(on, {
      exitCode: 0,
      stdout: cliReport([{ verdict: 'pass', violation: 0.02 }], [{ ...TOO_LARGE, path: '/repo/src/api.ts' }]),
    })
    await $.tool.call(edit('await fetch(url)'))

    expect(statuses.at(-1)).toContain('jev ✓ · src/api.ts · 1 judgment · 1 skipped as too large ·')
  })

  test('says no trait applies when traits judged nothing', KEYED, async ($, on) => {
    const { statuses } = world(on, { exitCode: 0, stdout: cliReport([]) })
    const ran = await $.tool.call(edit('const total = a + b'))

    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toContain('no trait applies')
  })

  test('notes a timeout as not checked and lets the edit through', KEYED, async ($, on) => {
    const { statuses } = world(on, { reject: 'process timed out after 6000 ms' })
    const ran = await $.tool.call(edit('await fetch(url)'))

    expect(ran.text).toBe('The file was updated.')
    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toBe('jev: traits did not finish within 6 s; src/api.ts not checked')
  })

  test('notes an operational failure from exit 2', KEYED, async ($, on) => {
    const { statuses } = world(on, { exitCode: 2, stderr: '\nTypeSafe returned 529 Overloaded\n    at stack' })
    const ran = await $.tool.call(edit('await fetch(url)'))

    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toBe('jev: TypeSafe returned 529 Overloaded; src/api.ts not checked')
  })

  test('spawns nothing in a repository without trait files', KEYED, async ($, on) => {
    const { spawns } = world(on, undefined, [])
    const ran = await $.tool.call(edit('await fetch(url)'))

    expect(spawns.length).toBe(0)
    expect(ran.context).toBeUndefined()
  })

  test('prefers the Keychain key over TYPESAFE_API_KEY', async ($, on) => {
    const { spawns } = world(on, CLEAN, ['fetch_timeout.md'], '/repo', { env: 'env-key', keychain: 'keychain-key' })
    await $.tool.call(edit('await fetch(url)'))

    expect(spawns[0]?.env).toEqual({ TYPESAFE_API_KEY: 'keychain-key' })
  })

  test('falls back to TYPESAFE_API_KEY without a Keychain item', async ($, on) => {
    const { spawns } = world(on, CLEAN, ['fetch_timeout.md'], '/repo', { env: 'env-key' })
    await $.tool.call(edit('await fetch(url)'))

    expect(spawns[0]?.env).toEqual({ TYPESAFE_API_KEY: 'env-key' })
  })

  test('prefers the plugin option over the Keychain', KEYED, async ($, on) => {
    const { spawns } = world(on, CLEAN, ['fetch_timeout.md'], '/repo', { env: 'env-key', keychain: 'keychain-key' })
    await $.tool.call(edit('await fetch(url)'))

    expect(spawns[0]?.env).toEqual({ TYPESAFE_API_KEY: 'test-key' })
  })

  test('spawns nothing and says so without a key', async ($, on) => {
    const { spawns, statuses } = world(on)
    const ran = await $.tool.call(edit('await fetch(url)'))

    expect(spawns.length).toBe(0)
    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toContain('no TypeSafe API key')
  })
})

describe('check_traits', () => {
  test('maps target, trait and path to traits flags', KEYED, async ($, on) => {
    const { spawns } = world(on, CLEAN, ['fetch_timeout.md'], '/')
    await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged', trait: 'project/fetch_timeout', path: '/repo/src' })

    const spawn = spawns[0]
    expect(spawn?.argv.slice(0, 2)).toEqual(['traits', 'check'])
    expect(flagValue(spawn?.argv ?? [], '--target')).toBe('staged')
    expect(flagValue(spawn?.argv ?? [], '--trait')).toBe('project/fetch_timeout')
    expect(flagValue(spawn?.argv ?? [], '--path')).toBe('/repo')
    expect(spawn?.argv).toContain('--json')
    expect(spawn?.argv).not.toContain('--stdin')
    expect(spawn?.stdin).toBeUndefined()
    expect(spawn?.env).toEqual({ TYPESAFE_API_KEY: 'test-key' })
    expect(spawn?.timeoutMs).toBe(8000)
  })

  test('maps files to --include paths under the repository', KEYED, async ($, on) => {
    const { spawns } = world(on)
    await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'files', files: ['src/a.ts', '/repo/src/b.ts'] })

    const argv = spawns[0]?.argv ?? []
    expect(argv.filter((_, i) => argv[i - 1] === '--include')).toEqual(['/repo/src/a.ts', '/repo/src/b.ts'])
    expect(argv).not.toContain('--target')
  })

  test('reports violations by file', KEYED, async ($, on) => {
    world(on, { exitCode: 0, stdout: cliReport([{ verdict: 'fix', violation: 0.88 }, { verdict: 'pass', violation: 0.01 }]) })
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged' })

    const report = String(ran.result)
    expect(report).toContain('jev-traits staged: violations · 2 judgments over 1 file')
    expect(report).toContain('src/api.ts:1')
    expect(report).toContain('fix    project/fetch_timeout  p(violation) 0.88')
    expect(report).toContain('Trait files: .agents/traits/project/fetch_timeout.md')
  })

  test('reports unsure judgments as one line per file', KEYED, async ($, on) => {
    world(on, { exitCode: 0, stdout: cliReport([{ verdict: 'unsure', violation: 0.1 }, { verdict: 'unsure', violation: 0.1 }]) })
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'changed' })

    const report = String(ran.result)
    expect(report).toContain('jev-traits changed: inconclusive')
    expect(report).toContain('Unsure, Jev lacked context:\n  src/api.ts: 2 (project/fetch_timeout)')
  })

  test('reports too-large skips as inconclusive, never as a pass', KEYED, async ($, on) => {
    world(on, { exitCode: 0, stdout: cliReport([{ verdict: 'pass', violation: 0.02 }], [TOO_LARGE]) })
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'changed' })

    const report = String(ran.result)
    expect(report).toContain('jev-traits changed: inconclusive · 1 judgment over 1 file · 1 request · ')
    expect(report).toContain('· 1 skipped as too large')
    expect(report).toContain(
      'Skipped as too large, not checked:\n  src/big.ts:201 project/fetch_timeout (300000/120000 bytes)',
    )
  })

  test('lists at most 20 too-large skips', KEYED, async ($, on) => {
    const skipped = Array.from({ length: 25 }, (_, i) => ({ ...TOO_LARGE, startLine: i * 200 + 1 }))
    world(on, { exitCode: 0, stdout: cliReport([], skipped) })
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'changed' })

    const report = String(ran.result)
    expect(report.split('\n').filter(line => line.startsWith('  src/big.ts:')).length).toBe(20)
    expect(report).toContain('  … and 5 more')
  })

  test('reports a check where every pair was skipped', KEYED, async ($, on) => {
    world(on, { exitCode: 0, stdout: cliReport([], [TOO_LARGE]) })
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'changed' })

    const report = String(ran.result)
    expect(report).toContain('jev-traits changed: inconclusive')
    expect(report).not.toContain('nothing to check')
  })

  test('reports a timeout as not checked', KEYED, async ($, on) => {
    world(on, { reject: 'process timed out after 8000 ms' })
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged' })

    expect(String(ran.result)).toBe('jev-traits staged: not checked, traits did not finish within 8 s.')
  })

  test('reports exit 2 with the CLI error', KEYED, async ($, on) => {
    world(on, { exitCode: 2, stderr: 'TYPESAFE_API_KEY is not set.' })
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged' })

    expect(String(ran.result)).toBe('jev-traits staged: not checked, TYPESAFE_API_KEY is not set..')
  })

  test('spawns nothing in a repository without trait files', KEYED, async ($, on) => {
    const { spawns } = world(on, undefined, [])
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged' })

    expect(spawns.length).toBe(0)
    expect(String(ran.result)).toBe('No traits in /repo/.agents/traits.')
  })

  test('finds no repository above an unrelated session folder', KEYED, async ($, on) => {
    const { spawns } = world(on, CLEAN, ['fetch_timeout.md'], '/')
    const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged' })

    expect(spawns.length).toBe(0)
    expect(String(ran.result)).toContain('No .agents/traits folder at or above /')
  })
})

test('/traits lists stored traits from traits ls', KEYED, async ($, on) => {
  const { spawns } = world(on, {
    exitCode: 0,
    stdout: JSON.stringify([{ name: 'project/fetch_timeout', path: '/repo/.agents/traits/project/fetch_timeout.md' }]),
  })
  const ran = await $.command.run({
    command: 'traits',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 100 },
  })

  expect(spawns[0]?.argv).toEqual(['traits', 'ls', '--json'])
  expect(spawns[0]?.env).toBeUndefined()
  expect(ran.text).toContain('Traits: 1 in /repo/.agents/traits')
  expect(ran.text).toContain('  project/fetch_timeout: .agents/traits/project/fetch_timeout.md')
})
