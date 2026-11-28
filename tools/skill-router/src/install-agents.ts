import { join } from "node:path";
import { buildCatalog } from "./catalog.ts";
import type { RouterContext } from "./types.ts";

const COMPACT_START = "<!-- skill-router:compact:start -->";
const COMPACT_END = "<!-- skill-router:compact:end -->";
const LEGACY_MARKER_START = "<!-- skill-router:available_skills:start -->";
const LEGACY_MARKER_END = "<!-- skill-router:available_skills:end -->";
const LEGACY_INTENT_START = "<!-- intent-skills:start -->";
const LEGACY_INTENT_END = "<!-- intent-skills:end -->";

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
  const { text: compactText } = await buildCatalog(cwd, {
    map: opts.map,
    format: "compact",
    ctx: opts.ctx,
  });
  const compactInner = markedInner(compactText, COMPACT_START, COMPACT_END);

  const file = Bun.file(targetPath);
  const exists = await file.exists();
  let content = exists ? await file.text() : "# AGENTS.md\n";

  content = removeMarkedBlock(content, LEGACY_INTENT_START, LEGACY_INTENT_END);
  content = removeMarkedBlock(content, LEGACY_MARKER_START, LEGACY_MARKER_END);
  content = removeLegacyAvailableSkills(content);
  content = replaceMarkedBlock(content, COMPACT_START, COMPACT_END, compactInner);

  if (!opts.dryRun) {
    await Bun.write(targetPath, content);
  }

  return { path: targetPath, text: content, wrote: !opts.dryRun };
}

export function defaultAgentsPath(cwd: string): string {
  return join(cwd, "AGENTS.md");
}
