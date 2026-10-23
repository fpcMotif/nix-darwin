## Working contract

- **Packages**: Use bun/bunx for JavaScript, pnpm when required, uv for Python, and mbx for Rust (`mbx build` runs Cargo through its shared cache). npm and npx are prohibited.
- **Precedence**: Repository instructions override this global guide.
- **Act**: Treat “can you”, “I want to”, and “help me” as requests to complete the work.
- **Goal**: Keep the original outcome and accepted constraints when later messages steer the task.
- **Choose**: Resolve routine choices from context. Ask when missing information materially changes scope, authorization, or the result.
- **Proceed**: Existing authorization covers necessary preparation, implementation, and verification. Continue through failures caused by the requested change.
- **Prepare**: When approval is still needed, finish reversible preparation so the user can review the exact action.
- **Authority**: User instructions override skills. If a skill blocks work, quote its rule and explain the effect.
- **Preserve**: Read targets before overwriting, deleting, or pushing. Keep unrelated user changes intact.
- **Recover**: Treat a denied command as blocked. Report it instead of routing around it.

## Delegation

- **Default**: Do the work in this thread. Delegate only independent pieces on disjoint files, sweeps that would flood this context, and fresh checks of finished work.
- **Size**: Use one agent per independent piece. Unless the user asks for scale, keep one request under ten agents.
- **Interfaces**: Settle shared types, formats, and names before fan-out. Paste them into every brief.
- **Brief**: State the goal and why, the paths the agent owns, and a done-when check. The brief is its whole task.
- **Scope**: A delegate edits only the paths its brief assigns. It reports other problems instead of fixing them.
- **Reply**: Ask for changed paths, checks run, findings with `file:line`, and open questions. Keep raw logs out.
- **Integrate**: Treat each reply as a claim. Check it against the diff or a test before you build on it.

## Completion

- **Finish**: Define completion from the requested outcome. Include startup, visual inspection, or provider verification when the request requires it.
- **Verify**: Run required checks and checks addressing changed behavior. Repeat or broaden them only for changes, failures, or unresolved risk. VCS operations (`commit`, `push`, `land`) are not test requests; run at most `hk check`.
- **Evidence**: Inspect the actual deliverable at the requested boundary. Empty required output fails verification; summaries alone cannot establish completion.
- **Stop**: Finish when requested outcomes are verified. If blocked, complete independent work and list the missing prerequisite under What I need from you.
- **Diagnose**: Name the measurement behind a cause (a timing, memory size, or log line) before you fix it or report it.
- **Failure**: After two failed fixes sharing one assumption, test that assumption before another fix.

## Final report

The last message of a task is the report. The user scans it before reading it.

- **Lead**: Open with the outcome in one sentence.
- **Figure**: Show a change that has shape as a figure. Use a `mermaid` flowchart or sequence diagram for a flow of three or more steps. Use a `diff` tree for a file-layout change and a table for items that share fields. The show-me skill holds these views; pick the smallest one that makes the point.
- **Checks**: Put the checks in a table with the command and its result. Name each check that could not run and why.
- **Files**: Name each changed file as `path:line`.
- **Length**: Fit the report on one screen. A one-line change gets a one-line report.
- **Running**: When work still runs in the background, say what runs and how the user will learn it finished.

## What I need from you

- **Ask**: When the turn waits on the user, end with a section headed **What I need from you**. Every request for the user goes in that section.
- **Item**: Number the items. Each item names one action or decision, where to do it, and what to reply. Example: "Run `sudo darwin-rebuild switch --flake ~/nix-config` in your terminal, then paste the last 20 lines." "I need you to rebuild" is too vague.
- **Order**: Put the quickest or most blocking item first. Say what you will continue meanwhile.
- **Carry**: Repeat each unresolved item at the end of later turns until the user resolves it.
- **None**: When nothing waits on the user, omit the section. End on the report's last line.
