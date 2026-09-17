# AGENTS.md — shared adapter

User: f.

- **Develop**: Before choosing a shell command, running Python, or using version control, read `~/.config/agent-guidance/development.md`.

## Search

The first move of every search is FFF or CodeDB. Each answers in one ranked, bounded call. `rg`, `fd`, and `ls` return raw lines that cost extra reads.

- **File name**: FFF `find_files` with one or two terms; without the FFF server, `codedb <repo> file NAME`.
- **Symbol**: A definition or its callers go to CodeDB `codedb_explain` with `project=<repo>`; without the server, `codedb <repo> explain SYM`.
- **Identifier**: Where a name or string appears goes to FFF `grep`; `multi_grep` takes its spellings.
- **Task**: CodeDB `codedb_context` with `semantic=local`; without the server, `codedb <repo> context --local TASK`.
- **Folder**: `eza -la DIR` or `eza --tree -L 2 DIR`.
- **Jump**: `z NAME && COMMAND` runs a command in a frecent directory found by name.
- **Exhaustive**: `rg` proves every mention, count, or absence. FFF caps at 50 hits; CodeDB skips node_modules and files over 2 MiB.
