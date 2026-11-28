# AGENTS.md (OMP adapter)

## OMP

- **Delegate**: Use `scout` for lookup, `sonic` for quick fixes, and `task` for general implementation.
- **Integrate**: The main agent reviews worker results and verifies combined behavior.
- **Review**: Use `reviewer` for substantive changes and `security-reviewer` for security work.
- **Design**: Use `designer` for difficult visual decisions and the vision role for routine image work.
- **Diagnose**: Use `oracle` for ambiguous architecture, uncertain diagnosis, or two failed fixes.
- **Escalate**: Move a task to a stronger configured role when its current model cannot complete it.
- **Eval**: For bulk inspection and multi-step tasks, use `eval` with Bun/JS (`Bun.$`) or Python. Gather all relevant context in one pass, and finish the actions in one or two calls instead of one tool call per step.
- **Complete**: For bulk work or blocking advisor notes, load `~/.omp/agent/managed-skills/omp-completion-and-advisor/SKILL.md`.

## Search

Search with the `codedb` CLI first: one call returns a ranked, bounded answer.

- **Known path**: Read the needed span directly.
- **File name**: `codedb <repo> file NAME`.
- **Symbol**: `codedb <repo> explain SYM`.
- **Call chain**: `codedb <repo> callpath FROM TO`.
- **Task**: `codedb <repo> context --local TASK`.
- **Identifier**: Native `grep` for one bare name; `lsp` for references CodeDB misses.
- **Folder**: `eza --tree -L 2 DIR`.
- **CodeDB scope**: CodeDB skips node_modules and files over 2 MiB.
- **Fallback**: After a `codedb` call fails, use scoped `rg`, `glob`, or direct reads, and name the failure.
