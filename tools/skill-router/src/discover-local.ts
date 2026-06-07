import { readdir, readlink, stat } from "node:fs/promises";
import { join } from "node:path";
import { parseFrontmatter } from "./frontmatter.ts";
import type { ScopeName, SkillRecord } from "./types.ts";

async function isDir(path: string): Promise<boolean> {
  try {
    return (await stat(path)).isDirectory();
  } catch {
    return false;
  }
}

async function readSkill(dir: string, name: string): Promise<SkillRecord | null> {
  const skillPath = join(dir, "SKILL.md");
  const file = Bun.file(skillPath);
  if (!(await file.exists())) return null;

  const content = await file.text();
  const fm = parseFrontmatter(content);
  const lines = content.split("\n").length;

  return {
    id: fm.name ?? name,
    scope: "user",
    description: fm.description ?? "",
    path: skillPath,
    lines,
    precedence: 0,
  };
}

async function resolveSkillDir(root: string, name: string): Promise<string | null> {
  const direct = join(root, name);
  const directSkill = join(direct, "SKILL.md");
  if (await Bun.file(directSkill).exists()) return direct;

  try {
    const linkTarget = await readlink(direct);
    const resolved = linkTarget.startsWith("/") ? linkTarget : join(root, linkTarget);
    if (await Bun.file(join(resolved, "SKILL.md")).exists()) return resolved;
  } catch {
    // not a symlink
  }
  return null;
}

async function listSkillDirs(root: string): Promise<Array<{ name: string; dir: string }>> {
  let entries: string[] = [];
  try {
    entries = await readdir(root);
  } catch {
    return [];
  }

  const found: Array<{ name: string; dir: string }> = [];
  for (const name of entries) {
    if (name.startsWith(".")) continue;
    const dir = await resolveSkillDir(root, name);
    if (dir) found.push({ name, dir });
  }
  return found;
}

export async function discoverFromDirs(
  scope: ScopeName,
  precedence: number,
  roots: string[],
  exclude: string[] = [],
): Promise<SkillRecord[]> {
  const byId = new Map<string, SkillRecord>();

  for (const root of roots) {
    if (!(await isDir(root))) continue;

    for (const { name, dir } of await listSkillDirs(root)) {
      if (exclude.includes(name)) continue;
      const skill = await readSkill(dir, name);
      if (!skill) continue;
      skill.scope = scope;
      skill.precedence = precedence;

      const existing = byId.get(skill.id);
      if (!existing || precedence > existing.precedence) {
        byId.set(skill.id, skill);
      }
    }
  }

  return [...byId.values()];
}
