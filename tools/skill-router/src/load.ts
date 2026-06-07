import { resolveContext } from "./config.ts";
import { discoverAllSkills, discoverSkills, resolveSkill } from "./discover.ts";
import { loadIntentSkill } from "./discover-intent.ts";
import type { RouterContext } from "./types.ts";

export async function loadSkill(
  cwd: string,
  query: string,
  ctx?: RouterContext,
): Promise<{ content: string; path: string; source: string } | null> {
  const resolved = ctx ?? (await resolveContext());
  const { runtime, config } = resolved;

  if (query.includes("#") || query.startsWith("@")) {
    const loaded = await loadIntentSkill(cwd, config.catalog.intentRunner, query, runtime.run, runtime.readText);
    if (!loaded) return null;
    return { ...loaded, source: "intent" };
  }

  const localOptions = { cwd, includePackage: false, ctx: resolved };
  const skills = query.includes(":")
    ? await discoverAllSkills(localOptions)
    : await discoverSkills(localOptions);
  const match = resolveSkill(skills, query);
  if (!match?.path) return null;

  const content = await runtime.readText(match.path);
  if (content === null) return null;

  return {
    content,
    path: match.path,
    source: `${match.scope}:${match.id}`,
  };
}

export async function loadSkillPathOnly(
  cwd: string,
  query: string,
  ctx?: RouterContext,
): Promise<string | null> {
  const result = await loadSkill(cwd, query, ctx);
  return result?.path ?? null;
}
