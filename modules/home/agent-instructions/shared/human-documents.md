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

## Final implementation review

Write one compact review in the PR or the existing design document; it is the only report.

1. **Decision**: State the changed behavior, the unchanged behavior, and the decision the reviewer must make. Completion: a reviewer can name all three from this section alone.
2. **Model**: Draw the smallest diagram that answers a real review question, chosen from the table below. Completion: each diagram answers one question and is drawn once.
3. **Evidence**: One row per requirement or failure mode: requirement | check | observed result | artifact and rerun command. Label static-analysis rows, and label blocked or not-run checks. Completion: the tested revision is stated and every row links an artifact.
4. **Risk**: State remaining gaps, simulated or external boundaries, mutation survivors, and rollout or rollback concerns. Completion: the review stops at ready-for-review; approval and merge stay with the human.

### Choose the diagram by the question

| Review question | Default view |
| --- | --- |
| What happens, and where can it fail? | Mermaid flowchart. |
| Who calls whom, in which order, and where can retries or races occur? | Mermaid sequence diagram with the failure branch. |
| Which states and transitions are allowed? | Mermaid state diagram. |
| Who owns data, contracts, or deployment boundaries? | Mermaid overview; PlantUML component, class, or deployment detail when UML notation answers a different question. |

Keep diagram source beside the document; for PlantUML, attach the rendered SVG or PNG. Render and inspect every changed diagram before submitting it. Render private architecture locally. Trivial changes skip the diagram and the empty sections.
