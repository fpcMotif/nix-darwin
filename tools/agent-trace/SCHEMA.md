# Claude Code Session Transcript Schema (contract for agent-trace implementations)

Source: `~/.claude/projects/<project-slug>/<session-uuid>.jsonl` — one JSON record per line. Tolerate malformed lines (skip, count them). Project slug = cwd path with `/` → `-`.

## Record envelope (all types)
`type`, `uuid`, `parentUuid` (links to previous record, forms the conversation DAG), `sessionId`, `timestamp` (ISO8601), `cwd`, `gitBranch`, `version`, `userType`, `entrypoint`, `isSidechain` (true = subagent/Task transcript).

## Record types (observed)
`assistant`, `user`, `attachment`, `last-prompt`, `queue-operation`, `mode`, `system`, `pr-link`, `custom-title`, `summary`. Unknown types MUST NOT crash the parser; bucket them as "other".

## `assistant`
- `requestId`, optional: `isApiErrorMessage`, `apiErrorStatus`, `error`, `attributionSkill`, `attributionMcpServer`, `attributionMcpTool`, `attributionPlugin`.
- `message`: `{ id, model, role, content: [...], stop_reason, stop_sequence, stop_details, usage, ... }`
- `message.model`: e.g. `claude-sonnet-5`, may be `<synthetic>`.
- `message.content[]` block types: `text`, `thinking`, `tool_use` (`{id, name, input}`).
- `message.usage`: `{ input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens, service_tier, speed, ... }` — treat all as optional integers.

## `user`
- Optional: `isMeta`, `permissionMode`, `promptSource`, `promptId`, `toolUseResult`, `sourceToolAssistantUUID`, `classifierMetaLines`.
- `message.content`: either a string (human prompt) or an array of `tool_result` blocks (`{type:"tool_result", tool_use_id, content, is_error?}`).
- Human prompts = records where content is a string and `isMeta != true`.

## `queue-operation`
`{operation: "enqueue"|"dequeue", content?, timestamp, sessionId}` — `enqueue.content` holds the raw queued user prompt text.

## Error signals
- `assistant.isApiErrorMessage == true` / `apiErrorStatus` / `error`
- `tool_result` blocks with `is_error == true`

## Subagents
`isSidechain == true` records belong to a spawned agent (Task/Agent tool). The parent's `assistant` record contains a `tool_use` named `Agent`/`Task`/`Workflow`; the sidechain shares the same `sessionId`.

## CLI contract (all three implementations)
```
agent-trace [--root PATH] [--format json|table] <command>
```
- `--root` default: `~/.claude/projects`
- `stats` — aggregate over all transcripts: sessions, records by type, tool_use histogram, models, token totals (input/output/cache-read/cache-creation), API error count, per-project breakdown.
- `prompts` — first human prompt per session (queue-operation enqueue content, else first non-meta user string), with timestamp, project, sessionId. Flags: `--grep PAT`, `--min-len N`.
- `flow <session.jsonl>` — render uuid/parentUuid tree: indent by depth, mark sidechains, tool_use names, errors.
- Streaming line-by-line parse. Never load a whole file into memory as one blob.
