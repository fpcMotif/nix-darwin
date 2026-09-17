---
name: labsgoogle-measured-slides
description: "Measured labs.google featured-hero ground truth: real slide titles/taglines/hrefs/video sources, transition anatomy, and grid card list for the GSAP rebuild"
---

# labs.google rebuild — measured ground truth (2026-08-22)

Real featured-hero slides extracted from the live DOM (`https://labs.google/`):

| # | Title | Tagline | CTA href | Hero loop |
|---|---|---|---|---|
| 1 | Google Flow Music | "Discover our latest experiments and help shape the future of AI technology." | flowmusic.app | `featured-hero/flow-music-hero-video-updated.webm` |
| 2 | Google Flow | "Google Flow (formerly VideoFX) is your AI creative studio for creating and refining your stories." | labs.google/fx/tools/flow | `featured-hero/google-flow-1440.webm` |
| 3 | Pomelli | "Create on-brand marketing content for your business." | labs.google.com/pomelli/about/ | `featured-hero/f428-labs-pomelli-hero-video.webm` |
| 4 | Stitch | "Turn your ideas into UI with our vibe design tool." | stitch.withgoogle.com | `featured-hero/stitch-hero-experiment-video.webm` |

Videos: muted, loop, autoplay, playsInline; 1600–1920px wide; object-fit cover; NO filter/transform on the element (blur lives in the footage). No canvas/WebGL on the page. Motion = CSS gl-float-x/y/r SVG shapes + width CSSTransition progress fill + JS carousel.

Transition anatomy (frame-by-frame): text crossfades IN PLACE → dark rounded-hexagon blob scales up over handoff (incoming title readable on panel) → footage crossfades → progress restarts. ~1.1s total.

Experiments grid below hero: desktop/*.mp4 per card (dreambeans, literature-insights, hypothesis-generation, computational-discovery, stitch, pomelli, flow-music, genie, mixboard, opal, stax, jules, learn-your-way, vantage, ai-edge-eloquent).

User intent: the fork's final page must match THIS site's structure/content/motion with GSAP powering it — not the "Northlight Labs" original-content placeholders. Assets © Google; local study build only.
