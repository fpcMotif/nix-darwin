---
name: omp-completion-and-advisor
description: "When to treat advisor blockers as binding, when to pause or escalate off Flash, and how to prove a deliverable is complete. Use in any omp session that is classifying, cataloging, or mutating many items, or after an advisor concern/blocker/error."
---

# Completion, advisor notes, and escalation (omp)

Distilled from Flash 3.8 on session `01a07e76-d188-75b1-84ca-519409b65068` (106 advisor notes: 74 blocker). Load this when the job is bulk Drafts/YouTube/catalog work or when advisor notes start stacking.

## Do the job

1. Run the user task first. Editing a skill is not delivery.
2. Keep the latest user message above older advisor text. A five-row table can be a quality example, not a cap.
3. Examples are examples. If the user pastes five YouTube URLs and then says "do them all," process the full source set.

## Advisor notes

- Severity `blocker` that cites disk, counts, or missing confirmation: fix it or escalate. Do not claim done.
- Severity `concern`: weigh it. If it matches the user goal, fix it. If it contradicts the latest user message, say so and follow the user.
- After **two** failed attempts on the same defect, pause. Do not start a third heuristic regen. Tell the user what failed and wait, or spawn a stronger model.

## Escalation (this machine)

| Situation | Spawn |
| --- | --- |
| Bounded file fix, verify, rewrite one artifact | `codex-spark-worker` (`@worker` / Spark) |
| Semantic classify / abstract of many drafts | `task` (`@task` / Terra), batched by UUID lists |
| Architecture or repeated reasoning failures | `oracle` (`@slow` / Terra xhigh) |
| Screenshots, OCR | vision role (Terra) |

Batch classification through the task role when it can run independently.

## Completeness gates

A report is false unless all of these pass on disk:

1. **Scope set.** Canonical IDs from the stated sources only. Do not union caches into the source set.
2. **Reconciliation.** Metadata UUID/id fields (not a whole-file regex) equal the source set. Print missing / extra / duplicate separately.
3. **Content.** Open the deliverable. Spot-check stratified samples. A URL, first line, `"key":`, `\documentclass`, or `Introductory` is not an abstract.
4. **Atomic write.** Temp file → validators → `fcp` or `os.replace`. Never leave a failed generation as the Desktop file.
5. **Handoff.** Artifact URIs plus unresolved gaps. Never write "polish" when counts disagree.

Presence of an id in a markdown file is not a deep read.
