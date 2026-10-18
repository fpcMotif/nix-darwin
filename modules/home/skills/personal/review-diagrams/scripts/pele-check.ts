#!/usr/bin/env bun
// Bun auto-installs the pinned import when no node_modules sits above this file.
import { relative } from "node:path";
import { PeleError, parse, render } from "pele@1.6.0";

type Diagram = { file: string; line: number; source: string; headline?: string; evidence: string[] };
type Transition = { from: string; to: string | null; event: string; edge: string };
type Machine = { initial: string; states: string[]; finals: string[]; transitions: Transition[] };

const args = Bun.argv.slice(2);
const artifact = args.includes("--artifact");
const htmlIndex = args.indexOf("--html");
const htmlOut = htmlIndex >= 0 ? args[htmlIndex + 1] : undefined;
const files = args.filter((a, i) => a !== "--artifact" && (htmlIndex < 0 || (i !== htmlIndex && i !== htmlIndex + 1)));

if (files.length === 0 || (htmlIndex >= 0 && !htmlOut) || (artifact && !htmlOut)) {
  console.error("usage: pele-check.ts FILE... [--html OUT.html [--artifact]]");
  process.exit(2);
}

function extract(file: string, text: string): Diagram[] {
  if (!file.endsWith(".md")) return [{ file, line: 1, source: text, evidence: [] }];
  const lines = text.split("\n");
  const diagrams: Diagram[] = [];
  for (let i = 0; i < lines.length; i++) {
    const open = lines[i].match(/^(\s*)(`{3,})mermaid\s*$/);
    if (!open) continue;
    let before = i - 1;
    while (before >= 0 && lines[before].trim() === "") before--;
    const prior = before >= 0 ? lines[before].trim() : "";
    const headline = prior && !prior.startsWith("```") && !prior.startsWith("- ") && !prior.startsWith("|")
      ? prior.replace(/^#+\s*/, "").replace(/^>\s*/, "")
      : undefined;
    const start = i + 1;
    let end = start;
    while (end < lines.length && !lines[end].trim().startsWith(open[2])) end++;
    let after = end + 1;
    while (after < lines.length && lines[after].trim() === "") after++;
    const evidence: string[] = [];
    while (after < lines.length && /^\s*- /.test(lines[after])) evidence.push(lines[after++].replace(/^\s*- /, ""));
    diagrams.push({ file, line: start + 1, source: lines.slice(start, end).join("\n"), headline, evidence });
    i = end;
  }
  return diagrams;
}

function stateMachine(source: string): Machine | undefined {
  const model = parse(source) as { type: string; relations?: { id1: string; id2: string; relationTitle: string }[] };
  if (model.type !== "state" || !model.relations) return undefined;
  let initial = "";
  const states = new Set<string>();
  const transitions: Transition[] = [];
  model.relations.forEach((r, i) => {
    if (r.id1 === "root_start") { initial = r.id2; states.add(r.id2); return; }
    states.add(r.id1);
    if (r.id2 !== "root_end") states.add(r.id2);
    transitions.push({ from: r.id1, to: r.id2 === "root_end" ? null : r.id2, event: r.relationTitle, edge: `edge${i}` });
  });
  if (!initial) return undefined;
  const finals = [...states].filter((s) => transitions.some((t) => t.from === s && t.to === null)
    && transitions.every((t) => t.from !== s || t.to === null));
  return { initial, states: [...states], finals, transitions };
}

const escape = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const inline = (s: string) => escape(s).replace(/`([^`]+)`/g, "<code>$1</code>").replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");

const diagrams: Diagram[] = [];
for (const file of files) diagrams.push(...extract(file, await Bun.file(file).text()));

if (diagrams.length === 0) {
  console.error(`no mermaid diagrams found in ${files.join(", ")}`);
  process.exit(1);
}

const items: object[] = [];
let failures = 0;
for (const diagram of diagrams) {
  const near = relative(process.cwd(), diagram.file);
  const location = `${near.startsWith("..") ? diagram.file : near}:${diagram.line}`;
  try {
    const { svg, type } = render(diagram.source, { idPrefix: `d${items.length}-` });
    items.push({
      anchor: `d${items.length + 1}`,
      headline: diagram.headline ?? `${type} at ${location}`,
      location,
      type,
      svg,
      source: diagram.source,
      evidence: diagram.evidence.length ? `<ul>${diagram.evidence.map((e) => `<li>${inline(e)}</li>`).join("")}</ul>` : "",
      findings: diagram.evidence.filter((e) => /^\*\*F\d+\*\*/.test(e)).length,
      machine: stateMachine(diagram.source),
    });
    console.log(`ok ${location} ${type}`);
  } catch (error) {
    if (!(error instanceof PeleError)) throw error;
    failures++;
    const line = error.line > 0 ? diagram.line + error.line - 1 : diagram.line;
    console.log(`${diagram.file}:${line}:${error.column}: ${error.code}`);
    console.log(error.message.replace(/^/gm, "  "));
  }
}

if (htmlOut) {
  const firstHeading = (await Bun.file(files[0]).text()).match(/^#\s+(.+)$/m)?.[1];
  const title = escape(firstHeading ?? "Review diagrams");
  const template = await Bun.file(new URL("../assets/review-page.html", import.meta.url)).text();
  const data = JSON.stringify(items).replace(/</g, "\\u003c");
  // The Artifact host wraps the page in its own document, so only a local file gets a doctype.
  const page = template.replaceAll("__TITLE__", title).replace("__DATA__", () => data);
  await Bun.write(htmlOut, artifact ? page : `<!doctype html>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n${page}`);
  console.log(`wrote ${htmlOut}`);
}

process.exit(failures > 0 ? 1 : 0);
