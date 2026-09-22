## Code quality

- **Direct**: Use the simplest direct implementation. A second real use earns an abstraction.
- **Local**: Edit the lines that change. Rewrite a file only when most of it changes.
- **Match**: Follow existing patterns and confirm libraries before using them.
- **Name**: Names carry what the code does. Comments explain only reasons the code cannot show.
- **Edge**: Validate at the input edge and trust internal callers.
- **Secret**: Read secrets from the environment. Code and logs contain secret names only.

## Testing

- **No tautological tests**: Derive expected behavior from requirements or an independent reference, never copied implementation logic. Do not merely assert a mock's configured return value. Each test must detect a named behavioral failure.
- **E2E first**: Highly prefer end-to-end tests as the sole testing layer when they cover the risks. Exercise real user, API, or CLI entry points and verify resulting state. Fuzzing and property-based checks can exercise those same boundaries; they do not require separate unit suites.
- **Failure modes first**: Before implementation, list identified failure modes and required outcomes. Explain any risk that needs isolation rather than E2E. Do not claim the list is exhaustive.
- **Tests before behavior**: NEVER implement new behavior first and retrofit its unit tests afterward. Work in small red-green-refactor cycles: one failing test, minimal implementation, then cleanup with tests passing. Verify the failure concerns the intended behavior. For existing bugs, write a reproducing regression test before the fix. This does not forbid independent tests exposing gaps found by mutation testing.
- **Choose by risk**: Use the techniques below where they address a named risk. Reuse existing tools and set a bounded run budget. Do not mandate every technique, add redundant suites, or build a testing platform for a small change.

| Technique | Use and required evidence |
| --- | --- |
| Fuzzing | Generate varied, malformed, boundary, or adversarial inputs where input robustness matters. Check meaningful failures, not only crashes. Retain failing inputs and minimize them when supported. |
| Property-based testing | Define requirements that hold across generated inputs or action sequences, such as idempotence or valid state transitions. Check meaningful scenarios were reached; skipped cases or never-triggered conditions are not evidence. Retain the counterexample and replay details. |
| Antithesis-style simulation | For races, retries, and partial failures, vary event order, delays, duplicate delivery, and relevant faults. Check safety and progress under stated recovery assumptions and bounds. Record the schedule/fault trace or platform replay reference. A random seed alone does not make live external services deterministic. Name simulated boundaries; keep real-provider checks. Do not require Antithesis itself. |
| Mutation testing | After the suite passes, deliberately alter selected changed or critical logic and check that tests detect it. Review surviving mutants for missing assertions or equivalent behavior; do not chase a blanket score. Retain mutations, outcomes, and survivor decisions. Keep compile errors, timeouts, and infrastructure failures distinct from assertion failures. Never ship deliberate mutations. |

### Test evidence

- **Verifiable**: Every E2E run must leave inspectable evidence, including successful runs. UI changes need a flow video plus assertion results. Backend changes need a rerunnable script plus observed, checked output. Fail the command on mismatches and retain failure evidence. A video alone or bare PASS/FAIL file is insufficient.
- **Repeatable**: Record command, revision, tool versions, prerequisites, fixture inputs, and setup/reset steps. For generated tests, save the seed, replay/shrink path when applicable, failing input or action sequence, and run budget. For simulation, include schedule/fault replay details. Promote confirmed failures into fixed regression cases before fixing production code. Semantic results must repeat; video bytes, timestamps, and generated IDs need not.
- **Honest**: Compare against explicit requirements or a reviewed baseline, not merely the previous run. Normalize only irrelevant volatile fields. Never regenerate expectations solely to pass. Distinguish passed, failed, blocked, and not-run checks. Report sampled runs and untested boundaries; passing tests are not proof of correctness. Use synthetic fixtures and redact secrets and personal data from artifacts.

## Fallow — TypeScript/JavaScript only

- **Scope**: Use Fallow for substantial TypeScript/JavaScript code or dependency changes, including related framework and style files. In mixed-language repositories, select the JS/TS project or workspace root and record scope. Do not use Fallow to analyze Rust, Python, Go, Nix, or other non-JS/TS code. Rust-native describes its implementation, not its target languages. Skip it for unrelated or documentation-only changes.
- **Purpose**: Use the free static layer for unused code, circular imports, duplication, complexity, configured architecture boundaries, and styling drift. It supplements tests, type checks, and lint; it does not prove runtime correctness.
- **Run**: Reuse the pinned binary or project script and existing configuration. Check the installed version's help or `fallow schema` before unfamiliar flags. Set `BASE` to the resolved PR comparison commit; run `fallow audit --base "$BASE" --format json`. Prefer new-only attribution unless repository policy requires stricter gating. If unavailable, report not run; do not silently install tooling.
- **Evidence**: Save JSON, stderr, exit status, command, version, revision, resolved base, configuration, and analyzed scope. For `audit`, exit 0 can mean pass or warn; 1 means policy failure; 2 means execution error. Read `verdict` and new-versus-inherited attribution, not just total issue counts. Never hide errors with `|| true` or discard diagnostics.
- **Act narrowly**: Inspect findings and verify framework entry points, generated code, dynamic consumers, and public APIs before removal. Preview fixes, review the diff, and rerun affected checks. Separate introduced findings from inherited debt. Do not delete code, suppress findings, or invent abstractions merely to improve a score.
- **Opt-in boundaries**: Default to static analysis. Hooks, MCP installation, guide-rewriting installers, Fallow Runtime, and code/coverage uploads require a separate request. Paid runtime monitoring is not a review prerequisite. No observed production hits does not prove code is safe to delete.

## Human final review

For substantial changes, provide one compact Markdown review: behavior and non-goals, the smallest useful diagram, requirement-to-evidence links, and remaining risks. For JS/TS changes, include scoped Fallow findings as static evidence when run. Prefer Mermaid. Use PlantUML only when UML detail improves the review. Do not maintain the same diagram in both formats. Diagrams explain intended structure; executed tests establish observed behavior. Neither replaces human judgment.

## Writing

- **Plain**: Use familiar, concrete words and active voice.
- **Short**: Keep one idea per sentence and each sentence under 20 words.
- **Structure**: Use a numbered list for a procedure. Use prose for connected reasoning.
- **Exact**: Preserve facts, quotes, citations, commands, and code exactly.
- **Lead**: State the outcome first, then the evidence needed to assess it.
