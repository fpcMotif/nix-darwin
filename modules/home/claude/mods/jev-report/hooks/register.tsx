import { atom, read, update } from 'claude-code'
import type { EngineInterface, PluginOptions, Register } from 'claude-code'

import type { Pinned } from '../types'
import {
  answersFrom,
  API_URL,
  decide,
  DEFAULT_MODEL,
  firstLine,
  KEYCHAIN_SERVICE,
  parseAnswer,
  requestBody,
  shouldJudge,
} from './lens'

const JEV_TIMEOUT_MS = 8_000

const pinned = atom({ plugin: 'jev-report', key: 'pinned' } as const, null)

let cachedKey: string | undefined
let lastKeyMissAt = -Infinity
let pendingNudge: string | undefined

async function apiKey($: EngineInterface, options: PluginOptions): Promise<string | undefined> {
  const option = typeof options.typesafe_api_key === 'string' ? options.typesafe_api_key.trim() : ''
  if (option) return option
  if (cachedKey) return cachedKey
  if (Date.now() - lastKeyMissAt < 30_000) return undefined
  const keychain = await $.process
    .run(['security', 'find-generic-password', '-s', KEYCHAIN_SERVICE, '-w'], { timeoutMs: 3000 })
    .catch(() => undefined)
  const fromKeychain = keychain?.exitCode === 0 ? keychain.stdout.trim() : ''
  // The Keychain wins so a key loaded from a plaintext .env cannot override it.
  const key = fromKeychain || (await $.env.get('TYPESAFE_API_KEY'))?.trim()
  if (key) return (cachedKey = key)
  lastKeyMissAt = Date.now()
  return undefined
}

async function askJev($: EngineInterface, key: string, model: string, answer: string) {
  const call = $.http.fetch(API_URL, {
    method: 'POST',
    headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
    body: JSON.stringify(requestBody(model, answer)),
  })
  const timeout = $.clock.sleep(JEV_TIMEOUT_MS).then(() => undefined)
  const response = await Promise.race([call, timeout]).catch(() => undefined)
  if (!response) return { failure: `no answer within ${JEV_TIMEOUT_MS / 1000} s` }
  if (response.status === 401) cachedKey = undefined
  if (!response.ok) return { failure: `HTTP ${response.status}` }
  try {
    const answers = answersFrom(JSON.parse(response.text))
    return answers ? { answers } : { failure: 'an answer without the expected fields' }
  } catch {
    return { failure: 'a reply that was not JSON' }
  }
}

async function pin($: EngineInterface, asks: readonly string[]) {
  const next: Pinned | null = asks.length > 0 ? { asks } : null
  await update($, pinned, () => next)
  $.ui.status(asks.length > 0 ? `◆ ${asks.length} for you · ${firstLine(asks[0] ?? '', 40)}` : undefined)
}

export const register: Register = (on, options: PluginOptions) => {
  const model = typeof options.model === 'string' && options.model.trim() ? options.model.trim() : DEFAULT_MODEL

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined || e.reason !== 'answer') return result
    const parsed = parseAnswer(e.answer)
    if (!shouldJudge(e.answer, parsed)) {
      await pin($, [])
      return result
    }
    const key = await apiKey($, options)
    if (!key) {
      await pin($, parsed.asks)
      return result
    }
    const judged = await askJev($, key, model, e.answer)
    if ('failure' in judged) {
      $.ui.status(`jev-report: ${judged.failure}; report not read`)
      await pin($, parsed.asks)
      return result
    }
    const lens = decide(parsed, judged.answers)
    pendingNudge = lens.nudge
    await pin($, lens.asks)
    if (lens.suggestion) await $.prompt.suggest({ text: lens.suggestion })
    return result
  })

  on('prompt.submit', async ($, e, next) => {
    const nudge = pendingNudge
    pendingNudge = undefined
    if (e.command || !nudge) return next(e)
    return next({ ...e, context: [...(e.context ?? []), nudge] })
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const shown = await read($, pinned)
    if (e.props.hasSurvey || shown === null) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        {shown.asks.map((ask, index) => (
          <Text key={`ask-${index}`}>
            <Text color="yellow">◆ </Text>
            {shown.asks.length > 1 ? `${index + 1}. ` : ''}
            {firstLine(ask, 96)}
          </Text>
        ))}
        <Box>
          <Button key="done" label="Done" onPress={() => pin($, [])} />
        </Box>
      </Box>
    )
  })
}
