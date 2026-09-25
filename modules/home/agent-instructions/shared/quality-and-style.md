## Code quality

- **Direct**: Use the simplest direct implementation. A second real use earns an abstraction.
- **Local**: Edit the lines that change. Rewrite a file only when most of it changes.
- **Match**: Follow existing patterns and confirm libraries before using them.
- **Name**: Names carry what the code does. Comments explain only reasons the code cannot show.
- **Edge**: Validate at the input edge and trust internal callers.
- **Secret**: Read secrets from the environment. In a project with `.env.schema`, declare each variable there for Varlock. Code and logs contain secret names only.

## Testing

- **Red first**: Write the failing test before the behavior or the fix; watch it fail for the intended reason. Tests written after their code are prohibited.
- **Independent**: Derive each expectation from the requirement or a reference outside the implementation. A test that cannot fail is tautological; replace it with one that names its failure.
- **E2E-first**: Drive the real entry point and check the resulting state. E2E is the sole layer until a named risk needs isolation.
- **Failure modes**: Before isolating a unit, list how it can fail. Each listed failure becomes a red test before the code.
- **Artifact**: Every E2E run leaves a repeatable artifact: the command, the tested revision, and checked output that fails on mismatch. UI changes add a flow video; backend changes add a rerunnable script.

## Writing

- **Plain**: Use familiar, concrete words and active voice.
- **Short**: Keep one idea per sentence and each sentence under 20 words.
- **Structure**: Use a numbered list for a procedure. Use prose for connected reasoning.
- **Exact**: Preserve facts, quotes, citations, commands, and code exactly.
- **Lead**: State the outcome first, then the evidence needed to assess it.
