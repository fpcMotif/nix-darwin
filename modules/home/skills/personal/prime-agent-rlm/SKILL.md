---
name: prime-agent-rlm
description: "Orchestrate Prime Agent RPC daemons and RLM patterns via OMP hub, including OpenRouter/free-model procedures and known failure modes"
---

# Prime Agent & RLM Tooling Integration

Guidelines and workflows for orchestrating **Prime Agent** (`prime-agent`) and **Recursive Language Model (RLM)** tooling alongside **Oh My Pi (OMP)**.

## Core Concepts

- **Prime Agent (`prime-agent`)**: Standalone self-improving agent framework with a daemon process, persistent IPython REPL, and Continual Harness (`/refine`).
- **`@shift-labs/pi-rlm`**: Extension for `pi` CLI replacing tool lists with a single `execute` tool in Bun TypeScript.
- **OMP Integration**: OMP drives `prime-agent` in headless RPC mode via JSONL (`stdin`/`stdout`), manages daemon jobs via `hub`, and shares REPL/subagent workflows.

## 1. Running Prime Agent in RPC Mode

Start a headless RPC session using `hub` or subprocess:

```bash
prime-agent --mode rpc --provider anthropic --model claude-sonnet-4-20250514
```

### JSONL Protocol Semantics
All RPC messages are newline-delimited JSON (`\n`).

#### Send Prompt
```json
{"id": "req-1", "type": "prompt", "message": "Refactor SearchItem.swift to use bitmask filters"}
```

#### Steering Active Execution
Deliver steering instructions mid-flight (after current tool execution, before next LLM call):
```json
{"id": "req-2", "type": "steer", "message": "Keep existing public invariants intact"}
```

#### Follow-up Execution
Queue follow-up tasks processed after agent stops:
```json
{"id": "req-3", "type": "follow_up", "message": "Run SwiftTest suite after completing refactor"}
```

#### Abort Operation
```json
{"id": "req-4", "type": "abort"}
```

---

## 2. Managing Background Daemon Sessions via `hub`

Use `hub` to launch and control Prime Agent RPC daemons in OMP:

```javascript
// Start RPC daemon
hub({
  op: "start",
  name: "prime-rpc-daemon",
  application: "prime-agent",
  args: ["--mode", "rpc", "--provider", "anthropic"],
  ready: { log: ".*", timeout: 15 }
});

// Write prompt to stdin
hub({
  op: "send",
  name: "prime-rpc-daemon",
  text: JSON.stringify({ id: "1", type: "prompt", message: "Analyze codebase performance bottlenecks" })
});
```

---

## 3. Subagent & REPL Workflows

### Prime Agent Python REPL (`rlm(...)`)
Inside Prime Agent's persistent IPython kernel:
```python
# Programmatic subagent delegation
summary = await rlm("Audit SwiftLint rules in tools/ast-grep/", agent="scout")
print(summary)
```

### OMP JS/Python `eval` Kernel
Inside OMP, replicate RLM REPL patterns using persistent `eval` state and `parallel` execution:
```javascript
const results = await parallel([
  () => agent("Audit SearchCoordinator.swift", { agent: "scout" }),
  () => agent("Audit KeywordEngine.swift", { agent: "scout" })
]);
```

---

## 4. Continual Harness & Skill Refinement

- Run `/refine` inside Prime Agent to analyze session trajectories and save durable lessons into `.prime-agent/skills/`.
- Use OMP `manage_skill` to mirror refined workflows into `~/.omp/agent/managed-skills/`.

---

## 5. Operational Notes (field-tested 2026-08-23)

**Model selection over OpenRouter**
- `stealth/ox-alpha` authenticates against OpenRouter but returns **empty completions** (`content: [], output tokens: 0`) through prime-agent's `openai-completions` client. Never use it as the daemon model.
- Working fallback: `--provider openrouter --model z-ai/glm-5.2:free` (256k ctx, $0 cost, handles tool loops). Other viable free models are listed by querying `https://openrouter.ai/api/v1/models` with the key from `~/.prime/agent/auth.json` (filter ids ending `:free`); never print the key.
- Always validate a new daemon with a strict ping BEFORE firing missions: send `{"id":"ping","type":"prompt","message":"Reply with exactly: PONG-OK and nothing else."}`, then require a log event whose assistant content is non-empty. `"success":true` alone is NOT proof — empty-content success happens on broken models.
- The startup warning `Model "<id>" not found for provider ... Using custom model id` is benign registry noise; judge by the ping, not the warning.

**Free-tier rate limits**
- `:free` endpoints 429 frequently; prime-agent auto-retries max 3 attempts then parks the session at `taskState: "needs_input"` with zero work done. Check `~/.prime/agent/sessions/<id>.jsonl` tail for that status before assuming progress.
- For long missions on a rate-limited tier, split work into small independent waves and be ready to execute them via OMP `task` agents instead — do not block delivery on a parked daemon.

**hub lifecycle gotchas**
- `hub op:"restart"` REUSES the original launch args — changing provider/model requires `stop` + fresh `start`.
- Auth state lives in `~/.prime/agent/auth.json` (e.g. `openrouter: set(api_key)`); restart the daemon after a fresh `/login`.
- `prime-agent@0.7.1` was side-loaded from a temp tarball (no npm package): there is NO update channel; `bun add -g prime-agent@latest` 404s. Don't burn time trying.
- OMP subagent spawning fails wholesale if `~/.omp/agent/config.yml` has YAML errors (symptom: Cloud Code Assist 400 `Unknown name "x-google-enum-deprecated"` or task preflight `SyntaxError: Unexpected token`). Validate/repair that file first; check for fused lines like `shape: boxhideThinkingBlock: true`.

**Never block the user's own processes**
- Before launching supervised dev servers (vite/backend) via `hub`, check who owns the target ports (`lsof -nP -iTCP:<port> -sTCP:LISTEN`). Hub instances left running have collided with the user's own `bun run dev:auth` more than once — stop your supervised instances after verification so the user's identical command succeeds.
