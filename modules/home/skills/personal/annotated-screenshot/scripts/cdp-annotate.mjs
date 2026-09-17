#!/usr/bin/env bun
// cdp-annotate — drive a CDP Chrome through a declarative scene, draw annotations
// in-page from live DOM reads, capture PNG frames (+ optional console traces).
//
//   bun cdp-annotate.mjs scene.json [--cdp http://localhost:9222] [--out DIR] [--var k=v ...]
//
// Scene format: see ../SKILL.md and ../examples/*.json. No dependencies (bun or node ≥ 22).
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const args = process.argv.slice(2)
const scenePath = args.find((a) => !a.startsWith('--'))
if (!scenePath) { console.error('usage: cdp-annotate.mjs scene.json [--cdp URL] [--out DIR] [--var k=v]'); process.exit(2) }
const opt = (name, dflt) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : dflt }
const vars = Object.fromEntries(args.flatMap((a, i) => (a === '--var' ? [args[i + 1].split(/=(.*)/s).slice(0, 2)] : [])))
const sceneText = readFileSync(scenePath, 'utf8').replace(/\$\{(\w+)\}/g, (_, k) => vars[k] ?? process.env[k] ?? `\${${k}}`)
const scene = JSON.parse(sceneText)
const CDP = opt('cdp', scene.cdp ?? 'http://localhost:9222')
const OUT = resolve(opt('out', scene.out ?? dirname(resolve(scenePath))))
mkdirSync(OUT, { recursive: true })
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const stamp = () => new Date().toISOString().slice(11, 23)
const log = (...a) => console.error(`[annotate ${stamp()}]`, ...a)

function connect(wsUrl, onEvent) {
  const ws = new WebSocket(wsUrl)
  let id = 0
  const pending = new Map()
  ws.addEventListener('message', (ev) => {
    const m = JSON.parse(String(ev.data))
    if (m.id && pending.has(m.id)) { const { resolve, reject } = pending.get(m.id); pending.delete(m.id); m.error ? reject(new Error(`${m.error.message ?? JSON.stringify(m.error)}`)) : resolve(m.result) }
    else if (m.method) onEvent?.(m)
  })
  const send = (method, params = {}) => new Promise((resolve, reject) => { const mid = ++id; pending.set(mid, { resolve, reject }); ws.send(JSON.stringify({ id: mid, method, params })) })
  return new Promise((resolve, reject) => { ws.addEventListener('open', () => resolve({ send, close: () => ws.close() })); ws.addEventListener('error', reject) })
}
const argToStr = (a) => a?.value ?? a?.description ?? a?.unserializableValue ?? a?.type ?? ''

// ---- traces: tail console lines from extra targets (service workers, other pages) ----
const traceLines = []
const traceConns = []
for (const t of scene.traces ?? []) {
  const targets = await (await fetch(`${CDP}/json/list`)).json()
  const hit = targets.find((x) => (t.type ? x.type === t.type : true) && (t.match ? x.url.includes(t.match) : true))
  if (!hit) { log(`trace target not found: ${JSON.stringify(t)}`); continue }
  const c = await connect(hit.webSocketDebuggerUrl, (m) => {
    if (m.method !== 'Runtime.consoleAPICalled') return
    const text = (m.params.args ?? []).map(argToStr).join(' ')
    if (!t.filter || text.includes(t.filter)) traceLines.push(`[${stamp()}] (${t.name ?? hit.type}) ${text}`)
  })
  await c.send('Runtime.enable')
  if (t.evaluate) await c.send('Runtime.evaluate', { expression: t.evaluate, awaitPromise: true, returnByValue: true })
  traceConns.push(c)
  log(`tracing ${hit.type} ${hit.url.slice(0, 60)}`)
}

