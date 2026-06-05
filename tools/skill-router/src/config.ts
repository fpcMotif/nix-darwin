import { join } from "node:path";
import type { AgentConfig, RouterConfig, ScopeConfig } from "./types.ts";

const DEFAULT_CONFIG_PATH = join(import.meta.dir, "..", "config.default.json");

type Env = Record<string, string | undefined>;
type UserRouterConfig = {
  scopes?: Partial<Record<keyof RouterConfig["scopes"], Partial<ScopeConfig>>>;
  agents?: Record<string, Partial<AgentConfig>>;
  catalog?: Partial<RouterConfig["catalog"]>;
};

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
  const defaults = (await Bun.file(DEFAULT_CONFIG_PATH).json()) as RouterConfig;
  const userPath = path ?? join(process.env.HOME ?? "", ".config", "skill-router", "config.json");
  const userFile = Bun.file(userPath);
  if (await userFile.exists()) {
    return mergeConfig(defaults, (await userFile.json()) as UserRouterConfig);
  }
  return defaults;
}

export function resolveScopeDirs(dirs: string[] | undefined, env: Env = process.env): string[] {
  return (dirs ?? []).map((d) => expandPath(d, env));
}

function mergeConfig(defaults: RouterConfig, user: UserRouterConfig): RouterConfig {
  const scopes = { ...defaults.scopes };
  for (const [name, scope] of Object.entries(user.scopes ?? {}) as Array<[keyof RouterConfig["scopes"], Partial<ScopeConfig>]>) {
    scopes[name] = { ...defaults.scopes[name], ...scope };
  }

  const agents = { ...defaults.agents };
  for (const [name, agent] of Object.entries(user.agents ?? {})) {
    agents[name] = { ...agents[name], ...agent } as AgentConfig;
  }

  const catalog = { ...defaults.catalog, ...user.catalog };
  catalog.intentRunner = pinnedIntentRunner(catalog.intentRunner, defaults.catalog.intentRunner);

  return { scopes, agents, catalog };
}

function pinnedIntentRunner(runner: string | undefined, fallback: string): string {
  const trimmed = runner?.trim();
  if (!trimmed || /@latest(?:\s|$)/.test(trimmed)) return fallback;
  return trimmed;
}
