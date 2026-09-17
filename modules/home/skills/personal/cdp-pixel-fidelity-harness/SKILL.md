---
name: cdp-pixel-fidelity-harness
description: "Build a deterministic pixel-fidelity benchmark harness (raw CDP): virtual-clock parking, animation seeking, interaction replay, transport hardening, and pixelmatch comparison for clone-vs-frozen-reference autoresearch loops."
---

# Deterministic pixel-fidelity benchmark harness (raw CDP)

Recipe for benchmarking "clone must render pixel-identical to a frozen reference, animations included" against a Vite/SPA build, using raw-WebSocket CDP and Node. Hardened in a real autoresearch session; every rule below was a live bug first.

## Protocol (the part that must never drift)

1. **Virtual clock from the first frame.** `Page.addScriptToEvaluateOnNewDocument` installs a rAF shim: `performance.now()` returns virtual time, each real rAF callback advances it by exactly 1000/60ms, and it **parks at SEEK_T from the very first frame** (`window.__PARK_AT` baked into the shim, not set later). rAF-driven systems (physics integrators, shader `u_time`) then observe an identical timestamp sequence — exactly SEEK_T/STEP callbacks — regardless of machine speed. A late park leaves trajectory length wall-clock-dependent and shows up as edge jitter on soft-body shapes.
2. **Pin WAAPI/CSS separately.** After any interaction settles, `document.getAnimations()` → for each: `a.pause(); a.currentTime = SEEK_T` (clamps finished transitions to end). Mid-transition poses: classify by `a.animationName` / `a.constructor.name === 'CSSTransition' && transitionProperty`, then set an **absolute** currentTime from the track's own start — wall-clock independent. Pin promptly (while tracks are still active).
3. **Interaction points are provenance, never gates.** Resolve text-labeled buttons to viewport points at CAPTURE time (`querySelectorAll('button')` + textContent match + on-viewport check), freeze into `meta.json`, and have replays dispatch `Input.dispatchMouseEvent` at the stored coordinates. If a stored point also guards execution (`if (!kf.point) { …do… }`), capture serializes the point and **benches silently skip the interaction** → huge deterministic mismatch. Execute whenever the action descriptor exists.
4. **Deterministic-by-construction interactions.** Fling/carousel snaps that are `Math.round(projected)` are safe. Space drag moves with fixed virtual-frame waits, not wall-clock sleeps. For converging soft-body fields, prefer settle-at-mount (pure function of box) or fixed-step catch-up; recapture the reference after such an intentional semantic change and say so in the run log.
5. **Fresh page per keyframe**: `Page.navigate` → poll `readyState` → `document.fonts.ready` → poll until `scrollHeight` is stable ~1.5s (SPA splash/content swap) → scroll → optional hover/click with settle ≥ longest transition → seek → double-rAF → `Page.captureScreenshot`.

## Transport hardening (prevents silent hangs)

- `ws.onclose`/`ws.onerror` must **reject every pending call**; a crashed headless Chrome otherwise leaves awaits unsettled forever (exit code 13, "unsettled top-level await").
- Per-send 30s timeout that deletes itself from the pending map.
- `/json/new` and the debugger socket race on a freshly spawned Chrome → wrap connect in a 6× retry (400ms apart), awaiting `opened` inside the try.
- Headless Chrome **exits cleanly when its last tab closes** — not a crash. Keep an `about:blank` guard tab or expect exit 0.
- Open tabs as `about:blank` + explicit `Page.navigate`. `/json/new?<encoded-url>` can land off-app.

## JS-in-page gotchas

- Regex literals inside template literals sent to `Runtime.evaluate` **lose backslashes** (`\(` → `(`, `\d` → `d`) → "Unterminated group". Build with `new RegExp(JSON.stringify(re.source))` interpolation, or `String.raw` at top level.
- `stylex`/utility stacks write multiple properties into one inline `style` attribute — match `style.transform` (the CSS property), not `getAttribute('style')`.
- Find components by transform *shape* (e.g. `/^translate\(-?[\d.]+px, -?[\d.]+px\) rotate\(-?[\d.]+rad\)$/` for rAF-painted bodies) — class names drift, painted output doesn't. Beware near-identical components (arc-carousel cards also rotate).

## Comparison

- `pixelmatch` (threshold 0.1) + `pngjs`; verify real PNG signatures (`file`) — don't trust sniffs.
- Emit `METRIC name=value` lines: aggregate + mean/worst keyframe + a **self-check** (capture every keyframe twice per run through the full protocol and diff the pair → `nondet_worst_pct` separates replay noise from app regressions).
- Expect a load-dependent floor on blurred/rotated edges under SwiftShader (`--disable-gpu`): sub-pixel AA jitter through `blur()` gradients reads as edge drift. Characterize it (same tree, varying load); **never widen the threshold to absorb it** — freeze `filter: blur` at seek time in the protocol instead.
- Diff images localize regressions instantly: thick colored bands on shape outlines = pose/phase shift; faint uniform ghosting = sub-threshold AA noise.

## Discipline

- Re-read harness files before every edit; anchor patches on fresh tags/lines — concurrent writers are common in these sessions.
- Off-limits measurement files may be edited only with explicit justification in the run log (coverage extensions and reliability fixes are legitimate; threshold widening never is).
