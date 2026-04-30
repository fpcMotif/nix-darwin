import { existsSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";

const DEFAULT_FILE = "README.md";
const GLOW_COMMAND = "@glow@";
const MAX_OUTPUT_BYTES = 4 * 1024 * 1024;
const SINGLE_QUOTE = "'";
const DOUBLE_QUOTE = '"';

function splitArgs(input: string): string[] {
  const args: string[] = [];
  let current = "";
  let quote: string | null = null;
  let escaping = false;

  for (const char of input.trim()) {
    if (escaping) {
      current += char;
      escaping = false;
      continue;
    }

    if (char === "\\") {
      escaping = true;
      continue;
    }

    if (quote) {
      if (char === quote) {
        quote = null;
      } else {
        current += char;
      }
      continue;
    }

    if (char === SINGLE_QUOTE || char === DOUBLE_QUOTE) {
      quote = char;
      continue;
    }

    if (/\s/.test(char)) {
      if (current) {
        args.push(current);
        current = "";
      }
      continue;
    }

    current += char;
  }

  if (escaping) current += "\\";
  if (current) args.push(current);
  return args;
}

function notify(ctx: ExtensionCommandContext, message: string, type: "info" | "error" = "info"): void {
  if (ctx.hasUI) {
    ctx.ui.notify(message, type);
  } else if (type === "error") {
    console.error(message);
  } else {
    console.log(message);
  }
}

function renderMarkdown(cwd: string, target: string): { ok: boolean; message: string } {
  const filePath = resolve(cwd, target);
  if (!existsSync(filePath)) return { ok: false, message: "Markdown file not found: " + filePath };
  if (!statSync(filePath).isFile()) return { ok: false, message: "Not a file: " + filePath };

  const result = spawnSync(GLOW_COMMAND, [filePath], {
    cwd,
    encoding: "utf8",
    maxBuffer: MAX_OUTPUT_BYTES,
    env: {
      ...process.env,
      GLOW_STYLE: process.env.GLOW_STYLE ?? "dark",
    },
  });

  const stdout = result.stdout?.trimEnd() ?? "";
  const stderr = result.stderr?.trimEnd() ?? "";

  if (result.error) return { ok: false, message: "Failed to run glow: " + result.error.message };
  if (result.status !== 0) {
    return { ok: false, message: stderr || stdout || "glow exited with status " + String(result.status) };
  }

  return { ok: true, message: stdout || "(glow produced no output)" };
}

export default function glowExtension(pi: ExtensionAPI) {
  pi.registerCommand("glow", {
    description: "Render a Markdown file with the Glow terminal renderer. Usage: /glow [file.md]",
    handler: async (args, ctx) => {
      const [target = DEFAULT_FILE] = splitArgs(args ?? "");
      const result = renderMarkdown(ctx.cwd ?? process.cwd(), target);
      notify(ctx, result.message, result.ok ? "info" : "error");
    },
  });
}
