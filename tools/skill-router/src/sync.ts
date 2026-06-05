import { lstat, mkdir, readlink, rm, symlink } from "node:fs/promises";
import { dirname, join } from "node:path";
import { expandPath, loadConfig } from "./config.ts";
import { discoverSkills } from "./discover.ts";
import type { SkillRecord } from "./types.ts";

type SyncResult = {
  agent: string;
  linked: string[];
  skipped: string[];
};

async function exists(path: string): Promise<boolean> {
  try {
    await lstat(path);
    return true;
  } catch {
    return false;
  }
}

async function ensureSymlink(target: string, linkPath: string, dryRun: boolean): Promise<"linked" | "skipped"> {
  if (!(await exists(target))) return "skipped";

  try {
    if ((await readlink(linkPath)) === target) return "skipped";
  } catch {
    // Not a symlink, missing, or unreadable. Replace below.
  }

  if (dryRun) return "linked";

  await mkdir(dirname(linkPath), { recursive: true });
  await rm(linkPath, { recursive: true, force: true });
  await symlink(target, linkPath, "dir");
  return "linked";
}

function skillsForAgent(skills: SkillRecord[], agent: string, scopes: Set<string>): SkillRecord[] {
  if (agent === "all") {
    return skills.filter((s) => scopes.has(s.scope) && s.path && !s.intentId);
  }
  return skills.filter((s) => scopes.has(s.scope) && s.path && !s.intentId);
}

export async function syncAgents(
  cwd: string,
  opts: { agents?: string[]; scopes?: string[]; dryRun?: boolean },
): Promise<SyncResult[]> {
  const config = await loadConfig();
  const skills = await discoverSkills({ cwd, includePackage: false });
  const scopeSet = new Set(opts.scopes ?? ["repo", "workspace"]);
  const agentNames = opts.agents ?? Object.keys(config.agents);
  const dryRun = opts.dryRun ?? false;
  const results: SyncResult[] = [];

  for (const agent of agentNames) {
    const agentConfig = config.agents[agent];
    if (!agentConfig || agentConfig.mode !== "filesystem") continue;

    const destRoot = expandPath(agentConfig.dir);
    const linked: string[] = [];
    const skipped: string[] = [];

    for (const skill of skillsForAgent(skills, agent, scopeSet)) {
      const linkPath = join(destRoot, skill.id);
      const outcome = await ensureSymlink(skill.path.replace(/\/SKILL\.md$/, ""), linkPath, dryRun);
      if (outcome === "linked") linked.push(skill.id);
      else skipped.push(skill.id);
    }

    results.push({ agent, linked, skipped });
  }

  return results;
}
