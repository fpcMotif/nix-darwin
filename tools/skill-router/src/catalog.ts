import { loadConfig } from "./config.ts";
import { discoverSkills, toLogicalId } from "./discover.ts";
import type { SkillRecord } from "./types.ts";

function trimDescription(text: string, max: number): string {
  const oneLine = text.replace(/\s+/g, " ").trim();
  if (oneLine.length <= max) return oneLine;
  if (max <= 3) return oneLine.slice(0, max);
  return `${oneLine.slice(0, max - 3)}...`;
}

function escapeXml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

export function renderAgentsBlock(skills: SkillRecord[], maxEntries: number, maxDesc: number): string {
  const picked = skills.slice(0, maxEntries);
  const entries = picked
    .map((skill) => {
      const logical = escapeXml(toLogicalId(skill));
      const desc = escapeXml(trimDescription(skill.description || `${skill.scope} skill`, maxDesc));
      const id = escapeXml(skill.id);
      return `  <skill>
    <name>${id}</name>
    <description>${desc}</description>
    <location>${logical}</location>
  </skill>`;
    })
    .join("\n");

  return `<available_skills>
${entries}
</available_skills>`;
}

export function renderIntentBlock(map = false): string {
  const mapLines = map
    ? `- Task mappings: run \`skill-router catalog --map\` for explicit task-to-skill pairs when a repo opts in.`
    : "";

  return `<!-- intent-skills:start -->
## Skill Loading

Keep startup skill context near-zero. Discover/load only on demand:
\`skill-router discover --json\`; \`skill-router load scope:id\`; packages: \`bunx @tanstack/intent@latest list|load @pkg#name\`.
Load 1-2 matching SKILL.md files max. Scope order: repo > workspace > user > package.
${mapLines}
<!-- intent-skills:end -->`;
}

export function renderMapTable(skills: SkillRecord[]): string {
  const rows = skills
    .filter((s) => s.description)
    .slice(0, 24)
    .map((s) => `| ${s.id} | ${toLogicalId(s)} | ${trimDescription(s.description, 80)} |`)
    .join("\n");

  return `| Skill | Load as | When |
| --- | --- | --- |
${rows}`;
}

export async function buildCatalog(cwd: string, opts: { map?: boolean; format?: "compact" | "agents" | "intent" | "all" }) {
  const config = await loadConfig();
  const skills = await discoverSkills({ cwd, includePackage: true });
  const format = opts.format ?? "all";

  const parts: string[] = [];
  if (format === "intent" || format === "compact" || format === "all") {
    parts.push(renderIntentBlock(opts.map));
  }
  if (format === "agents" || format === "all") {
    parts.push(renderAgentsBlock(skills, config.catalog.maxEntries, config.catalog.maxDescriptionChars));
  }
  if (opts.map) {
    parts.push(renderMapTable(skills));
  }

  return { skills, text: parts.join("\n\n") };
}
