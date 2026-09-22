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

Keep one compact Markdown review in the PR or existing design document. Do not create a parallel reporting system.

1. **Decision**: State changed behavior, unchanged behavior, and the decision the human must make.
2. **Model**: Show the smallest diagram that resolves a real review question. Prefer Mermaid for the overview. Add PlantUML detail only when useful; do not redraw the same information twice.
3. **Evidence**: Use a small table: requirement or failure mode | check/scenario | observed result | artifact and rerun command. Distinguish executed test evidence from static-analysis reports; neither is just a PASS count. Show the tested revision and label blocked or unrun checks.
4. **Risk**: State remaining gaps, simulated/external boundaries, and relevant rollout or rollback concerns. For mutation checks, explain important survivors. For generated tests, link minimized failures and replay details. Stop at readiness for review; never imply human approval or merge without authorization.

### Static evidence for TypeScript/JavaScript

When Fallow runs, link its saved JSON report in the same evidence table, labeled static analysis.
Record command, version/configuration, scope, base/revision, verdict, and exit status.
Summarize introduced findings, inherited debt, and decisions: fix, justified exception, or deferred risk.
Keep static findings separate from executed tests and optional production coverage.
For Rust, Python, Go, Nix, or other non-JS/TS code, omit Fallow and follow that project's tooling.

Use significant import-cycle or boundary findings to check Mermaid/PlantUML models against actual dependencies.
A declared boundary without a matching enabled check is not verified by Fallow.
Link optional `fallow viz` HTML only when a code map answers a question the compact diagram cannot.
Do not require both views or dump the whole dependency graph into UML.
Neither a map nor a health score establishes correct behavior or safe deletion.

### Choose the diagram by the question

| Review question | Default view |
| --- | --- |
| What happens, and where can it fail? | Mermaid flowchart. |
| Who calls whom, in which order? Where can retries or races occur? | Mermaid sequence diagram, including the relevant failure branch. |
| Which states and transitions are allowed or forbidden? | Mermaid state diagram. |
| Who owns data, contracts, or deployment boundaries? | Mermaid overview; PlantUML component, class, or deployment detail when UML notation materially clarifies it. |

UML is the modeling notation, not an additional test suite. Mermaid and PlantUML are alternative rendering tools.
Combine a Mermaid overview with a linked PlantUML detail only when they answer different questions.
Keep diagram source beside the document. For PlantUML, attach a rendered SVG or PNG from that source.
Render and inspect every changed diagram; do not submit source alone as visual review evidence.
Use local or approved rendering for private architecture; do not send it to public diagram services.
Trace important diagram transitions or contracts to evidence-table rows; diagrams alone do not establish correctness.
Review contracts, ownership, failure paths, and unnecessary coupling—not whether every class has a box.
Skip diagrams and empty template sections for trivial changes that need no visual explanation.
