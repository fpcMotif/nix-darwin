# Human-reviewed documents

Make the document answer these questions, in this order when it helps the reader:

- What is wrong?
- Why does it happen? Explain the general mechanism before the instance, so the reader can recognise another occurrence.
- What changes?
- What stays unchanged?
- What evidence establishes this?

Open with **At a glance**: three sentences that state the problem and cause, the change, and what stays unchanged.

Quote exact evidence and label estimates. Put working cases beside failures.
Add a visual only when it answers one review question better than prose.
When the mechanism stays subtle, including in a spec `to-spec` just published, load `eli5` for the picture version and link its artifact at the foot.
When later evidence changes the analysis, update the body and attach that evidence to the comment.

The document is done when a reviewer can name the cause, change, and unchanged behavior from **At a glance** alone, without reconstructing the author's reasoning.

## ADRs and domain documents

ADRs and CONTEXT.md follow the `domain-modeling` skill's formats, not the **At a glance** structure above. Without that skill, match the existing files in `docs/adr/` and `CONTEXT.md`. These rules extend Current-state integrity's Present rule.

An ADR records one current decision, its reason, and any non-obvious constraint. Keep the rejected options that explain the choice. Leave implementation detail in code unless it is the decision.

Before recording a decision, read the relevant code and existing ADRs. Ask the user only about choices the repository cannot answer. Mark proposed behavior as proposed until it is built.

When a decision changes, rewrite its ADR in place. Delete an ADR that no longer holds a current decision. Repair links to it. Never reuse its number. Git history, not the files on disk, shows the highest number used. Do not add superseded notices, amendment banners, or update sections.

When a term changes, update CONTEXT.md, the ADRs, and the code together. Keep one name per concept.

Before implementation ends, compare the ADR and CONTEXT.md text with the code and the check output. Resolve contradictions in scope, and state the gaps that remain.

Recording a decision does not authorize the code change it implies.
