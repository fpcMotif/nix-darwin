# Decision table

`scripts/fingerprint.py` computes every feature and the register. This file is the human-readable copy of the same rules, plus the presentation table the script cannot express. When the two disagree, the script wins and this file gets fixed.

## Register scoring

Five registers. Each seed scores all five; the highest wins; ties resolve in the order poster, folio, ledger, atlas, specimen.

| Register | Read it as | +3 | +1 each |
|---|---|---|---|
| **specimen** | science editorial: cards with code, symbol, Latin name, assay | ≥ 3 element symbols in the seed (`Sr`, `Fe`, `Na` …) | a 3-digit palindrome in the digit string; digit share 12–20% |
| **poster** | campaign: sans 800 caps, diagonal or mirrored, kinetic | one uppercase letter appears ≥ 5 times (the motif letter) | case flips ≥ 40; upper−lower within ±2; any 3-char palindrome |
| **ledger** | data report: tables, tabular numerals, one sans, dense | digit share ≥ 20% | an ascending or descending digit run (`456`); case flips ≤ 30 |
| **folio** | print magazine: serif-led, diptych columns, folios, drop cap | ≥ 3 doubled bigrams (`II`, `ll`, `00`) | zero element symbols; ≥ 3 zeros; ≥ 17 vowels |
| **atlas** | globe-first: dark opening act with the map, then light | (+2) first zero at ≤ 40% of the string; (+2) motif letter in A M W H N | digits open with a repeat (`6 5 6 6`) |

## Feature → choice

| Feature | Rule | Choice |
|---|---|---|
| length | columns = largest divisor ≤ 12; unit = length ÷ columns | 96 → 12 columns, 8px unit, 96px section rhythm |
| upper − lower | within ±2 → 6/6; upper ahead → 7/5 type-led; lower ahead → 5/7 image-led | hero split |
| case flips | ≥ 40 kinetic; 30–39 standard; ≤ 29 still | motion budget (see law.md for what each allows) |
| zeros | each zero's position ÷ length = a page fraction; keep the first two at ≥ 50%; two zeros closer than 5% merge into one band; atlas keeps one early zero for the hero; ledger keeps every band light | dark bands at those fractions; no zero → light finale on the lightest accent tint |
| motif letter | top uppercase letter with count ≥ 5 | signature device from the motif table below |
| palindromes (`xOx`) | present | mirrored chapters: image left, then image right |
| ascending run or digit share ≥ 20% | present | numbered ledgers for real sequences (steps, rows) |
| element symbols ≥ 3 | present | specimen fields: code, 3-letter symbol from the Latin name, assay |
| doubled bigrams ≥ 3 | present | two-column diptych with a 1px column rule |
| 6-char hex inside the seed | present | one highlight colour = the nearest brand token to that hex; all other colour from the law |
| first character | lowercase / uppercase / digit | opening: eyebrow-first quiet / headline-first loud / numeral-first |
| last character | digit / letter | footer ends on figures / on words |

## Motif letter → signature device

| Letter | Device |
|---|---|
| V, N | diagonal seam between hero halves with a 4px accent stripe; a `V` glyph breaks each section hairline |
| A, M | monumental caps: display at clamp(2.8rem, 6.5vw, 6.5rem), letter-spacing 0.02em |
| W, Z | zigzag: alternate cards offset by one grid column |
| O, Q | ring masks on portraits; a ping ring on the headquarters pin |
| I, L, T | vertical hairlines and sideways labels (`writing-mode: vertical-rl`) |
| X | crossing hairlines, a diagonal grid in the hero background |
| S | a ribbon marquee under the hero |
| K | angular bracket frames around figures |
| H, E | ladder grid: hairline rungs between rows |
| none | a hairline ruler with a tick at each digit's position and the digit beneath |

## Presentation by register

Every page uses the same skeleton: nav · hero · proof band · portfolio · industries · quality · global supply · contact · footer. The register decides how each section looks.

| Section | specimen | poster | ledger | folio | atlas |
|---|---|---|---|---|---|
| nav | hairline bar, mono links | chevron-prefixed links, sharp CTA | utility strip above, navy-weight CTA | centred masthead wordmark, links split around it | transparent over the dark hero, turns paper after 40px |
| hero | 7/5 split, one specimen card overlapping the photo | 6/6 split with the diagonal seam, staggered word entrance | report cover: headline + key–value spec card | cover spread: drop cap standfirst, 3:4 plate with "Fig. 1" caption | full-viewport dark map with arcs and pins, ticker of bases |
| proof band | 4-cell hairline grid, serif numerals | 4 numerals on the first dark band | 4 KPI cards, tabular numerals | two stats under the standfirst | 6-cell hairline grid |
| portfolio | specimen tiles that flip to the dark tone on hover | 4:5 photo cards, hover lifts the photo and sweeps an underline | one data table, 40px rows, mono codes, "Spec" links | round ringed portraits 3×2 | A–Z index rows with a sticky preview |
| industries | three 4:5 plates with numerals | mirrored chapters | three tinted 16:9 cards | three 3:4 plates with figure captions | three 3:2 cards + division strip |
| quality | 3 pillars + 6-cell certification strip | pillars + certification strip | pillars + 4-step ledger + status cards | two-column prose + certification table | pillars + 6-cell strip + 4-step row |
| global supply | region list beside the map, hover links row to pin | staircase list with a stepped path | 6-row table | 3/3 split list + small map | 6-cell region strip (map already spent) |
| contact | dark band with radial glow | dark band | tinted light band | dark band, the only one | light band on the lightest accent tint |
| footer | ghost wordmark, columns, colophon | ghost wordmark with the motif letter | dense 4 columns | colophon: issue, typefaces, seed | divisions and bases, ghost wordmark |

## Type by register

| Register | Display | Body | Values |
|---|---|---|---|
| specimen | serif 400, one italic phrase in the accent | sans | mono |
| poster | sans 800 uppercase, −0.04em; serif italic for one word and the big numerals | sans | mono |
| ledger | sans 700 at 48px, one family for everything | sans | mono, tabular |
| folio | serif 400 at clamp(3rem, 5vw, 6rem); drop cap; pull quote italic 36–44px | sans captions | mono folios |
| atlas | sans 800 uppercase wide-tracked; serif italic for the second half of the headline | sans | mono rail |
