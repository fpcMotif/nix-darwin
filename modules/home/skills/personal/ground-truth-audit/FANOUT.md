# The reviewer fleet

The fan-out branch of [`ground-truth-audit`](SKILL.md): how to run hundreds of vision checks
in parallel without losing the detail or the ability to re-run what failed.

## Shard by source unit

One unit file per reviewer, holding the ground truth and the artefacts to judge:

```json
{
  "unit_id": "FCN-FI-007#3",
  "rel": "FCN/财务/FCN-FI-007 科技税务会计标准作业程序SOP.pdf",
  "pages": [{"page_png": "…/p003.png", "artefacts": [{"id": "fig-p003-01", "png": "…"}]}]
}
```

Carry `rel` — the source path — inside both the unit file and every result the reviewer
writes. That is what binds a result to its source when the shards are rebuilt.

Size by review work, not by artefact count. A pass that only judges crops takes ~12 per
unit; a pass that also transcribes tables takes ~8. Group by source unit within a document
so a reviewer reads one page's artefacts together.

## The reviewer prompt

Five things earn their place in it:

- **Name the vision task.** Say the judgement comes from opening the pictures, because the
  metadata in the unit file is a tempting shortcut that produces confident, unlooked-at
  answers.
- **Define each category by what the reader learns**, not by what the thing looks like.
  *A grid of values you read one cell out of* separates cleanly; *a table* does not.
- **State the obligation per category**, and say which one is graded. Naming the common
  failure directly — *a diagram with no prose steps is a failure* — moves the rate.
- **Ask for what is missing**, not only whether what is present is good. This is the half
  that needs ground truth, and it is the half a reviewer skips unless asked.
- **Give the exact output path and shape**, including one entry per artefact with matching
  ids, and ask it to confirm the JSON parses before finishing.

## Detail to disk, summary to the orchestrator

Each reviewer writes its full per-artefact detail to a file and returns counts plus the
worst examples. Hundreds of full verdicts will not fit in one context, and the detail is
what you need later to fix things.

Return a schema-validated summary so a malformed response is retried at the tool layer
rather than parsed hopefully downstream.

## Recovering the failures

Expect a few units per hundred to die on connection errors, and expect the failures to
cluster on the units carrying the most work. Re-run those individually rather than
re-running the batch: a full re-run costs the whole corpus again and rewrites results that
were already fine.

A re-run writes a new result file rather than editing the old one, so one artefact can be
described twice. Read results in name order, file re-runs above the originals, and
deduplicate on `(source path, artefact id)` keeping the last. Without that, every re-judged
artefact is counted twice and the total exceeds the number of artefacts that exist.

## Re-running only what changed

After an extractor change, re-judge the artefacts whose crops moved, not the whole corpus.
Diff the builds on geometry, take the union of new and changed artefacts, and shard just
those into supplementary units numbered well above the originals so the existing files stay
put.

Stale results for artefacts that no longer exist surface as orphans in the coverage check —
which is where they should be caught, not silently dropped by the loader.
