# AGENTS.md — OMP adapter

## OMP

- **Delegate**: Use `scout` for lookup, `sonic` for quick fixes, and `task` for general implementation.
- **Integrate**: The main agent reviews worker results and verifies combined behavior.
- **Review**: Use `reviewer` for substantive changes and `security-reviewer` for security work.
- **Design**: Use `designer` for difficult visual decisions and the vision role for routine image work.
- **Diagnose**: Use `oracle` for ambiguous architecture, uncertain diagnosis, or two failed fixes.
- **Escalate**: Move a task to a stronger configured role when its current model cannot complete it.
- **Complete**: For bulk work or blocking advisor notes, load `/Users/martinfan/.omp/agent/managed-skills/omp-completion-and-advisor/SKILL.md`.
- **Develop**: Before choosing a shell command, running Python, or using version control, read `~/.omp/agent/guidance/development.md`.
- **Documents**: Before writing an issue, specification, PRD, or analysis, read `~/.omp/agent/guidance/human-documents.md`.

## Search

The first move of every search is CodeDB. One call returns ranked, bounded answers. `rg`, `fd`, and `ls` return raw lines that cost extra reads.

- **File name**: `codedb <repo> file NAME` ranks fuzzy file-name matches.
- **Symbol**: A definition or its callers go to `codedb <repo> explain SYM`. One call returns the body and every call site.
- **Call chain**: `codedb <repo> callpath FROM TO` gives the shortest resolved chain.
- **Task**: `codedb <repo> context --local TASK` orients a task in one bundle.
- **Identifier**: Native `grep` for one bare name; `lsp` for references in a language CodeDB misses.
- **Words**: `rw --for="TERMS"` when no file, identifier, or symbol name is known yet.
- **Folder**: `eza -la DIR` or `eza --tree -L 2 DIR`.
- **Jump**: `z NAME && COMMAND` runs a command in a frecent directory found by name.
- **Exhaustive**: `rg` proves every mention, count, or absence. CodeDB skips node_modules and files over 2 MiB.
