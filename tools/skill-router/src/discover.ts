import { isAbsolute, join } from "node:path";
import { loadConfig, resolveScopeDirs } from "./config.ts";
import { discoverFromDirs } from "./discover-local.ts";
import { discoverIntentSkills } from "./discover-intent.ts";
import { findGitRoot } from "./git.ts";
import type { DiscoverOptions, SkillRecord } from "./types.ts";

function rooted(root: string, path: string): string {
  return isAbsolute(path) ? path : join(root, path);
}

export async function discoverSkills(options: DiscoverOptions): Promise<SkillRecord[]> {
  const config = await loadConfig();
  const cwd = options.cwd;
  const gitRoot = await findGitRoot(cwd);

  const batches: SkillRecord[][] = [];

  const repoDirs = resolveScopeDirs(config.scopes.repo.dirs).map((d) => rooted(cwd, d));
  batches.push(
    await discoverFromDirs("repo", config.scopes.repo.precedence, repoDirs),
  );

  if (gitRoot && cwd !== gitRoot) {
    const workspaceDirs = resolveScopeDirs(config.scopes.workspace.dirs).map((d) => rooted(gitRoot, d));
    batches.push(
      await discoverFromDirs("workspace", config.scopes.workspace.precedence, workspaceDirs),
    );
  }

  const userDirs = resolveScopeDirs(config.scopes.user.dirs);
  batches.push(
    await discoverFromDirs(
      "user",
      config.scopes.user.precedence,
      userDirs,
      config.scopes.user.exclude ?? [],
    ),
  );

  if (options.includePackage !== false) {
    batches.push(
      await discoverIntentSkills(
        cwd,
        config.catalog.intentRunner,
        config.scopes.package.precedence,
        options.includeGlobalPackages ?? false,
      ),
    );
  }

  const merged = new Map<string, SkillRecord>();
  const sorted = batches.flat().sort((a, b) => b.precedence - a.precedence);

  for (const skill of sorted) {
    if (!merged.has(skill.id)) {
      merged.set(skill.id, skill);
    }
  }

  return [...merged.values()].sort((a, b) => a.id.localeCompare(b.id));
}

export function toLogicalId(skill: SkillRecord): string {
  if (skill.intentId) return skill.intentId;
  return `${skill.scope}:${skill.id}`;
}

export function resolveSkill(skills: SkillRecord[], query: string): SkillRecord | undefined {
  if (query.includes("#") || query.startsWith("@")) {
    return skills.find((s) => s.intentId === query);
  }
  if (query.includes(":")) {
    const [scope, id] = query.split(":", 2);
    return skills.find((s) => s.scope === scope && s.id === id);
  }
  return skills.find((s) => s.id === query);
}
