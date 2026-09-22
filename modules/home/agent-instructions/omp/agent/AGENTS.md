# AGENTS.md — OMP adapter

## OMP

- **Delegate**: Use `scout` for lookup, `sonic` for quick fixes, and `task` for general implementation.
- **Integrate**: The main agent reviews worker results and verifies combined behavior.
- **Review**: Use `reviewer` for substantive changes and `security-reviewer` for security work.
- **Design**: Use `designer` for difficult visual decisions and the vision role for routine image work.
- **Diagnose**: Use `oracle` for ambiguous architecture, uncertain diagnosis, or two failed fixes.
- **Escalate**: Move a task to a stronger configured role when its current model cannot complete it.
- **Complete**: For bulk work or blocking advisor notes, load `/Users/martinfan/.omp/agent/managed-skills/omp-completion-and-advisor/SKILL.md`.

Everything else this guide needs is below: search, working contract, code quality and testing, development routing, the testing guide, and human-reviewed documents.

## OMP tools

- **Read**: Use native `read` for text, spans, URLs, and image questions.
- **Shell**: Use the Command routing table below when native tools cannot answer the task.
- **Spawn**: Use `task` only for independent work smaller than the current task.
- **Background**: A bash call past the auto-background threshold (60 s by default) keeps running, and its result arrives as a follow-up turn. Do other work, or end the reply and be woken.
- **Services**: Start services, watchers, debuggers, and REPLs with `hub` `op:"start"`; read them with `op:"logs"` and end them with `op:"stop"`.
- **Condition**: Wait for readiness with `hub` `op:"wait"`, a `name`, `for: "ready"`, and a `pattern`, bounded by `timeout`. Job results deliver themselves; a bare `op:"wait"` is only for when nothing else remains.
- **Timeout**: `timeout` bounds the whole call without lengthening the foreground wait. `timeout: 0` removes the deadline; reserve it for jobs that must run unbounded.
- **Lifetime**: `omp -p` cancels unfinished jobs about three seconds after the final answer, and a `task` worker's jobs end when the worker is parked. Finish required jobs before either point.

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