// ---- page target ----
let target
if (scene.tab) {
  const targets = await (await fetch(`${CDP}/json/list`)).json()
  target = targets.find((x) => x.type === 'page' && new RegExp(scene.tab).test(x.url))
  if (!target) throw new Error(`no open tab matches /${scene.tab}/`)
} else {
  target = await (await fetch(`${CDP}/json/new?${encodeURIComponent(scene.url ?? 'about:blank')}`, { method: 'PUT' })).json()
}
const pageLines = []
const page = await connect(target.webSocketDebuggerUrl, (m) => {
  if (m.method !== 'Runtime.consoleAPICalled') return
  const text = (m.params.args ?? []).map(argToStr).join(' ')
  if (scene.pageConsole === undefined || text.includes(scene.pageConsole)) pageLines.push(`[${stamp()}] (page) ${text}`)
})
await page.send('Page.enable'); await page.send('Runtime.enable')
const vp = { width: 1440, height: 840, scale: 2, ...(scene.viewport ?? {}) }
await page.send('Emulation.setDeviceMetricsOverride', { width: vp.width, height: vp.height, deviceScaleFactor: vp.scale, mobile: false })
if (scene.colorScheme) await page.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: scene.colorScheme }] })
if (scene.bringToFront !== false) await page.send('Page.bringToFront') // note: steals OS focus from the user
const evaluate = async (expression) => {
  const r = await page.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })
  if (r.exceptionDetails) throw new Error(`evaluate failed: ${r.exceptionDetails.exception?.description ?? r.exceptionDetails.text}\n${expression.slice(0, 200)}`)
  return r.result.value
}

// ---- target resolution (shared by steps and annotations), runs in-page ----
// A target is: a CSS selector · "js:<expr returning Element|DOMRect|{x,y}>" · {x,y} ·
// "@cursor" (pointer) · "@hover" (rect of the last `hover` step's element, re-measured live) · "@last" (last resolved).
// Any target may carry an offset: { "target": <t>, "offset": [dx, dy] }.
const RESOLVE_SRC = `(function(t, named){
  const rectOf = (el) => { const r = el.getBoundingClientRect(); return { left: r.left, top: r.top, width: r.width, height: r.height, right: r.right, bottom: r.bottom, cx: r.left + r.width/2, cy: r.top + r.height/2 } }
  const pt = (x, y) => ({ left: x, top: y, width: 0, height: 0, right: x, bottom: y, cx: x, cy: y })
  if (t === '@cursor') return pt(named.cursor.x, named.cursor.y)
  if (t === '@last') return named.last
  if (t === '@hover') return window.__annotHover instanceof Element ? rectOf(window.__annotHover) : named.hover
  if (typeof t === 'object') return pt(t.x, t.y)
  let v
  if (t.startsWith('js:')) v = (0, eval)(t.slice(3))
  else v = document.querySelector(t)
  if (!v) return null
  if (v instanceof Element) return rectOf(v)
  if (typeof v.left === 'number') return { left: v.left, top: v.top, width: v.width ?? 0, height: v.height ?? 0, right: v.left + (v.width ?? 0), bottom: v.top + (v.height ?? 0), cx: v.left + (v.width ?? 0)/2, cy: v.top + (v.height ?? 0)/2 }
  if (typeof v.x === 'number') return { left: v.x, top: v.y, width: 0, height: 0, right: v.x, bottom: v.y, cx: v.x, cy: v.y }
  return null
})`
const cursor = { x: 0, y: 0 }
let last = null, hover = null
const resolveTarget = async (t) => {
  const spec = t && typeof t === 'object' && 'target' in t ? t : { target: t, offset: [0, 0] }
  const r = await evaluate(`${RESOLVE_SRC}(${JSON.stringify(spec.target)}, ${JSON.stringify({ cursor, last, hover })})`)
  if (!r) throw new Error(`target not found: ${JSON.stringify(t)}`)
  const [dx, dy] = spec.offset ?? [0, 0]
  const out = dx || dy ? { ...r, left: r.left + dx, right: r.right + dx, top: r.top + dy, bottom: r.bottom + dy, cx: r.cx + dx, cy: r.cy + dy } : r
  last = out
  return out
}
// remember the element behind a `hover` step so "@hover" re-measures it live (virtualized DOMs move)
const rememberHover = (t) => evaluate(`(() => { const t = ${JSON.stringify(t)}; window.__annotHover = typeof t === 'string' ? (t.startsWith('js:') ? (0, eval)(t.slice(3)) : document.querySelector(t)) : null; return !!window.__annotHover })()`)

