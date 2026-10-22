export const KEYCHAIN_SERVICE = 'typesafe-api-key'
export const DEFAULT_MODEL = 'jev-latest'
export const API_URL = 'https://api.typesafe.ai/v1/systemone'

// A short reply with no ask section has nothing for Jev to read.
export const MIN_JUDGED_CHARS = 280
export const MAX_JUDGED_CHARS = 24_000

const ASK_HEADING = /^\s*(?:#{1,6}\s*|\*\*)?What I need from you\b/i
const HEADING = /^\s*(?:#{1,6}\s|\*\*[^*]+\*\*\s*$)/
const NUMBERED = /^\s*\d+[.)]\s+(.+)$/
const FIGURE = /^\s*```(?:mermaid|diff)\b|^\s*\|?\s*:?-{3,}:?\s*\|/m

export const FIGURES = {
  none: {
    criterion: 'No figure: the message is short, or its points stand apart and read well as text',
    view: '',
  },
  flowchart: {
    criterion: 'A flowchart: steps, decisions, or parts that feed one another',
    view: 'a Mermaid flowchart',
  },
  sequence: {
    criterion: 'A sequence diagram: calls or messages passed between components in order',
    view: 'a Mermaid sequence diagram',
  },
  state: {
    criterion: 'A state diagram: something that moves between named states',
    view: 'a Mermaid state diagram',
  },
  file_tree: {
    criterion: 'A file tree: files or folders that were added, moved, or removed',
    view: 'a diff file tree',
  },
  table: {
    criterion: 'A table: several items compared on the same fields, such as before and after',
    view: 'a table',
  },
  page: {
    criterion: 'A visual page: a layout, UI, or dense concept that no text diagram can hold',
    view: 'one focused HTML page',
  },
} as const
export type Figure = keyof typeof FIGURES
const FIGURE_NAMES = Object.keys(FIGURES) as Figure[]

export type Parsed = {
  readonly hasFigure: boolean
  readonly hasAskSection: boolean
  readonly asks: readonly string[]
}

export function parseAnswer(answer: string): Parsed {
  const lines = answer.split('\n')
  const start = lines.findIndex(line => ASK_HEADING.test(line))
  const asks: string[] = []
  if (start >= 0)
    for (const line of lines.slice(start + 1)) {
      if (HEADING.test(line) && !NUMBERED.test(line)) break
      const item = NUMBERED.exec(line)?.[1]?.trim()
      if (item) asks.push(item)
    }
  return { hasFigure: FIGURE.test(answer), hasAskSection: start >= 0, asks }
}

export function shouldJudge(answer: string, parsed: Parsed): boolean {
  return answer.length <= MAX_JUDGED_CHARS && (parsed.hasAskSection || answer.length >= MIN_JUDGED_CHARS)
}

export function requestBody(model: string, answer: string) {
  return {
    model,
    state: { message: answer },
    questions: {
      waits_on_user: {
        type: 'noul',
        instructions:
          'Does `message` ask its reader to do something or decide something before the work can continue? ' +
          'An offer of optional extra work does not count, and neither does a remark that nothing is needed.',
      },
      figure: {
        type: 'choice',
        instructions: 'Which single figure would make `message` easiest to follow for a reader who scans it first?',
        criteria: Object.fromEntries(FIGURE_NAMES.map(name => [name, FIGURES[name].criterion])),
      },
      prose_strain: {
        type: 'score',
        instructions: 'How hard is `message` to follow as plain prose, without any figure?',
        criteria: [
          'Easy: a short answer, or a few facts that stand apart',
          'Moderate: several connected steps or parts that the reader must hold in mind',
          'Hard: a flow, structure, or comparison that the prose spreads across many sentences',
        ],
      },
    },
  }
}

export type Answers = {
  readonly waits: number
  readonly figure: Figure
  readonly figureP: number
  readonly strain: number
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)
const isFigure = (value: unknown): value is Figure => typeof value === 'string' && value in FIGURES

export function answersFrom(body: unknown): Answers | undefined {
  if (!isRecord(body) || !isRecord(body.answers)) return undefined
  const { waits_on_user: waits, figure, prose_strain: strain } = body.answers
  if (!isRecord(waits) || typeof waits.noul !== 'number') return undefined
  if (!isRecord(figure) || !isFigure(figure.choice) || !isRecord(figure.probabilities)) return undefined
  if (!isRecord(strain) || typeof strain.score !== 'number') return undefined
  const figureP = figure.probabilities[figure.choice]
  return {
    waits: waits.noul,
    figure: figure.choice,
    figureP: typeof figureP === 'number' ? figureP : 0,
    strain: strain.score,
  }
}

export const THRESHOLDS = {
  pin: 0.4,
  unfiled: 0.75,
  empty: 0.2,
  figure: 0.6,
  strain: 1.0,
} as const

export type Lens = {
  readonly asks: readonly string[]
  readonly nudge?: string
  readonly suggestion?: string
}

export function decide(parsed: Parsed, answers: Answers): Lens {
  const asks = parsed.asks.length > 0 && answers.waits >= THRESHOLDS.pin ? parsed.asks : []
  const nudge =
    parsed.hasAskSection && answers.waits < THRESHOLDS.empty
      ? 'jev-report: your last message had a What I need from you section, but nothing in it waited on the user. ' +
        'When nothing waits, leave the section out and end on the report.'
      : !parsed.hasAskSection && answers.waits >= THRESHOLDS.unfiled
        ? 'jev-report: your last message asked the user to act outside a What I need from you section. ' +
          'Put each request there as a numbered item that names the action, where to do it, and what to reply.'
        : undefined
  const wantsFigure =
    !parsed.hasFigure &&
    answers.figure !== 'none' &&
    answers.figureP >= THRESHOLDS.figure &&
    answers.strain >= THRESHOLDS.strain
  const suggestion = wantsFigure ? `/show-me that as ${FIGURES[answers.figure].view}` : undefined
  return { asks, ...(nudge ? { nudge } : {}), ...(suggestion ? { suggestion } : {}) }
}

export const firstLine = (text: string, max = 72) => {
  const line = text.replace(/[`*_]/g, '').trim()
  return line.length > max ? `${line.slice(0, max - 1)}…` : line
}
