---
name: chrome-extension-frameshift-visual-diff
description: Automate visual regression diff sweeps and Frameshift report generation for Chrome extension pages over CDP port 9222 using Bun and pixelmatch
---

# Chrome Extension Frameshift Visual Diff Workflow

Automated visual regression testing and Frameshift-compatible report generation for Chrome extension pages (options.html, popup.html) over Chrome DevTools Protocol (CDP port 9222) using Bun, pixelmatch, and pngjs.

## Prerequisites

```bash
bun add -d pixelmatch pngjs @types/pixelmatch @types/pngjs
```

Ensure Chrome is running with remote debugging:
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
```

## 1. Extension Target Discovery via CDP

Extension pages run under `chrome-extension://<id>/`. Query `http://127.0.0.1:9222/json/list` and match `type === 'page'` and the extension origin:

```ts
async function getExtensionTarget(): Promise<{ wsUrl: string; extBaseUrl: string }> {
  const targets = await (await fetch('http://127.0.0.1:9222/json/list')).json()
  const target = targets.find((t: { type?: string; url?: string }) =>
    t.type === 'page' && t.url && t.url.startsWith('chrome-extension://')
  )
  if (!target) throw new Error('No active Chrome extension page target found on CDP 9222')
  const extBaseUrl = target.url.match(/chrome-extension:\/\/[a-z0-9]+/i)![0]
  return { wsUrl: target.webSocketDebuggerUrl, extBaseUrl }
}
```

## 2. Checkpoint Capture with High-DPI Emulation

Do not rely on `fullPage: true` (which causes jitter on sticky headers and custom scrollbars). Use fixed viewport checkpoints with device scale factor 2:

```ts
const CHECKPOINTS = [
  { name: 'options__saving', urlPath: 'options.html#saving', width: 1200, height: 800 },
  { name: 'options__archive', urlPath: 'options.html#archive', width: 1200, height: 800 },
  { name: 'popup__main', urlPath: 'popup.html', width: 420, height: 620 },
]

for (const cp of CHECKPOINTS) {
  await client.send('Emulation.setDeviceMetricsOverride', {
    width: cp.width,
    height: cp.height,
    deviceScaleFactor: 2,
    mobile: false,
  })
  await client.send('Page.navigate', { url: `${extBaseUrl}/${cp.urlPath}` })
  // Allow DOM and async storage reads to settle
  await new Promise((r) => setTimeout(r, 500))
  const { data } = await client.send('Page.captureScreenshot', { format: 'png' })
  writeFileSync(`${outDir}/${cp.name}.png`, Buffer.from(data, 'base64'))
}
```

## 3. Pixelmatch Diff & Frameshift Report

Compare `baseline/` and `candidate/` images with pixelmatch signature diff color `[253, 141, 104]` (coral):

```ts
const numDiffPixels = pixelmatch(img1.data, img2.data, diff.data, width, height, {
  threshold: 0.1,
  diffColor: [253, 141, 104],
})
```

Output `report.json` with `summary` and `screens` conforming to Frameshift schema, alongside an interactive `report.html` side-by-side visual viewer.
