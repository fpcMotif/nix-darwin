import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

const TRAITS = '/repo/.agents/traits'
const TRAIT_PATH = `${TRAITS}/project/fetch_timeout.md`
const TRAIT = '---\npaths: ["src/**"]\nwhen:\n  - fetch\n---\nEvery fetch call passes an AbortSignal timeout.\n'
const KEYED = { options: { typesafe_api_key: 'test-key' } }

type Reply = { status?: number; violation?: number; inconclusive?: number }
type SentRequest = {
  model: string
  state: { change: { path: string; kind: string; code: string; head?: string; excerpt?: { index: number } } }
  questions: Record<string, { type: string; instructions: { trait: string; question: string }; criteria: Record<string, string> }>
}

function world(on: On, reply: Reply = {}, files: Record<string, string> = {}) {
  const requests: SentRequest[] = []
  const statuses: (string | undefined)[] = []
  mock.clock(on)
  on('fs.exists', (_, e) => ({ value: e.path === TRAITS }))
  on('fs.list', (_, e) => {
    if (e.path === TRAITS) return { value: [{ name: 'project', kind: 'dir', size: 0, mtimeMs: 0, isLink: false }] }
    if (e.path === `${TRAITS}/project`)
      return { value: [{ name: 'fetch_timeout.md', kind: 'file', size: TRAIT.length, mtimeMs: 1, isLink: false }] }
    return { value: [] }
  })
  on('fs.read', (_, e) => {
    if (e.path === TRAIT_PATH) return { value: TRAIT }
    const file = files[e.path]
    return file === undefined ? { deny: `ENOENT ${e.path}` } : { value: file }
  })
  on('http.fetch', (_, e) => {
    const sent = JSON.parse(e.init?.body ?? '{}') as SentRequest
    requests.push(sent)
    const violation = reply.violation ?? 0.02
    const inconclusive = reply.inconclusive ?? 0.01
    const answers = Object.fromEntries(
      Object.keys(sent.questions).map(id => [
        id,
        {
          type: 'choice',
          choice: violation > 0.5 ? 'violation' : 'compliant',
          probabilities: { compliant: 0.98 - violation - inconclusive, violation, 'not-applicable': 0.02, inconclusive },
          confidence: 0.9,
        },
      ]),
    )
    const status = reply.status ?? 200
    return {
      value: {
        status,
        ok: status < 300,
        headers: {},
        text: JSON.stringify({ model: 'jev-1.13.0', answers, usage: { input_tokens: 300, output_tokens: 20 } }),
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
  return { requests, statuses }
}

const BIG_HEAD = "import { timeoutFetch } from './net'\n"
const BIG_FILE = BIG_HEAD + 'export const load = () => fetch(url)\n'.repeat(700)

const edit = (new_string: string, file_path = '/repo/src/api.ts') =>
  ({ tool: 'Edit', file_path, old_string: 'TODO', new_string }) as const

describe('per-edit check', () => {
  test('adds a likely violation after the edit result', KEYED, async ($, on) => {
    const { requests, statuses } = world(on, { violation: 0.93 })
    const ran = await $.tool.call(edit('const res = await fetch(url)'))

    expect(requests.length).toBe(1)
    const sent = requests[0]
    expect(sent?.model).toBe('jev-latest')
    expect(sent?.state.change).toEqual({ path: 'src/api.ts', kind: 'edit', code: 'const res = await fetch(url)' })
    const asked = Object.values(sent?.questions ?? {})
    expect(asked.length).toBe(1)
    expect(asked[0]?.type).toBe('choice')
    expect(asked[0]?.instructions.trait).toBe('Every fetch call passes an AbortSignal timeout.')
    expect(Object.keys(asked[0]?.criteria ?? {})).toEqual(['compliant', 'violation', 'not-applicable', 'inconclusive'])

    expect(ran.text).toBe('The file was updated.')
    const feedback = ran.context?.join('\n') ?? ''
    expect(feedback).toContain('Likely violations, fix these:')
    expect(feedback).toContain('project/fetch_timeout (p=0.93)')
    expect(feedback).toContain('.agents/traits/project/fetch_timeout.md')
    expect(statuses.at(-1)).toContain('jev ⚠ 1 to fix · src/api.ts')
  })

  test('lets a clean edit through unchanged', KEYED, async ($, on) => {
    const { requests, statuses } = world(on, { violation: 0.02 })
    const ran = await $.tool.call(edit('await fetch(url, { signal: AbortSignal.timeout(5000) })'))

    expect(requests.length).toBe(1)
    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toContain('jev ✓ · src/api.ts · 1 trait ·')
  })

  test('asks nothing when the when-gate does not match', KEYED, async ($, on) => {
    const { requests, statuses } = world(on)
    const ran = await $.tool.call(edit('const total = a + b'))

    expect(requests.length).toBe(0)
    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toContain('no trait applies')
  })

  test('asks nothing outside the trait paths', KEYED, async ($, on) => {
    const { requests } = world(on)
    await $.tool.call(edit('await fetch(url)', '/repo/scripts/seed.ts'))

    expect(requests.length).toBe(0)
  })

  test('fails open when TypeSafe errors', KEYED, async ($, on) => {
    const { requests, statuses } = world(on, { status: 529 })
    const ran = await $.tool.call(edit('await fetch(url)'))

    expect(requests.length).toBe(1)
    expect(ran.text).toBe('The file was updated.')
    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toContain('TypeSafe 529')
  })

  test('sends the file opening lines with an edit', KEYED, async ($, on) => {
    const file = `${BIG_HEAD}export {}\n`
    const { requests } = world(on, { violation: 0.02 }, { '/repo/src/api.ts': file })
    await $.tool.call(edit('const res = await fetch(url)'))

    expect(requests[0]?.state.change.head).toBe(file)
    expect(Object.values(requests[0]?.questions ?? {})[0]?.instructions.question).toContain('`change.head`')
  })

  test('asks nothing and says so without a key', async ($, on) => {
    const { requests, statuses } = world(on)
    mock.env(on, {})
    on('process.run', () => ({
      value: { exitCode: 44, stdout: '', stderr: 'not found', isStdoutTruncated: false, isStderrTruncated: false },
    }))
    const ran = await $.tool.call(edit('await fetch(url)'))

    expect(requests.length).toBe(0)
    expect(ran.context).toBeUndefined()
    expect(statuses.at(-1)).toContain('no TypeSafe API key')
  })
})

const STAGED_DIFF = [
  'diff --git a/src/api.ts b/src/api.ts',
  'index 1111111..2222222 100644',
  '--- a/src/api.ts',
  '+++ b/src/api.ts',
  '@@ -1,1 +1,2 @@',
  ' export {}',
  '+const res = await fetch(url)',
  'diff --git a/docs/notes.md b/docs/notes.md',
  'deleted file mode 100644',
  '--- a/docs/notes.md',
  '+++ /dev/null',
  '@@ -1 +0,0 @@',
  '-old',
  '',
].join('\n')

test('check_traits reports staged violations by file', KEYED, async ($, on) => {
  const { requests } = world(on, { violation: 0.88 })
  const gitCalls: string[][] = []
  on('session.root', () => ({ value: '/repo' }))
  on('process.run', (_, e) => {
    gitCalls.push([...e.argv])
    const stdout = e.argv.includes('--cached') ? STAGED_DIFF : ''
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged' })

  expect(gitCalls[0]).toContain('--cached')
  expect(requests.length).toBe(1)
  expect(requests[0]?.state.change.kind).toBe('diff')
  expect(requests[0]?.state.change.path).toBe('src/api.ts')
  const report = String(ran.result)
  expect(report).toContain('jev-traits staged: violations')
  expect(report).toContain('src/api.ts')
  expect(report).toContain('fix    project/fetch_timeout  p(violation) 0.88')
  expect(report).not.toContain('docs/notes.md')
})

test('check_traits finds a repository below the session folder through path', KEYED, async ($, on) => {
  const { requests } = world(on, { violation: 0.88 })
  const gitFolders: (string | undefined)[] = []
  on('session.root', () => ({ value: '/' }))
  on('process.run', (_, e) => {
    gitFolders.push(e.init?.cwd)
    const stdout = e.argv.includes('--cached') ? STAGED_DIFF : ''
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  const unreached = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged' })
  expect(String(unreached.result)).toContain('No .agents/traits folder at or above /')

  const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'staged', path: '/repo/src' })

  expect(gitFolders).toEqual(['/repo'])
  expect(requests.length).toBe(1)
  expect(String(ran.result)).toContain('fix    project/fetch_timeout  p(violation) 0.88')
})

test('check_traits gives later excerpts the file opening lines', KEYED, async ($, on) => {
  const { requests } = world(on, { violation: 0.02 }, { '/repo/src/big.ts': BIG_FILE })
  on('session.root', () => ({ value: '/repo' }))
  await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'files', files: ['src/big.ts'] })

  const excerpts = requests.map(r => r.state.change).sort((a, b) => (a.excerpt?.index ?? 0) - (b.excerpt?.index ?? 0))
  expect(excerpts.length).toBeGreaterThan(1)
  expect(excerpts[0]?.head).toBeUndefined()
  for (const later of excerpts.slice(1)) expect(later.head?.startsWith(BIG_HEAD)).toBe(true)
})

test('check_traits reports unsure judgments as one line per file', KEYED, async ($, on) => {
  const { requests } = world(on, { inconclusive: 0.6 }, { '/repo/src/big.ts': BIG_FILE })
  on('session.root', () => ({ value: '/repo' }))
  const ran = await $.tool.call({ tool: 'mcp__jev-traits__check_traits', target: 'files', files: ['src/big.ts'] })

  const report = String(ran.result)
  expect(report).toContain('jev-traits files: inconclusive')
  expect(report).toContain(`Unsure, Jev lacked context:\n  src/big.ts: ${requests.length} (project/fetch_timeout)`)
  expect(report).not.toContain('[excerpt')
})
