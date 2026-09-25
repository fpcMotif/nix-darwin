## Code quality

- **Direct**: Use the simplest direct implementation. A second real use earns an abstraction.
- **Local**: Edit the lines that change. Rewrite a file only when most of it changes.
- **Match**: Follow existing patterns and confirm libraries before using them.
- **Name**: Names carry what the code does. Comments explain only reasons the code cannot show.
- **Edge**: Validate at the input edge and trust internal callers.
- **Secret**: Read secrets from the environment. In a project with `.env.schema`, declare each variable there for Varlock. Code and logs contain secret names only.

## Current-state integrity

Leave the affected system coherent and minimal. This holds when a third-party skill drives the work, without editing the skill.

- **Reconcile**: Trace a changed contract through its callers, tests, configuration, and docs. Update every place that still states the old contract.
- **Remove**: Delete dead code, unused dependencies, and stale text within scope. Confirm dead code through its entry points and consumers, not a missing search hit. Keep compatibility code and migrations that consumers still need.
- **Present**: Maintained documents, including ADRs and CONTEXT.md, describe the current state. Rewrite the body in place instead of appending corrections. Git history holds the old text.
- **Distinguish**: Keep intended contracts separate from observed behavior. Never rewrite a requirement to excuse a bug, or describe a plan as built. When code and a document disagree, find which side is wrong before editing either.
- **Scope**: Keep cleanup inside the task's scope. Report stale material beyond it and contradictions you could not resolve.

## Writing

- **Plain**: Use familiar, concrete words and active voice.
- **Short**: Keep one idea per sentence and each sentence under 20 words.
- **Structure**: Use a numbered list for a procedure. Use prose for connected reasoning.
- **Exact**: Preserve facts, quotes, citations, commands, and code exactly.
- **Lead**: State the outcome first, then the evidence needed to assess it.
