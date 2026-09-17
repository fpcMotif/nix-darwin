---
name: labs-google-clone-ground-truth
description: "Measured ground truth of the real labs.google page (structure, hero specs, media assets, copy) and the study/benchmark tooling for the pixel-fidelity clone in googlelab-cc"
---

# labs.google clone — measured ground truth + study tooling

Workspace: /Users/martinfan/devv/googlelab-cc (clone study build, "Northlight Labs").
User directive: replicate labs.google pixel-by-pixel, frame-by-frame (hero, hover, content);
KEEP the WebGL implementation (src/webgl) — never port to the -gsap sibling workspace.

## Real labs.google structure (measured 2026-08-22, viewport 1568x908, scrollHeight 5665)

1. Dark featured hero (~908px): full-bleed VIDEO carousel, 4 slides:
   - Google Flow Music — "Create full songs with our AI music studio."
   - Google Flow — "Bring your stories to life with our AI creative studio."
   - Pomelli — "Create on-brand marketing content for your business."
   - Stitch — "Turn your ideas into UI with our vibe design tool."
   Media (downloaded to public/assets/featured-hero/):
   videos: flow-music-hero-video-updated.webm, google-flow-1440.webm,
   f428-labs-pomelli-hero-video.webm, stitch-hero-experiment-video.webm
   posters: flow-music-poster.webp, google-flow-featured-hero.webp,
   pomelli-poster.webp, stitch-poster.webp (all under labs.google/assets/{videos/featured-hero,images/tools}/)
2. Light section "Be the first to experiment" (pink accent on 'experiment'): horizontal
   image-card rail (AI Edge Boxart, dreambeans, Literature Insights, Hypo...), arrows,
   pills row (All Create Develop Explore Learn).
3. Statement: "Discover our latest experiments and help shape the future of AI technology..."
4. "Life beyond the Lab" + three dark phone-mockup cards (Google Gemini / Google Flow /
   Gemini Notebook), each "Try it now".
5. "Stay connected for early access..." + newsletter/trusted-tester pills + social icons.
6. Falling colorful flat shapes (physics playground).
7. Footer: link columns + GIANT "Google Labs" wordmark + bottom bar.

## Measured hero specs
- Title: H2, Google Sans 120px/138px, weight 400, white, centered y~309.
- Subheading: 24px (SMALL tag). CTA: liquid button 182x65 center (784,566), 21px label.
- Arrows: "Previous/Next experiment" 60x60 circles at (620,833) and (949,833).
- Progress: container (650,803) 269x65; active bar 135x8 at y832, track rgb(243,239,234);
  inactive slides are 8px dots. Real page: Angular (app-featured-hero), slide advance not
  triggerable via synthetic .click() on arrows.
- Body bg transparent; the video IS the background; floating "cards" live inside the videos.

## Tooling in repo (all need Chrome on CDP_PORT, default 9334)
- tools/study-capture.mjs --target labs|clone --out DIR: exhaustive screenshot study
  (entrance, sweep @DPR2, hero hovers + CTA spring timestamps, card hovers, pill hovers
  + all 5 theme end-states, flip choreography frames 60-1400ms, card hovers, physics
  grab/drag/throw, footer hover, fullpage DPR1+DPR2).
- tools/record-frames.mjs: frame-by-frame motion recorder (virtual clock stepped per
  frame, all animations pinned to absolute t, one PNG per frame).
- tools/bench-pixel-fidelity.mjs + autoresearch.sh: 9-keyframe pixel benchmark vs
  fixtures/reference (self-reference guard). Autoresearch session: pixel-fidelity-webgl.

## Hard-won gotchas
- Headless Chrome exits (code 0) when its last tab closes — not a crash.
- /json/new?<encoded-url> lands off-app; open about:blank then Page.navigate.
- Regex literals inside template literals sent via Runtime.evaluate lose backslashes;
  interpolate JSON.stringify(new RegExp(...).source).
- Resolved interaction points frozen into meta.json must never double as execution gates.
- SwiftShader AA on blurred rotating edges gives a load-dependent ~0.07-0.12% pixel noise
  floor; identical tree scores 0.0000 when quiet. Never widen pixelmatch threshold to hide it.
- Concurrent editors rewrite harness files constantly: re-read + fresh tags before edits.
- Clone vs real labs.google = ~87% pixel diff (content differs); parity work = porting the
  structure/copy/media above section by section, hero first (FeaturedHero.tsx rewritten,
  needs side-by-side verification next).
