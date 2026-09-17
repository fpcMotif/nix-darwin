# Review checklist

Walk this list on every capture. Tick a line only after looking at the image or the log that proves it. Each line carries its fix.

## From the capture log

- [ ] `horizontalOverflow` is false at every width. Fix: give wide tables, code and diagrams `overflow-x: auto` on their own container.
- [ ] `errors` is empty apart from a favicon 404. Fix: open the console message, fix the source line.
- [ ] `failed` lists no image URL. Fix: swap the asset in the content module.

## From the desktop screens

- [ ] Every section's heading is visible in its screen. Fix: the reveal margin is too deep; set it to 0px or -40px.
- [ ] Zero clipped text. Look at stat cells, labels at the right edge of maps, ruler captions. Fix: lower the clamp maximum, allow wrapping, or move the caption above the line.
- [ ] Zero empty grey cells in hairline grids. Fix: reset `margin`, `padding`, `list-style` on the `ul`/`ol` that forms the grid.
- [ ] Two-column sections sit side by side at 1440. Fix: put grid items in the DOM in column order, or set explicit `gridRow`.
- [ ] Borders draw where the brief says (nav hairline, CTA outline, card frames). Fix: a global reset outside a cascade layer is overriding layered styles; move the reset into `@layer base`.
- [ ] Each property with three responsive tiers uses a bounded middle range (`min-width and max-width`). Fix: rewrite the middle tier as a range.
- [ ] Hover state captured for one portfolio item and one region row, and it matches the brief.
- [ ] Focus reaches the same hover device with the keyboard (tab once, capture).
- [ ] Colour pairs match the law: sample the CTA, one eyebrow, one label on the dark band.

## From the mobile screens

- [ ] Stat values fit their cells. Fix: mobile numeral 36px.
- [ ] Decorations that crowd at 390px are hidden: ruler digits, folios, map captions, ticker second row.
- [ ] The mobile menu opens, lists every nav link, and closes on Escape.

## From the code

- [ ] Lint and type checks on the file print nothing.
- [ ] The file header carries the seed and the five findings.
- [ ] Every colour in the file is a token; a grep for `#` inside style objects finds only the one gradient.

Done when two consecutive captures tick every line.
