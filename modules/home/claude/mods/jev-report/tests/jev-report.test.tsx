import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

import { parseAnswer } from '../hooks/lens'

const KEYED = { options: { typesafe_api_key: 'test-key' } }
const FILLER = 'The rebuild links the new guide into each host, and the check reads every rendered file. '.repeat(4)

const ASKING = [
  'The new rules are in place.',
  FILLER,
  '**What I need from you**',
  '1. Run `sudo darwin-rebuild switch --flake ~/nix-config` in your terminal, then reply "rebuilt".',
  '2. Pick the default model in Settings.',
].join('\n')

const EMPTY_ASK = ['The work is finished.', FILLER, '## What I need from you', 'Nothing needed from you right now.'].join('\n')
const DENSE = `The session starts the daemon, which streams the prompt to the model and relays each result. ${FILLER}`
const DRAWN = `${DENSE}\n\n\`\`\`mermaid\nsequenceDiagram\n  UI->>Daemon: prompt\n\`\`\``

type Jev = { waits: number; figure?: string; figureP?: number; strain?: number } | { status: number }

function jevReply(jev: Jev) {
  if ('status' in jev) return { status: jev.status, ok: false, headers: {}, text: '' }
  const figure = jev.figure ?? 'none'
  const body = {
    model: 'jev-latest',
    answers: {
      waits_on_user: { type: 'noul', noul: jev.waits },
      figure: { type: 'choice', choice: figure, confidence: 0.8, probabilities: { [figure]: jev.figureP ?? 0.9 } },
      prose_strain: { type: 'score', score: jev.strain ?? 0, confidence: 0.8, probabilities: {} },
    },
  }
  return { status: 200, ok: true, headers: {}, text: JSON.stringify(body) }
}

function world(on: On, jev: Jev) {
  const fetched: string[] = []
  const statuses: (string | undefined)[] = []
  const suggestions: string[] = []
  const contexts: (readonly string[] | undefined)[] = []
  const clock = mock.clock(on)
  mock.env(on, {})
  on('http.fetch', (_, e) => {
    fetched.push(e.url)
    return { value: jevReply(jev) }
  })
  on('ui.status', (_, e) => {
    statuses.push(e.text)
    return { value: undefined }
  })
  on('prompt.suggest', (_, e) => {
    suggestions.push(e.text)
    return { isShown: true }
  })
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('prompt.submit', (_, e) => {
    contexts.push(e.context)
    return { text: e.text, ...(e.context ? { context: e.context } : {}) }
  })
  return { clock, fetched, statuses, suggestions, contexts }
}

const finish = (answer: string) =>
  ({ answer, durationMs: 1000, isAborted: false, turnId: 'turn-1', reason: 'answer' }) as const
const typed = (text: string) => ({ text, wait: false, origin: { kind: 'composer' } }) as const

const BAND = {
  plugin: 'jev-report',
  component: 'AbovePrompt',
  surface: 'terminal',
  props: { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 100, scroll: { offset: 0, bodyRows: 6 }, view: {} },
} as const

describe('parseAnswer', () => {
  test('reads the numbered items under What I need from you', async () => {
    const parsed = parseAnswer(ASKING)
    expect(parsed.hasAskSection).toBe(true)
    expect(parsed.asks).toEqual([
      'Run `sudo darwin-rebuild switch --flake ~/nix-config` in your terminal, then reply "rebuilt".',
      'Pick the default model in Settings.',
    ])
  })

  test('sees a Mermaid block or a table as a figure', async () => {
    expect(parseAnswer(DRAWN).hasFigure).toBe(true)
    expect(parseAnswer('| a | b |\n|---|---|\n| 1 | 2 |').hasFigure).toBe(true)
    expect(parseAnswer(DENSE).hasFigure).toBe(false)
  })
})

describe('turn.complete', () => {
  test('pins each ask above the prompt when the report waits on the user', KEYED, async ($, on) => {
    const { statuses , clock } = world(on, { waits: 0.95 })
    await $.turn.complete(finish(ASKING))
    await clock.settle()
    expect(statuses.at(-1)).toContain('◆ 2 for you')
    const ui = await $.ui.mount(BAND)
    expect((await ui.find({ type: 'Text', text: /darwin-rebuild/ }))?.text).toContain('1. Run sudo darwin-rebuild')
    await ui.unmount()
  })

  test('tells the model once that an ask section held nothing', KEYED, async ($, on) => {
    const { contexts, statuses , clock } = world(on, { waits: 0.05 })
    await $.turn.complete(finish(EMPTY_ASK))
    await clock.settle()
    expect(statuses.at(-1)).toBeUndefined()
    await $.prompt.submit(typed('next task'))
    await $.prompt.submit(typed('and another'))
    expect(contexts[0]?.join('\n')).toContain('leave the section out')
    expect(contexts[1]).toBeUndefined()
  })

  test('proposes the figure Jev picks for a dense report without one', KEYED, async ($, on) => {
    const { suggestions , clock } = world(on, { waits: 0.02, figure: 'sequence', figureP: 0.85, strain: 1.8 })
    await $.turn.complete(finish(DENSE))
    await clock.settle()
    expect(suggestions).toEqual(['/show-me that as a Mermaid sequence diagram'])
  })

  test('proposes nothing when the report already has a figure', KEYED, async ($, on) => {
    const { suggestions , clock } = world(on, { waits: 0.02, figure: 'sequence', figureP: 0.85, strain: 1.8 })
    await $.turn.complete(finish(DRAWN))
    await clock.settle()
    expect(suggestions).toEqual([])
  })

  test('leaves a short reply unread', KEYED, async ($, on) => {
    const { fetched , clock } = world(on, { waits: 0.9 })
    await $.turn.complete(finish('Done.'))
    await clock.settle()
    expect(fetched).toEqual([])
  })

  test('still pins the parsed asks when Jev fails', KEYED, async ($, on) => {
    const { statuses , clock } = world(on, { status: 529 })
    await $.turn.complete(finish(ASKING))
    await clock.settle()
    expect(statuses).toContain('jev-report: HTTP 529; report not read')
    expect(statuses.at(-1)).toContain('◆ 2 for you')
  })
})
