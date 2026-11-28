import type { CommandRunner } from "./command-runner.ts";
import type { ReadText } from "./file-reader.ts";

export type ScopeName = "repo" | "workspace" | "user";

export type SkillRecord = {
  id: string;
  scope: ScopeName;
  description: string;
  path: string;
  lines?: number;
  precedence: number;
};

export type ScopeConfig = {
  precedence: number;
  dirs?: string[];
  exclude?: string[];
};

export type AgentConfig = {
  dir: string;
  mode: "filesystem" | "logical";
};

export type RouterConfig = {
  scopes: Record<ScopeName, ScopeConfig>;
  agents: Record<string, AgentConfig>;
  catalog: {
    maxEntries: number;
    maxDescriptionChars: number;
  };
};

export type RouterRuntime = {
  run: CommandRunner;
  readText: ReadText;
  env: Record<string, string | undefined>;
  configPath?: string;
};

// Resolved once at the cli.ts edge: the injected runtime plus the parsed config.
// Threaded through every module so config is read once per invocation;
// downstream modules read ctx.config instead of re-calling loadConfig.
export type RouterContext = {
  runtime: RouterRuntime;
  config: RouterConfig;
};

export type DiscoverOptions = {
  cwd: string;
  ctx?: RouterContext;
};