// ---- input ----
const MOD = { alt: 1, ctrl: 2, control: 2, meta: 4, cmd: 4, shift: 8 }
const KEYS = { Alt: ['AltLeft', 18], Meta: ['MetaLeft', 91], Shift: ['ShiftLeft', 16], Control: ['ControlLeft', 17], Enter: ['Enter', 13], Escape: ['Escape', 27], Tab: ['Tab', 9], ArrowDown: ['ArrowDown', 40], ArrowUp: ['ArrowUp', 38] }
let held = 0
const modBits = (list = []) => list.reduce((m, k) => m | (MOD[k.toLowerCase()] ?? 0), 0)
const mouse = async (type, x, y, extra = {}) => {
  cursor.x = x; cursor.y = y
  await page.send('Input.dispatchMouseEvent', { type, x, y, modifiers: held | modBits(extra.modifiers), button: extra.button ?? 'none', clickCount: extra.clickCount ?? 0 })
}
const keyEvent = async (type, name) => {
  const [code, vk] = KEYS[name] ?? [name, 0]
  const bit = MOD[name.toLowerCase()] ?? 0
  if (type === 'down') held |= bit; else held &= ~bit
  await page.send('Input.dispatchKeyEvent', { type: type === 'down' ? 'rawKeyDown' : 'keyUp', key: name, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk, modifiers: held })
}

