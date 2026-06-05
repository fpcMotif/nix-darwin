export type ScopeName = "repo" | "workspace" | "user" | "package";

export type SkillRecord = {
  id: string;
  scope: ScopeName;
  description: string;
  path: string;
  lines?: number;
  intentId?: string;
  package?: string;
  precedence: number;
};

export type ScopeConfig = {
  precedence: number;
  dirs?: string[];
  exclude?: string[];
  provider?: "intent";
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
    intentRunner: string;
    // Package scope (TanStack Intent) is opt-in. When false (default) the
    // intentRunner is never spawned unless a caller passes includePackage:true
    // (CLI `--package`), keeping discovery local-only and off the network.
    packageScope?: boolean;
  };
};

export type DiscoverOptions = {
  cwd: string;
  includePackage?: boolean;
  includeGlobalPackages?: boolean;
};
