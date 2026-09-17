---
name: seeded-landing-direction
description: Derive a landing-page creative direction from a random alphanumeric seed and build it. Use when asked to design from a random string, to find subpatterns in a seed, or to produce N distinct landing variants to compare.
---

# Seeded landing direction

One seed becomes one **register** (the page's whole treatment), one **brief** (numbers, tokens, named devices), one built page, and a **clean pass** (two captures in a row with zero review failures). The fingerprint script decides the register; the decision table turns every feature into one choice; the law limits every colour, type and motion choice to a listed value. Follow the steps in order. Each step ends on a "Done when" line; move on only when it holds.

Read [references/adapters.md](references/adapters.md) first and pick the adapter for the stack you are in. It names the token file, the content module, the page file, the dev URL and the stack pitfalls.

## 1. Seed

Run exactly:

```bash
LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 96 > seed.txt
```

Done when: `seed.txt` holds 96 characters. For N variants, make N seeds in N files (`seed-1.txt` …).

## 2. Fingerprint

```bash
python3 scripts/fingerprint.py seed.txt > fingerprint.json
```

Read the whole JSON. The `decisions` block names the register, hero split, motion budget, dark bands, motif device, mirroring, numbering, opening and ending. The `findings` block lists the five strongest facts with their numbers.

Done when: `decisions.register` is one of `specimen`, `poster`, `ledger`, `folio`, `atlas`. For N variants: when a register repeats one already built, draw a new seed for that slot (up to three draws), then keep the best-scoring distinct one.

## 3. Brief

Copy [templates/brief.md](templates/brief.md) to `direction-brief.md` and fill every field from `fingerprint.json`, [references/decisions.md](references/decisions.md) and [references/law.md](references/law.md). Each finding cites its number. Each design field holds a token name, a pixel or clamp value, or a device named in the decision table.

Done when: every field is filled, and a search of the brief for the words "nice", "modern", "clean", "premium", "elegant" finds zero matches.

## 4. Build

Build the page in the adapter's page file with the adapter's section skeleton. Take content only from the content module. Take colours, type and radii only from the token file. Apply the register column of the presentation table in `decisions.md` to every section. Put the seed and the five findings in the file header comment. Run the adapter's lint and type commands on the file.

Done when: the page renders every skeleton section with real content, the file's lint and type checks print nothing, and the header comment carries the seed.

## 5. Capture loop

```bash
URL=<dev url> NAME=<key> OUT=./captures node scripts/capture.mjs
```

Open every image the script writes. Walk [references/review.md](references/review.md) top to bottom, ticking each line. For every unticked line apply its fix recipe, then capture again.

Done when: two consecutive captures tick every line (a clean pass ×2).

## 6. Report

Write eight lines: seed; the five findings with the decision each produced; the register; what the review changed; the capture paths; open risks. For N variants also run `python3 scripts/compare.py captures/variants.json > compare.html` and hand over the file.

Done when: the report exists and every claim in it points to a file that exists.
