import { join } from "node:path";
import type { RouterConfig } from "./types.ts";

const DEFAULT_CONFIG_PATH = join(import.meta.dir, "..", "config.default.json");

type Env = Record<string, string | undefined>;

export function expandPath(template: string, env: Env = process.env): string {
  const expanded = template.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}/g, (_, name: string, fallback?: string) => {
    return env[name] ?? fallback ?? "";
  });
  const home = env.HOME ?? "";
  if (expanded === "~") return home;
  if (expanded.startsWith("~/")) return join(home, expanded.slice(2));
  return expanded;
}

export async function loadConfig(path?: string): Promise<RouterConfig> {
  const userPath = path ?? join(process.env.HOME ?? "", ".config", "skill-router", "config.json");
  const userFile = Bun.file(userPath);
  if (await userFile.exists()) {
    return (await userFile.json()) as RouterConfig;
  }
  return (await Bun.file(DEFAULT_CONFIG_PATH).json()) as RouterConfig;
}

export function resolveScopeDirs(dirs: string[] | undefined, env: Env = process.env): string[] {
  return (dirs ?? []).map((d) => expandPath(d, env));
}
