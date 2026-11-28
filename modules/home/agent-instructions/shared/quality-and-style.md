## Code quality

- **Direct**: Use the simplest direct implementation. A second real use earns an abstraction.
- **Local**: Edit the lines that change. Rewrite a file only when most of it changes.
- **Match**: Follow existing patterns and confirm libraries before using them.
- **Name**: Names carry domain meaning (`GLOSSARY.md` terms), not structural types (`data`, `result`, `item`, `temp`, `handler`) or version suffixes (`V2`, `New`). Replace the old implementation and take its name.
- **Comment**: Comments state only a constraint, tradeoff, unit, or workaround the code cannot express, in at most three lines attached to the code. Write no narration that repeats identifier words, no history notes (`retired`, `used to`, `no longer`, `previously`, `formerly`), no date stamps, and no orphan comments.
- **Edge**: Validate at the input edge and trust internal callers.
- **Oracle**: Derive each test expectation from the requirement or a reference outside the implementation. Watch each new test go red with its behavior missing or broken. A test that cannot go red is tautological.
- **Secret**: Read secrets from the environment. In a project with `.env.schema`, declare each variable there for Varlock. Code and logs contain secret names only.

## Current-state integrity

Leave the affected system coherent and minimal. This holds when a third-party skill drives the work, without editing the skill.

- **Reconcile**: Trace a changed contract through its callers, tests, configuration, and docs. Update every place that still states the old contract.
- **Remove**: Delete dead code, unused dependencies, and stale text within scope. Confirm dead code through its entry points and consumers, not a missing search hit. Keep compatibility code and migrations that consumers still need.
- **Present**: Maintained documents (ADRs and `GLOSSARY.md`) describe the current state. Rewrite the body in place instead of appending corrections. Git history holds the old text.
- **Distinguish**: Keep intended contracts separate from observed behavior. Never rewrite a requirement to excuse a bug, or describe a plan as built. When code and a document disagree, find which side is wrong before editing either.
- **Scope**: Keep cleanup inside the task's scope. Report stale material beyond it and contradictions you could not resolve.

## Writing

These rules govern all prose: replies, Markdown docs, ADRs, GLOSSARY.md, commit and PR bodies, and code comments.

- **Plain**: Use familiar, concrete words (`use`, `help`, `is`, `has`), simple tenses, and active voice. Drop model vocabulary (`delve`, `pivotal`, `utilize`, `facilitate`, `foster`, `enhance`, `showcase`, `underscore`, `landscape`, `tapestry`), metaphor jargon (`substrate`, `vector`, `flywheel`, `paradigm`), and brochure verbs (`serves as`, `stands as`, `boasts`).
- **Short**: Keep one idea per sentence and each sentence under 20 words. Join ideas with a period or comma, never semicolons, em dashes, spaced hyphens, or mid-sentence connector colons.
- **Direct**: State the claim directly instead of "not just X, but Y". Count the real items instead of grouping into threes or false "from X to Y" ranges. Cut trailing `-ing` clauses (`..., ensuring...`, `..., highlighting...`).
- **Format**: Use sentence-case headings, straight quotes in source text, no decorative emojis, and no bold `**Label:**` inline-header lists that restate their line.
- **Whole**: Keep articles and "that". Short sentences are still complete sentences.
- **Certain**: Use must, can, or will. Name the condition that limits a claim instead of softening it.
- **Factual**: State what a thing does and its measured effect, not how important it is or how it feels. Replace puffery and unnamed attributions with the event or source.
- **Consistent**: Use one word for one meaning across a document (`GLOSSARY.md` terms where defined). Repeat the right word instead of cycling synonyms. Define a term in a few words at first use.
- **Structure**: Use a numbered list for a procedure, with each step's condition before its command. Use prose for connected reasoning.
- **Exact**: Preserve facts, quotes, citations, commands, and code exactly.
- **Lead**: State the outcome first, then the evidence needed to assess it. Omit generic conclusions and chatbot sign-offs.
- **Transparent**: State the reason and the evidence behind a claim or decision. Name what you measured and what you did not check.
- **Honest**: State the cost, limitation, or failure mode that a choice accepts, and name the condition that reverses it.
- **Symmetric**: Give parallel items, glossary entries, and decision records the same structure and level of detail.
- **Classic**: Show the object directly (Pinker). Cut meta-discourse, zombie nouns, and noun clusters over three words. Make every word pay rent (McCloskey).
