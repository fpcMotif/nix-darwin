import { loadIntentSkill } from "./discover-intent.ts";
import { discoverAllSkills, discoverSkills, resolveSkill } from "./discover.ts";
import { loadConfig } from "./config.ts";

export async function loadSkill(cwd: string, query: string): Promise<{ content: string; path: string; source: string } | null> {
  const config = await loadConfig();

  if (query.includes("#") || query.startsWith("@")) {
    const loaded = await loadIntentSkill(cwd, config.catalog.intentRunner, query);
    if (!loaded) return null;
    return { ...loaded, source: "intent" };
  }

  const localOptions = { cwd, includePackage: false };
  const skills = query.includes(":")
    ? await discoverAllSkills(localOptions)
    : await discoverSkills(localOptions);
  const match = resolveSkill(skills, query);
  if (!match?.path) return null;

  const file = Bun.file(match.path);
  if (!(await file.exists())) return null;

  return {
    content: await file.text(),
    path: match.path,
    source: `${match.scope}:${match.id}`,
  };
}

export async function loadSkillPathOnly(cwd: string, query: string): Promise<string | null> {
  const result = await loadSkill(cwd, query);
  return result?.path ?? null;
}
