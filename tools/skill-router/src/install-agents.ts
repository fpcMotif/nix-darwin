import { join } from "node:path";
import { buildCatalog } from "./catalog.ts";

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

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export async function installAgentsMd(
  cwd: string,
  targetPath: string,
  opts: { map?: boolean; dryRun?: boolean },
): Promise<{ path: string; text: string; wrote: boolean }> {
  const { text: catalogText } = await buildCatalog(cwd, { map: opts.map, format: "compact" });
  const splitAt = catalogText.indexOf("<available_skills>");
  const intentText = splitAt === -1 ? catalogText : catalogText.slice(0, splitAt);
  const intentInner = intentText.replace(INTENT_START, "").replace(INTENT_END, "").trim();
  const agentsInner = splitAt === -1 ? "" : catalogText.slice(splitAt).trim();

  const file = Bun.file(targetPath);
  const exists = await file.exists();
  let content = exists ? await file.text() : "# AGENTS.md\n";

  content = replaceMarkedBlock(content, INTENT_START, INTENT_END, intentInner);
  if (agentsInner) {
    content = replaceMarkedBlock(content, MARKER_START, MARKER_END, agentsInner);
  } else {
    content = removeMarkedBlock(content, MARKER_START, MARKER_END);
  }

  // Drop legacy flat <available_skills> blocks outside skill-router markers.
  if (content.includes(MARKER_START)) {
    const parts = content.split(MARKER_START);
    const head = parts[0].replace(/<available_skills>[\s\S]*?<\/available_skills>\s*/g, "");
    content = head + MARKER_START + parts.slice(1).join(MARKER_START);
  }

  if (!opts.dryRun) {
    await Bun.write(targetPath, content);
  }

  return { path: targetPath, text: content, wrote: !opts.dryRun };
}

export function defaultAgentsPath(cwd: string): string {
  return join(cwd, "AGENTS.md");
}
