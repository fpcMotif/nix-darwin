import { join } from "node:path";
import { buildCatalog } from "./catalog.ts";
import type { RouterContext } from "./types.ts";

const MARKER_START = "<!-- skill-router:available_skills:start -->";
const MARKER_END = "<!-- skill-router:available_skills:end -->";
const INTENT_START = "<!-- intent-skills:start -->";
const INTENT_END = "<!-- intent-skills:end -->";

function replaceMarkedBlock(content: string, start: string, end: string, inner: string): string {
  const pattern = new RegExp(`${escapeRegExp(start)}[\\s\\S]*${escapeRegExp(end)}`, "m");
  const block = `${start}\n${inner.trim()}\n${end}`;
  if (pattern.test(content)) return content.replace(pattern, block);
  return `${content.trimEnd()}\n\n${block}\n`;
}

function removeMarkedBlock(content: string, start: string, end: string): string {
  const pattern = new RegExp(`\\n*${escapeRegExp(start)}[\\s\\S]*${escapeRegExp(end)}\\n*`, "m");
  return content.replace(pattern, "\n").replace(/\n{3,}/g, "\n\n").trimEnd() + "\n";
}

function markedInner(content: string, start: string, end: string): string {
  const startAt = content.indexOf(start);
  const endAt = content.indexOf(end);
  if (startAt === -1 || endAt === -1 || endAt < startAt) return content.trim();
  return content.slice(startAt + start.length, endAt).trim();
}

function removeLegacyAvailableSkills(content: string): string {
  return content.replace(/<available_skills>[\s\S]*?<\/available_skills>\s*/g, "");
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export async function installAgentsMd(
  cwd: string,
  targetPath: string,
  opts: { map?: boolean; dryRun?: boolean; ctx?: RouterContext },
): Promise<{ path: string; text: string; wrote: boolean }> {
  const { text: intentText } = await buildCatalog(cwd, {
    map: opts.map,
    format: "compact",
    includePackage: false,
    ctx: opts.ctx,
  });
  const intentInner = markedInner(intentText, INTENT_START, INTENT_END);

  const file = Bun.file(targetPath);
  const exists = await file.exists();
  let content = exists ? await file.text() : "# AGENTS.md\n";

  content = replaceMarkedBlock(content, INTENT_START, INTENT_END, intentInner);
  content = removeMarkedBlock(content, MARKER_START, MARKER_END);

  // Drop legacy flat <available_skills> blocks outside skill-router markers.
  content = removeLegacyAvailableSkills(content);

  if (!opts.dryRun) {
    await Bun.write(targetPath, content);
  }

  return { path: targetPath, text: content, wrote: !opts.dryRun };
}

export function defaultAgentsPath(cwd: string): string {
  return join(cwd, "AGENTS.md");
}
