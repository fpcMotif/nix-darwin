# CLAUDE.md — Claude adapter

## Claude

- **Shell guard**: Run a command elsewhere with `z DIR && CMD` or the tool's own directory flag, such as `git -C DIR`. Copy with `fcp SRC DST`. Read a known path with the Read tool or `bat -pp -r A:B`. Find a file by name pattern with `fd`. Symbol and feature questions go to Search. Run Python with `uv run`. Change files with Edit or Write. A hook enforces each route, even in bypass mode.
- **Ask box**: In the desktop app, call `wrap_up` before the report. Set `ask` to item 1 of What I need from you as one question, `actions` to its answers, and `blocked` when work stops. With nothing pending, omit `ask` and `actions`. The report, with its What I need from you section, follows the call.
- **Reset**: When a task ends or the context grows large, suggest `/clear` over `/compact`. A hook hands the next session this transcript's path, so nothing is summarized away.
- **Chat figures**: In chat, draw a flow as ASCII boxes and arrows in a `text` block, like so:

  ```text
  ┌──────┐   ┌───────┐   ┌──────┐
  │ Edit │──▶│ Build │──▶│ Test │
  └──────┘   └───────┘   └──────┘
  ```

## Search

Search with fff, codedb, and vesalius first: one call returns a ranked, bounded answer. These routes own symbol and feature questions. `rg`, `fd`, and `bat` serve raw text and known paths.

- **Users**: `mcp__vesalius__usages` for who calls, imports, or depends on a symbol or file. Add `change` before a rename, signature change, or removal.
- **Feature**: `mcp__vesalius__feature_map` with the question, for where a behaviour is implemented.
- **Long file**: `mcp__vesalius__outline` before Read on a file over 300 lines.
- **Known path**: Read the needed span with offset and limit.
- **File name**: `mcp__fff__find_files` with one or two terms.
- **Identifier**: `mcp__fff__grep`; batch spellings in one `mcp__fff__multi_grep`.
- **Symbol**: `mcp__codedb__codedb_explain` with `name` and `project=<repo>`.
- **Call chain**: `mcp__codedb__codedb_callpath`.
- **Task**: `mcp__codedb__codedb_context` with `semantic=local` and `project=<repo>`.
- **Folder**: `mcp__codedb__codedb_list_dir` or `eza --tree -L 2 DIR`.
- **Other repo**: Pass its path as `project` to codedb, or run `vesalius usages X --repo DIR`; confirm the checkout before editing.
- **Unindexed**: Nix, shell, and Markdown have no symbol index. Use fff for those files.
- **Fallback**: After an MCP call fails, use scoped `rg`, `fd`, or Read, and name the failure.
- **Detail**: `~/.claude/search-routing.md` for unclear routing.

## Agents

- **Read-only**: Send searches and lookups to the Explore agent, which cannot edit. Mark review briefs read-only.
- **Search brief**: Name the search route in every brief that explores code. The CLI forms run in a subagent's Bash: `vesalius usages X --repo DIR`, `vesalius feature-map "QUESTION" --repo DIR`, `codedb DIR explain SYM`. Scoped `rg` serves raw text.
- **Haiku**: Pass the exact spans or candidates in the brief. Ask Haiku to classify or rewrite that input in place, with no file searching or reading.
- **Fork**: A fork sees this whole conversation, so its brief names the one task it owns.
- **Workflow**: In a workflow run, give each verifier a whole review dimension or file with all its findings. This keeps a run near its size guideline.
