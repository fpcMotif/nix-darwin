---
name: ground-truth-audit
description: >-
  Ground-truth audit of a bulk extraction: render each source unit beside the
  artefacts taken from it and judge the pair — PDF to image, OCR to text, scrape
  to records. Use when checking extractor output at scale with a vision or judge
  model, when a proposed filter change needs its blast radius measured, when
  artefact and source counts disagree, or when assembling a side-by-side pack for
  the calls a human must make.
---

# Ground-truth audit

An extractor's report is drawn from the same assumptions that produced its output, so a
filter silently discarding a third of the real content still prints a clean summary.
Ground truth — the source rendered independently of the extractor — is what closes the gap
between what the source holds and what the artefact carries.

The loop below is ordered. Each step's completion criterion is written to be checkable —
run the check rather than judging it by eye.

## 1. Pair every artefact with its ground truth

Render the **whole source unit** — the page, the record, the original file — and put it
beside the artefacts taken from it. A reviewer holding only the artefact can answer *is
this any good*; only a reviewer holding the source can answer *is anything missing*. That
second question is the one worth asking, and it is unaskable without ground truth.

Group by source unit, not by artefact. One page with its three crops is a reviewable unit;
three crops alone are three unanswerable questions.

**Done when** every artefact under audit has a rendered source beside it, and the count of
rendered sources matches the count of source units that produced an artefact.

## 2. Turn each classification into an obligation

When the audit assigns a category, make the category imply a mechanically checkable
artefact, then check it in code. A judge that says *this is a data table* owes a
transcribed table; one that says *this is a flowchart* owes both a diagram and prose steps.

Write the obligations as a validator over the returned labels — one function, one table of
category to required field. It catches the plausible-looking label that skipped the work,
which is the failure a spot-check never finds because the label reads fine.

**Done when** a validator run over every label reports zero unmet obligations, and the
validator has a test per category proving it rejects the empty payload.

## 3. Fan out reviewers

One reviewer per unit, on a cheap model, in parallel. Each writes its full detail to a file
on disk and returns only a compact summary, so the detail outlives the transcript and the
orchestrator's context stays spendable on the next step.

Read [`FANOUT.md`](FANOUT.md) for the harness: sharding, the reviewer prompt shape,
recovering dead units, and what to do when a corpus is too large for one pass.

**Done when** every unit has a result file.

## 4. Close the coverage loop in both directions

Two symmetric checks, and either one alone hides drift:

- **Gaps** — artefacts on disk with no verdict. A unit that died mid-write leaves a file
  that exists, parses as nothing, and vanishes from the totals while they still look
  plausible.
- **Orphans** — verdicts naming an artefact that no longer exists. A re-cut renumbers or
  removes an artefact and leaves its verdict behind, inflating the count past the number of
  artefacts that exist.

An orphan and a gap in the same run cancel in the total and leave it looking correct.

**Done when** gaps and orphans are both zero, or every survivor is listed by path and side,
opened, and its cause named as a mechanism — the trap that manufactured it, or the
exclusion that intended it.

## 5. Verify a verdict before acting on it

Reviewers are confidently wrong often enough to matter, and their wrongness is
plausible — a missing figure reported on the wrong page because the document restarts its
own page numbering; a regression attributed to current source that was measured against an
older build. Take the specific claim, find the cheapest independent check, and run it.
Grep the source for the thing said to be missing. Diff the two builds. Open the file.

Reviewers are also right in ways you are not, so check the claims that contradict you with
the same energy as the ones that flatter you.

**Done when** every finding has been reproduced or refuted by a check that does not route
through the reviewer that raised it, and each dismissal names the check that refuted it.

## 6. Measure the blast radius before changing a rule

A threshold change is a corpus-wide edit. Before applying it, count what it touches and
look at the tail: how many artefacts does the new rule move, and are they the ones you
meant? A rule that rescues one known defect and moves exactly one artefact is safe; a rule
that moves two hundred is a different change than the one you intended.

After applying it, diff the builds and classify every difference as new, lost, or changed.
Match on geometry or content, since ids renumber when a unit's contents shift and an
id-keyed diff reports a rename as a deletion plus an addition.

**Done when** the diff is enumerated and every entry is either the intended fix or has been
opened and accepted.

## 7. Escalate what structure cannot settle

Some calls are genuinely the human's — most often the ones where two failure modes pull on
the same knob and the trade sits at a value only they can pick. Ship those as a browsable
page rather than a list in chat: source beside artefact beside destination, one specific
question per case.

`review_pack.py` renders it. Emit the open cases as JSON and run it:

```bash
python3 review_pack.py --schema                        # the cases.json contract
python3 review_pack.py cases.json -o review.html
```

It writes one self-contained file — every image inlined — so the human can open it straight
from disk or forward it to someone else. It refuses to write while any case names an asset
that is not on disk, so a page with silent holes never reaches them.

To check it yourself, serve the directory and load it over `http://`: the in-app browser
declines `file://` URLs. Force the lazy images eager, then confirm the loaded count equals
the image count before handing it over — a page that renders fine above the fold can still
be broken further down.

Write the collector that decides *which cases are open* as its own script, separate from
`review_pack.py`. Then a case drops out of the pack by itself once the extractor stops
producing it, and the pack is one command to rebuild after every change.

**Done when** each open case carries a specific question, the resolved ones are listed as
resolved rather than silently removed, and the rendered page has been opened with every
image confirmed loaded.

## Traps

Each of these produced a wrong number that looked right.

**Key on the file, not the identifier.** Identifiers repeat: revisions share a document id,
and two unrelated procedures share a prefix. Keying output directories, source renders or
verdicts on the id makes one source silently overwrite another. Key on the path.

**Normalise before comparing paths.** macOS stores filenames decomposed; a model writing
the same name back emits it precomposed. Raw string comparison makes them different keys,
so results silently fail to apply while reporting themselves as orphans. Compare NFC.

**Make loaders complain.** A loader that skips an unparseable file keeps the pipeline
running and hides the dead unit. Return the problems alongside the data and print them.

**Bind results to their content, not to their position.** Numbered result files matched to
numbered work files by name break the moment the work is re-sharded. Stamp each result with
the source it describes.

**Keep one build on disk.** A stale sibling build gets read — by a reviewer resolving a
path, by you deriving a total — and it produces a confident, wrong number.

**Confirm the build actually ran.** A lint or format gate in front of a rebuild step can
fail while the surrounding command reports success, leaving the previous artefact in place.
Verifying a stale artefact repeats the same finding and reads as a stubborn bug.

**Emit a reference only for a file that exists.** Writing the link and writing the file are
two operations; when only the first runs, the corpus fills with references that resolve to
nothing and nothing complains.

**Done when** every trap above has been checked against this run's own keying, loaders and
build directory — each settled with the command or file that settled it, or marked
not-applicable — before any count it could fake is reported.
