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
- **Documents**: Before writing an issue, specification, PRD, analysis, or final review, read `~/.omp/agent/guidance/human-documents.md`.
- **Test**: Before writing a test, choosing a technique beyond E2E, or recording a test artifact, read `~/.omp/agent/guidance/testing.md`.

## Search

CodeDB is the default structural tool. Native search is the discovery tool. `rg` is the verification tool. Read known paths directly; prefer one bounded call over chains of searches.

- **Known path**: Read the needed span directly.
- **File name**: `codedb <repo> file NAME` ranks fuzzy file-name matches.
- **Symbol**: `codedb <repo> explain SYM` for a definition and indexed call sites.
- **Call chain**: `codedb <repo> callpath FROM TO` gives the shortest resolved chain.
- **Task**: `codedb <repo> context --local TASK` orients a task in one bundle.
- **Identifier**: Native `grep` for one bare name; `lsp` for references in a language CodeDB misses.
- **Words**: `rw --for="TERMS"` when no file, identifier, or symbol name is known yet.
- **Folder**: `eza --tree -L 2 DIR` or `eza -la DIR`.
- **Coverage**: Use scoped `rg` for text listings, counts, or absence checks. CodeDB skips node_modules and files over 2 MiB.
- **Fallback**: When CodeDB is unavailable or stale, use scoped `rg`, `glob`, or direct reads. Do not retry merely to obey routing.

Ranked or indexed results do not guarantee every caller or repo-wide absence. Read additional source only when needed context is missing or freshness is uncertain.
