---
name: annotated-screenshot
description: Capture annotated screenshots of a live page through Chrome DevTools Protocol — drive a gesture (hover, modifier keys, scroll, click), draw numbered callouts/boxes/arrows from live DOM reads, save PNG frames and console traces, then host them on a git branch and embed them in a GitHub issue or PR. Use when a bug report, PR, issue, or showcase needs "show, don't tell" evidence from a real page, when a hover/keyboard gesture must be reproduced exactly, or when a diagnosis needs before/after frames of the same scene.
---

# annotated-screenshot

Two scripts, no dependencies (bun or node ≥ 22):

- `scripts/cdp-annotate.mjs scene.json [--cdp URL] [--out DIR] [--var k=v]` — runs a **scene** against a running Chrome and writes PNG frames (+ `trace.log`).
- `scripts/gh-attach.mjs <pngs…> [--issue N | --pr N] [--caption …]` — pushes the frames to an `assets/<slug>` branch via a temp worktree and prints/post the embedding markdown.

## Steps

1. **Find the Chrome.** `curl -s http://localhost:9222/json/version` (use `localhost`, not `127.0.0.1` — Chrome often binds `[::1]`). If nothing answers, ask the user to launch Chrome with `--remote-debugging-port=9222` (their logged-in profile is usually the point); launch your own only when no login is needed. Done when `/json/list` returns targets.
2. **Write the scene** (copy the closest file in `examples/`). A scene is `url` or `tab` (regex of an open tab), optional `viewport`/`colorScheme`/`traces`, and ordered `steps`. Targets anywhere in a scene are a CSS selector, `js:<expr>` returning an Element/rect/point, `{x,y}`, `@cursor`, `@hover` (the last hovered element, re-measured live), or `@last`; wrap as `{ "target": …, "offset": [dx, dy] }` to nudge. Done when every annotation's text states a fact you read from the page or a log — callouts are evidence, not captions.
3. **Run it**, then look at every PNG you captured before using it. Fix clipped or overlapping labels by shortening lines, moving `anchor`/`dx`/`dy`, or widening `viewport`. Done when each frame reads top-to-bottom without the reader needing the scene file.
4. **Attach.** `gh-attach.mjs` with `--dry-run` first (prints the markdown and where it would push), then for real; add `--issue N`/`--pr N` to post as a comment, or paste the printed markdown into a body. Done when the raw URLs return 200.

## Scene reference

Steps run in order; one object may combine several keys (they execute in the order below):

| key | effect |
|---|---|
| `wait` ms · `waitFor` selector or `js:` (timeout 20 s) | pacing |
| `evaluate` js (`print: true` logs the value) | arbitrary page setup |
| `scrollTo` target (`block`, `settle` ms) · `scrollBy` px | viewport placement |
| `hover` target (`dx`, `dy`, `modifiers`) · `nudge` [px…] (`every` ms) · `click` target | trusted pointer input (CDP) |
| `keyDown` / `keyUp` name or [names] — `Alt` `Meta` `Shift` `Control` `Enter` `Escape` … | held modifiers ride on every later mouse event |
| `type` text | `Input.insertText` |
| `annotate` [items] · `capture` file.png (`fullPage`, `keepAnnotations`) | draw, then shoot; the layer is removed after each capture |

Annotation items: `box` target (`color`, `pad`, `solid`) · `label` text or [lines] with `at` target + `anchor` right/left/above/below/at (`gap`, `dx`, `dy`, `size`) or absolute `x`/`y` · `arrow` `{from, to}` · `banner` [lines] (`position` top/bottom). Colors: `red green blue orange ink purple yellow` or hex. Number callouts yourself (①②③) in the label text — numbering only means something when the frame is a sequence.

Scene-level: `traces` — tail console lines from other targets (`type`, `match` substring of the target url, `filter` substring, optional `evaluate` run once on attach, e.g. to stub a downloader) into `trace.log` and the JSON result; `pageConsole` substring to keep page console lines; `bringToFront: false` when the user is at the keyboard (bringing the tab forward steals their OS focus and a `blur` hits the page); `keepTab: true` to leave the tab open; `${VAR}` in the file is filled from `--var` or the environment.

## Gotchas

- `Page.bringToFront` is on by default because background tabs throttle timers (a 500 ms dwell becomes 1–1.5 s). If the user is active, prefer `bringToFront: false` and longer waits over fighting them for focus.
- CDP-injected modifier keys are not physical: any **synthetic** mousemove Chrome emits on its own carries the real (unpressed) modifier state. A page that re-reads modifiers from pointer events may drop a held key mid-gesture — that is a loop artifact, not a page bug.
- Annotations are drawn from the DOM at capture time; virtualized lists recycle nodes, so resolve with `@hover` / `js:` expressions rather than cached coordinates.
- Pushing assets is outward-facing: run `--dry-run` first, and keep the branch dedicated (`assets/<slug>`), never the working branch.

Worked example: `examples/threads-cloaked-img.json` — the Threads `pointer-events:none` Quick Grab bug (x-media-downloader #92): stubs the extension's downloader through a service-worker trace, hovers with Alt+Meta held, and shoots before/after frames with five numbered callouts.
