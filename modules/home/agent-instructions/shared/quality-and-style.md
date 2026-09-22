## Code quality

- **Direct**: Use the simplest direct implementation. A second real use earns an abstraction.
- **Local**: Edit the lines that change. Rewrite a file only when most of it changes.
- **Match**: Follow existing patterns and confirm libraries before using them.
- **Name**: Names carry what the code does. Comments explain only reasons the code cannot show.
- **Edge**: Validate at the input edge and trust internal callers.
- **Secret**: Read secrets from the environment. Code and logs contain secret names only.

## Testing

- **No tautological tests**: Assert required observable behavior. Do not copy implementation logic into expectations or merely assert a mock's configured return value. Derive expectations from requirements or an independent oracle. Each test must detect a named behavioral failure.
- **E2E first**: Highly prefer end-to-end tests as the sole testing mechanism. Verify complex features through real user, API, or CLI entry points and check resulting state. Do not add redundant unit suites.
- **Tests before code**: NEVER write unit tests after implementing the code under test.
- **Isolation exception**: Explain the risk E2E cannot verify adequately. FIRST list all identified failure modes and required outcomes. THEN write failing tests. Only then implement the isolated system.
- **Verifiable artifacts**: Every E2E run must leave inspectable evidence, including successful runs. For UI changes, record a video of the exercised flow and retain assertion results. For backend changes, provide a rerunnable script with definitive observed output and asserted outcomes. Exit nonzero on mismatches; retain failure evidence.
- **Repeatable artifacts**: Record the exact command, tested revision, prerequisites, fixture inputs, and setup/reset steps. Another person must be able to reproduce the scenario and inspect actual outcomes. A bare PASS/FAIL file is insufficient. The semantic result must repeat; video bytes, timestamps, and generated IDs need not.
- **Meaningful comparison**: Compare actual behavior with explicit assertions or a reviewed expected baseline, not merely the previous run. Normalize irrelevant volatile fields only. Never regenerate baselines solely to make a failing test pass.

## Writing

- **Plain**: Use familiar, concrete words and active voice.
- **Short**: Keep one idea per sentence and each sentence under 20 words.
- **Structure**: Use a numbered list for a procedure. Use prose for connected reasoning.
- **Exact**: Preserve facts, quotes, citations, commands, and code exactly.
- **Lead**: State the outcome first, then the evidence needed to assess it.
