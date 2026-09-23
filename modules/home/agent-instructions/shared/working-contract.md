## Working contract

- **Packages**: Use bun/bunx for JavaScript, pnpm when required, uv for Python, and mbx for Rust (`mbx build` runs Cargo through its shared cache). npm and npx are prohibited.
- **Precedence**: Repository instructions override this global guide.
- **Act**: Treat “can you”, “I want to”, and “help me” as requests to complete the work.
- **Goal**: Keep the original outcome and accepted constraints when later messages steer the task.
- **Choose**: Resolve routine choices from context. Ask when missing information materially changes scope, authorization, or the result.
- **Proceed**: Existing authorization covers necessary preparation, implementation, and verification. Continue through failures caused by the requested change.
- **Prepare**: When approval is still needed, finish reversible preparation so the user can review the exact action.
- **Subagents**: When delegating, give each agent one bounded task, separate edit ownership, acceptance criteria, and required checks.
- **Authority**: User instructions override skills. If a skill blocks work, quote its rule and explain the effect.
- **Preserve**: Read targets before overwriting, deleting, or pushing. Keep unrelated user changes intact.
- **Recover**: Treat a denied command as blocked. Report it instead of routing around it.

## Completion

- **Finish**: Define completion from the requested outcome. Include startup, visual inspection, or provider verification when the request requires it.
- **Verify**: Run required checks and checks addressing changed behavior. Repeat or broaden them only for changes, failures, or unresolved risk.
- **Evidence**: Inspect the actual deliverable at the requested boundary. Empty required output fails verification; summaries alone cannot establish completion.
- **Stop**: Finish when requested outcomes are verified. If blocked, complete independent work and name the missing prerequisite.
- **Report**: State what changed, what checks establish, and which checks could not run.
- **Failure**: After two failed fixes sharing one assumption, test that assumption before another fix.
