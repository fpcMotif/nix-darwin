import { join } from "node:path";
import { bunCommandRunner } from "./command-runner.ts";
import { bunReadText } from "./file-reader.ts";
import type { AgentConfig, RouterConfig, RouterContext, RouterRuntime, ScopeConfig } from "./types.ts";

export const DEFAULT_CONFIG_PATH = join(import.meta.dir, "..", "config.default.json");

type Env = Record<string, string | undefined>;
type UserRouterConfig = {
  scopes?: Partial<Record<keyof RouterConfig["scopes"], Partial<ScopeConfig>>>;
  agents?: Record<string, Partial<AgentConfig>>;
  catalog?: Partial<RouterConfig["catalog"]>;
};

export function defaultRuntime(overrides: Partial<RouterRuntime> = {}): RouterRuntime {
  const runtime: RouterRuntime = {
    run: bunCommandRunner,
    readText: bunReadText,
    env: process.env,
  };
  for (const [key, value] of Object.entries(overrides) as Array<[keyof RouterRuntime, RouterRuntime[keyof RouterRuntime]]>) {
    if (value !== undefined) Object.assign(runtime, { [key]: value });
  }
  return runtime;
}

export function expandPath(template: string, env: Env = process.env): string {
  const expanded = template.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}/g, (_, name: string, fallback?: string) => {
    return env[name] ?? fallback ?? "";
  });
  const home = env.HOME ?? "";
  if (expanded === "~") return home;
  if (expanded.startsWith("~/")) return join(home, expanded.slice(2));
  return expanded;
}

export async function loadConfig(runtime: RouterRuntime = defaultRuntime()): Promise<RouterConfig> {
  const defaultsText = await runtime.readText(DEFAULT_CONFIG_PATH);
  if (defaultsText === null) throw new Error(`missing default skill-router config: ${DEFAULT_CONFIG_PATH}`);

  const defaults = JSON.parse(defaultsText) as RouterConfig;
  const userPath = runtime.configPath ?? join(runtime.env.HOME ?? "", ".config", "skill-router", "config.json");
  const userText = await runtime.readText(userPath);
  if (userText !== null) {
    return mergeConfig(defaults, JSON.parse(userText) as UserRouterConfig);
  }
  return defaults;
}

// Resolve the once-per-invocation context at the cli.ts edge: bind the runtime
// and read+merge config a single time. Downstream modules accept the returned
// RouterContext and read ctx.config instead of re-calling loadConfig.
export async function resolveContext(runtime: RouterRuntime = defaultRuntime()): Promise<RouterContext> {
  return { runtime, config: await loadConfig(runtime) };
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
