import { spawnSync } from "node:child_process";

const docLock = "@docLock@";
const editTools = new Set(["edit", "write", "apply_patch"]);

type Context = { cwd?: string; sessionManager: { getSessionId(): string } };

function run(mode: "grant" | "edit", ctx: Context, payload: object) {
  const cwd = ctx.cwd ?? process.cwd();
  const session_id = ctx.sessionManager.getSessionId();
  process.env.DOC_LOCK_SESSION = session_id;
  return spawnSync(docLock, [mode], {
    cwd,
    input: JSON.stringify({ session_id, cwd, ...payload }),
    encoding: "utf8",
    timeout: 20_000,
  });
}

export default function (pi: {
  on(event: string, handler: (event: any, ctx: Context) => unknown): unknown;
}) {
  pi.on("input", (event: { text: string; source: string }, ctx) => {
    if (event.source === "interactive") run("grant", ctx, { prompt: event.text });
  });

  pi.on("tool_call", (event: { toolName: string; input: unknown }, ctx) => {
    if (!editTools.has(event.toolName)) return;
    const result = run("edit", ctx, { tool_name: event.toolName, tool_input: event.input });
    if (result.status !== 0) {
      return {
        block: true,
        reason: result.stderr || result.error?.message || `doc-lock exited with status ${result.status}`,
      };
    }
  });
}
