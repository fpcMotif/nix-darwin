# AGENTS.md — OMP adapter

## OMP

- **Delegate**: Use `scout` for lookup, `sonic` for quick fixes, and `task` for general implementation.
- **Integrate**: The main agent reviews worker results and verifies combined behavior.
- **Review**: Use `reviewer` for substantive changes and `security-reviewer` for security work.
- **Design**: Use `designer` for difficult visual decisions and the vision role for routine image work.
- **Diagnose**: Use `oracle` for ambiguous architecture, uncertain diagnosis, or two failed fixes.
- **Escalate**: Move a task to a stronger configured role when its current model cannot complete it.
- **Complete**: For bulk work or blocking advisor notes, load `/Users/martinfan/.omp/agent/managed-skills/omp-completion-and-advisor/SKILL.md`.
- **Develop**: Before choosing a shell command, running Python or Rust, adding an environment variable, or using version control, read `~/.omp/agent/guidance/development.md`.
- **Documents**: Before writing an issue, specification, PRD, analysis, ADR, or CONTEXT.md, read `~/.omp/agent/guidance/human-documents.md`.

## Search

Search with the `codedb` CLI first: one call returns a ranked, bounded answer.

- **Known path**: Read the needed span directly.
- **File name**: `codedb <repo> file NAME`.
- **Symbol**: `codedb <repo> explain SYM`.
- **Call chain**: `codedb <repo> callpath FROM TO`.
- **Task**: `codedb <repo> context --local TASK`.
- **Identifier**: Native `grep` for one bare name; `lsp` for references CodeDB misses.
- **Words**: `rw --for="TERMS"` when no name is known yet.
- **Folder**: `eza --tree -L 2 DIR`.
- **Trust**: Act on a result that answers the question.
- **Coverage**: Scoped `rg` confirms a full listing, count, or absence. CodeDB skips node_modules and files over 2 MiB.
- **Fallback**: After a `codedb` call fails, use scoped `rg`, `glob`, or direct reads, and name the failure.
