#!/usr/bin/env bun
// Mechanical checks only. Word choice and one-meaning-per-word need a reader.

const INSTRUCTION_MAX = 20;
const DESCRIPTION_MAX = 25;
const PARAGRAPH_MAX = 6;
const HEDGES = /\b(should|would|may|might)\b/gi;
const INFLATION = /\b(crucial|critical(?:ly)?|robust|seamless(?:ly)?|leverag\w*|utiliz\w*|delve\w*|powerful|essential)\b/gi;
const PASSIVE = /\b(?:is|are|was|were|be|been|being)\s+(?:\w+ly\s+)?(\w+ed|built|done|made|run|set|sent|shown|written|taken|given)\b/gi;
const TRAILING_ING = /,\s+(\w+ing)\b/g;
const DASH = /—|\s–\s|\s--\s/g;

type Finding = { line: number; rule: string; text: string };

const path = Bun.argv[2];
if (!path) {
  console.error("usage: bun ste-check.ts FILE");
  process.exit(2);
}

const source = await Bun.file(path).text();
const findings: Finding[] = [];

const lines = source.split("\n");
let inFence = false;
const prose: { line: number; text: string }[] = [];
for (const [index, raw] of lines.entries()) {
  if (/^\s*(```|~~~)/.test(raw)) {
    inFence = !inFence;
    prose.push({ line: index + 1, text: "" });
    continue;
  }
  const skip = inFence || /^\s*(#|\||<!--|---\s*$)/.test(raw);
  const text = skip ? "" : raw.replace(/`[^`]*`/g, "CODE").replace(/https?:\/\/\S+/g, "URL");
  prose.push({ line: index + 1, text });
}

const excerpt = (sentence: string) =>
  sentence.length > 70 ? `${sentence.slice(0, 67)}...` : sentence;

const isListItem = (text: string) => /^\s*(?:[-*+]|\d+[.)])\s+/.test(text);
const isInstruction = (text: string) => /^\s*\d+[.)]\s+/.test(text);

function checkSentences(text: string, line: number, instruction: boolean) {
  const body = text.replace(/^\s*(?:[-*+]|\d+[.)])\s+/, "").replace(/\*\*([^*]+)\*\*:?/g, "$1");
  const sentences = body.split(/(?<=[.!?])\s+(?=[A-Z"'(])/).filter((s) => s.trim());
  for (const sentence of sentences) {
    const words = sentence.split(/\s+/).filter((w) => /[A-Za-z0-9]/.test(w)).length;
    const limit = instruction ? INSTRUCTION_MAX : DESCRIPTION_MAX;
    if (words > limit) {
      const kind = instruction ? "instruction" : "description";
      findings.push({ line, rule: `${kind} ${words} words > ${limit}`, text: excerpt(sentence) });
    }
  }
  return sentences.length;
}

function checkPatterns(text: string, line: number) {
  for (const [rule, pattern] of [
    ["hedge", HEDGES],
    ["importance word", INFLATION],
    ["passive voice", PASSIVE],
    ["trailing -ing clause", TRAILING_ING],
    ["dash join", DASH],
  ] as const) {
    for (const match of text.matchAll(pattern)) {
      findings.push({ line, rule, text: match[0].trim() });
    }
  }
}

type Block = { line: number; text: string; listItem: boolean; instruction: boolean };
const blocks: Block[] = [];
let current: Block | undefined;
for (const { line, text } of prose) {
  if (!text.trim()) {
    current = undefined;
    continue;
  }
  if (isListItem(text) || !current) {
    current = { line, text: text.trim(), listItem: isListItem(text), instruction: isInstruction(text) };
    blocks.push(current);
    continue;
  }
  current.text += ` ${text.trim()}`;
}

for (const block of blocks) {
  const count = checkSentences(block.text, block.line, block.instruction);
  checkPatterns(block.text, block.line);
  if (!block.listItem && count > PARAGRAPH_MAX) {
    findings.push({ line: block.line, rule: `paragraph ${count} sentences > ${PARAGRAPH_MAX}`, text: "" });
  }
}

for (const { line, rule, text } of findings) {
  console.log(`${path}:${line}\t${rule}${text ? `\t${text}` : ""}`);
}
console.log(`${findings.length} findings`);
process.exit(findings.length > 0 ? 1 : 0);