// ---- annotations: one fixed SVG layer, drawn from live rects ----
const COLORS = { red: '#E2463F', green: '#23A86B', blue: '#2F7BEA', orange: '#FF7A1A', ink: '#111111', purple: '#7E68C9', yellow: '#F2B705' }
const color = (c, dflt) => COLORS[c] ?? c ?? dflt
const FONT = scene.font ?? 'ui-monospace, Menlo, monospace'
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
async function renderAnnotations(items) {
  const parts = []
  const label = (x, y, lines, c, size = 15) => {
    const w = Math.max(...lines.map((t) => t.length)) * size * 0.62 + 24
    const h = lines.length * (size + 7) + 16
    return { w, h, svg: `<g><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="8" fill="${c}" opacity=".96"/>` + lines.map((t, i) => `<text x="${x + 12}" y="${y + size + 9 + i * (size + 7)}" font-family="${FONT}" font-size="${size}" font-weight="${i === 0 ? 700 : 500}" fill="#fff">${esc(t)}</text>`).join('') + '</g>' }
  }
  for (const a of items) {
    if (a.box) {
      const r = await resolveTarget(a.box); const p = a.pad ?? 6
      parts.push(`<rect x="${r.left - p}" y="${r.top - p}" width="${r.width + 2 * p}" height="${r.height + 2 * p}" rx="8" fill="none" stroke="${color(a.color, COLORS.red)}" stroke-width="${a.width ?? 4}" ${a.solid ? '' : 'stroke-dasharray="12 8"'}/>`)
    } else if (a.arrow) {
      const from = await resolveTarget(a.arrow.from), to = await resolveTarget(a.arrow.to); const c = color(a.color, COLORS.orange)
      parts.push(`<line x1="${from.cx}" y1="${from.cy}" x2="${to.cx}" y2="${to.cy}" stroke="${c}" stroke-width="4"/><circle cx="${to.cx}" cy="${to.cy}" r="7" fill="${c}"/>`)
    } else if (a.label) {
      const lines = Array.isArray(a.label) ? a.label : [a.label]
      const c = color(a.color, COLORS.ink); const size = a.size ?? 15
      const probe = label(0, 0, lines, c, size)
      let x, y
      if (a.at) {
        const r = await resolveTarget(a.at); const g = a.gap ?? 16; const pos = a.anchor ?? 'right'
        if (pos === 'right') { x = r.right + g; y = r.top + (a.dy ?? 0) }
        else if (pos === 'left') { x = r.left - g - probe.w; y = r.top + (a.dy ?? 0) }
        else if (pos === 'above') { x = r.left + (a.dx ?? 0); y = r.top - g - probe.h }
        else if (pos === 'below') { x = r.left + (a.dx ?? 0); y = r.bottom + g }
        else { x = r.cx + (a.dx ?? 0); y = r.cy + (a.dy ?? 0) } // 'at'
      } else { x = a.x ?? 24; y = a.y ?? 24 }
      parts.push(label(x, y, lines, c, size).svg)
    } else if (a.banner) {
      const lines = Array.isArray(a.banner) ? a.banner : [a.banner]
      const c = color(a.color, COLORS.ink); const size = a.size ?? 15
      const probe = label(0, 0, lines, c, size)
      const y = (a.position ?? 'bottom') === 'top' ? 16 : vp.height - probe.h - 16
      parts.push(label(24, y, lines, c, size).svg)
    }
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${vp.width}" height="${vp.height}" style="position:fixed;inset:0;z-index:2147483647;pointer-events:none">${parts.join('')}</svg>`
  await evaluate(`(() => { document.getElementById('__annot')?.remove(); const h = document.createElement('div'); h.id = '__annot'; h.innerHTML = ${JSON.stringify(svg)}; document.body.appendChild(h); return true })()`)
}
const clearAnnotations = () => evaluate(`(document.getElementById('__annot')?.remove(), true)`)

// ---- steps ----
const captured = []
for (const [i, s] of (scene.steps ?? []).entries()) {
  try {
    if (s.wait !== undefined) await sleep(s.wait)
    if (s.waitFor) { const t0 = Date.now(); while (!(await evaluate(`!!(${s.waitFor.startsWith('js:') ? s.waitFor.slice(3) : `document.querySelector(${JSON.stringify(s.waitFor)})`})`))) { if (Date.now() - t0 > (s.timeout ?? 20000)) throw new Error(`waitFor timed out: ${s.waitFor}`); await sleep(250) } }
    if (s.evaluate) { const v = await evaluate(s.evaluate); if (s.print) log('evaluate →', JSON.stringify(v)) }
    if (s.scrollTo) { await resolveTarget(s.scrollTo); await evaluate(`(() => { const t = ${JSON.stringify(s.scrollTo)}; const el = t.startsWith('js:') ? (0, eval)(t.slice(3)) : document.querySelector(t); el?.scrollIntoView({ block: ${JSON.stringify(s.block ?? 'center')} }); return true })()`); await sleep(s.settle ?? 800) }
    if (s.scrollBy) await evaluate(`(window.scrollBy(0, ${s.scrollBy}), true)`)
    if (s.hover) { const r = await resolveTarget(s.hover); hover = r; await rememberHover(s.hover); await mouse('mouseMoved', r.cx + (s.dx ?? 0), r.cy + (s.dy ?? 0), s) }
    if (s.nudge) { for (const d of Array.isArray(s.nudge) ? s.nudge : [s.nudge]) { await mouse('mouseMoved', cursor.x + d, cursor.y, s); await sleep(s.every ?? 40) } }
    if (s.click) { const r = await resolveTarget(s.click); const x = r.cx, y = r.cy; await mouse('mouseMoved', x, y, s); await mouse('mousePressed', x, y, { ...s, button: 'left', clickCount: 1 }); await mouse('mouseReleased', x, y, { ...s, button: 'left', clickCount: 1 }) }
    if (s.keyDown) for (const k of [].concat(s.keyDown)) await keyEvent('down', k)
    if (s.keyUp) for (const k of [].concat(s.keyUp)) await keyEvent('up', k)
    if (s.type) await page.send('Input.insertText', { text: s.type })
    if (s.annotate) await renderAnnotations(s.annotate)
    if (s.capture) {
      const shot = await page.send('Page.captureScreenshot', { format: 'png', ...(s.fullPage ? { captureBeyondViewport: true } : {}) })
      const file = resolve(OUT, s.capture); writeFileSync(file, Buffer.from(shot.data, 'base64')); captured.push(file); log(`captured ${file}`)
      if (s.keepAnnotations !== true) await clearAnnotations()
    }
  } catch (err) { log(`step ${i + 1} failed:`, err.message); if (scene.continueOnError !== true) break }
}
// release anything still held so the page is left sane
for (const name of ['Meta', 'Alt', 'Shift', 'Control']) if (held & MOD[name.toLowerCase()]) await keyEvent('up', name)
await sleep(200)

if (scene.traces?.length || scene.pageConsole !== undefined) {
  const logFile = resolve(OUT, scene.log ?? 'trace.log')
  writeFileSync(logFile, [...traceLines, ...pageLines].sort().join('\n') + '\n')
  log(`trace → ${logFile} (${traceLines.length + pageLines.length} lines)`)
}
if (scene.tab === undefined && scene.keepTab !== true) await page.send('Page.close').catch(() => {})
for (const c of traceConns) c.close()
page.close()
console.log(JSON.stringify({ captured, traces: traceLines.slice(-20) }, null, 2))
