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
In a document that is not an issue, when the mechanism stays subtle, load `eli5` for the picture version and link its artifact at the foot.
When later evidence changes the analysis, update the body and attach that evidence to the comment.

The document is done when a reviewer can name the cause, change, and unchanged behavior from **At a glance** alone, without reconstructing the author's reasoning.

## Issues

These steps cover every issue you raise: one finding, a batch of findings, or a spec that `to-spec` publishes.

1. **Vet**: Open the code behind each finding before you write it up. Drop a finding that the code contradicts. Done when every surviving claim cites a `file:line` you read in this session.
2. **Write**: Give each surviving finding its own issue with these parts, in this order:
   - **At a glance**, as above.
   - **Background**: what a reader new to this code must know, then how to make the change. Keep only what the reader needs to act.
   - **Diagram**: one flowchart or sequence diagram from the `review-diagrams` skill, checked, with its `file:line` evidence list under it. In a `to-spec` spec, that list is the one place that names file paths.
   - **Related issues**: a link to each issue this one touches, with one clause on how. Write "None" when it touches none.

   A `to-spec` spec keeps its own template between **Background** and **Diagram**.
3. **Label**: Apply exactly one of `ready-for-agent`, `ready-for-human`, or `needs-triage`, by the project's triage label document.
4. **Explain**: Make one page per issue with the `eli5` skill: big pictures, few words, one key idea. Link the page at the foot of its issue.
5. **Link**: In a batch, create every issue first, then fill each **Related issues** section with the real numbers.

Done when each issue carries its four parts, one label, and its ELI5 link, and your reply lists each dropped finding with the reason.

## ADRs and domain documents

ADRs and GLOSSARY.md follow the `domain-modeling` skill's formats, not the **At a glance** structure above. Without that skill, match the existing files in `docs/adr/` and `GLOSSARY.md`. These rules extend Current-state integrity's Present rule.

An ADR records one current decision, its reason, and any non-obvious constraint. Keep the rejected options that explain the choice. Leave implementation detail in code unless it is the decision.

Before recording a decision, read the relevant code and existing ADRs. Ask the user only about choices the repository cannot answer. Mark proposed behavior as proposed until it is built.

When a decision changes, rewrite its ADR in place. Delete an ADR that no longer holds a current decision. Repair links to it. Never reuse its number. Git history, not the files on disk, shows the highest number used. Do not add superseded notices, amendment banners, or update sections.

When a term changes, update GLOSSARY.md, the ADRs, and the code together. Keep one name per concept.

Before implementation ends, compare the ADR and GLOSSARY.md text with the code and the check output. Resolve contradictions in scope, and state the gaps that remain.

Recording a decision does not authorize the code change it implies.
