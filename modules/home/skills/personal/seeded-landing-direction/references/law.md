# The law

Values that hold for every register. When the brief or the build wants a value that is absent here, take the nearest listed value.

## Colour

- Canvas is the token named paper (pure white). Text is the token named ink.
- The accent leads: eyebrows and section numerals use accent-700; the one italic headline phrase uses accent-600; the primary CTA is accent-500 fill with accent-950 text (hover accent-400).
- Blue is interactive only: links and outline CTAs use blue-700 text; blue is never a surface.
- Dark bands use accent-950 as the ground. Text on it: accent-100 for prose, accent-300 for data, accent-400 for labels, always at full opacity.
- Small text floor is mute-600 on paper. mute-400 and mute-500 are for borders and decoration.
- Division or category colours appear as 8px dots and tag borders only, at most three per viewport.
- One gradient per page: the radial glow inside the dark contact band.
- Every colour is a token from the project token file. A hex found in the seed is mapped to its nearest token before use.

## Type

- Three roles, three families: display, body, values. Numerals use the display or the mono face; never the body face.
- Mono micro-labels: 11px floor, uppercase, letter-spacing 0.22–0.32em.
- Headlines: `text-wrap: balance`; measure ≤ 12ch for the hero, ≤ 18ch for section titles. Body measure ≤ 60ch.
- Tabular numerals wherever digits align.

## Space and structure

- 8px unit. Section padding 72 / 96 / 128px at mobile / tablet / desktop.
- Container 1440–1480px; gutters 20px mobile, 40px desktop.
- Structure is hairlines: 1px lines in the line token, and grids built as `gap: 1px` on a line-coloured ground with paper cells.
- Radius: 6px on buttons, cards and frames; 0 in the poster register; pills only for chips.
- Shadows appear on hover only.
- Photographs get a 1px 10% black inset outline.

## Motion

- Easing `cubic-bezier(0.22, 1, 0.36, 1)`, duration 0.8–0.9s, lift 24–32px, stagger 0.08s.
- Budgets: still = entrance reveals only; standard = reveals plus one marquee; kinetic = reveals, one marquee, word-by-word hero entrance, one parallax.
- Every animation is gated by reduced motion: marquees pause, paths render complete, reveals show content.
- Every hover device has a keyboard path: focus produces the same state.

## Numbering

- Number only real sequences: page chapters in order, process steps, specification codes, index rows. Counts in eyebrows state real totals ("08 specimens").

## Images

- Lazy-load below the fold. Explicit aspect ratios. Alt text from the content module.
