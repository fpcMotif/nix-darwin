# Testing guide

Read this before writing a test, choosing a technique beyond E2E, or recording a test artifact. The agent guide's Testing section states the rules; this file holds the detail they reach for.

## Loop

1. List the failure modes the change must handle. Completion: each item names an input or event and the required outcome.
2. Write one test for the first failure mode and run it. Completion: the test is red, and its message names that mode.
3. Implement the smallest change that turns it green. Completion: the suite passes with no test edited.
4. Refactor with the suite green, then return to step 2. Completion: every listed failure mode has a test that was red once.

The failure-mode list is a sample, never a proof; record what it leaves untested. A bug found later enters at step 2 as a regression test that reproduces it. A surviving mutant (below) enters the same way.

## Repeatable artifact

An artifact is evidence a reviewer can inspect plus the means to reproduce it. Two forms cover most changes:

| Change | Artifact |
| --- | --- |
| UI or flow | A video of the driven flow, with the assertion results that ran alongside it. |
| Backend, CLI, or data | A rerunnable script that performs the scenario, checks the real outcome, and exits non-zero on mismatch. |

Record beside it: the exact command, the tested revision, tool versions, fixture inputs, and setup or reset steps.

The check compares observed state to the requirement, never to the previous run; two runs can share a bug. A `PASS`/`FAIL` line summarizes a check the script performed, such as counting rows; a printed line with no check behind it is not evidence. Semantic results repeat; video bytes, timestamps, and generated IDs may differ. Report every check as passed, failed, blocked, or not run. Fixtures are synthetic; artifacts carry no secrets or personal data.

## Beyond E2E: choose by risk

E2E is the sole layer until one of these risks is named. Reuse tools the project already has and bound the run budget.

| Risk | Technique | Keep with the artifact |
| --- | --- | --- |
| Malformed or boundary input | Fuzzing: varied, malformed, and adversarial inputs at the same entry point. Check meaningful failures, not only crashes. | Each failing input, minimized where the tool supports it. |
| A rule that must hold for all inputs | Property-based testing: idempotence, valid transitions, or round-trips across generated inputs or action sequences. Confirm the generator reached the interesting cases. | The counterexample, the seed, and the shrink path; a seed alone does not replay a shrunk case. |
| Races, retries, partial failure | Simulation: vary event order, delays, duplicate delivery, and injected faults; check safety and progress under stated bounds. Name the simulated boundary and keep one real-provider check; a seed does not make an external service deterministic. | The schedule or fault trace, or the platform's replay reference. |
| Assertions that may be missing | Mutation testing after the suite is green: alter selected logic and confirm a test goes red. Review each survivor for a missing assertion or equivalent behavior; a blanket score is not the goal. | Mutations, outcomes, and the decision on each survivor. Mutants never ship. |

## Static analysis: Fallow (TypeScript and JavaScript only)

Fallow reads TypeScript/JavaScript projects and their framework and style files; Rust-native describes its build, not its targets. Use it for a substantial JS/TS change when the project pins `fallow`; otherwise report it not run. Skip it for other languages and for documentation-only changes; in a mixed repository, scope it to the JS/TS workspace root.

With `BASE` set to the resolved comparison commit: `fallow audit --base "$BASE" --format json`. Exit 0 is pass or warn, 1 is a policy failure, 2 is an execution error; read `verdict` and the new-versus-inherited split, not the raw count. Keep the JSON, stderr, exit status, version, scope, and base with the artifact. Findings supplement tests, type checks, and lint. Inspect entry points, generated code, and dynamic consumers before deleting anything. Separate introduced findings from inherited debt. Installing tooling, hooks, Fallow Runtime, or uploads needs a separate request.

## Report

One row per requirement or failure mode: requirement | check | observed result | artifact and rerun command. Label static-analysis rows as such, and label blocked or not-run checks. Where the adapter provides a human-documents guide, its final-review section owns the surrounding shape.
