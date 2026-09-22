# Human-reviewed documents

Use this process for an issue, specification, PRD, or analysis that a human reviews.

1. Resolve one material choice before writing. Completion: scope and reader are known.
2. Start with “At a glance”. Completion: three sentences state the problem, cause, and change.
3. Explain the general mechanism before the instance. Completion: the reader can recognise another occurrence.
4. Present exact evidence. Completion: estimates are labelled and working cases sit beside failures.
5. Match each relationship to one useful visual. Completion: every visual answers one question.
6. When the mechanism remains subtle — including a spec `to-spec` just published — load `eli5` for the picture version; don't sketch a substitute. Completion: the eli5 artifact is linked at the foot.

The document is done when “At a glance” lets a reviewer name the cause, change, and unchanged behavior.
When later evidence changes the analysis, update the body and attach that evidence to the comment.

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
