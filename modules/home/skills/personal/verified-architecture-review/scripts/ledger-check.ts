#!/usr/bin/env bun

type Verdict = "DO" | "SHRINK" | "DROP";
type Premise = { claim: string; command: string; output: string; holds: boolean | "partial" };
type Count = { claim: string; card?: number; value: number; command?: string; output?: string; guess?: boolean };
type Churn = { sha: string; kind: "rewording" | "behavior" };
type Artifact = { path: string; command: string; findings: string[] };
type Entry = {
  id: string;
  title: string;
  premise: Premise;
  counts: Count[];
  churn?: Churn[];
  artifacts: Artifact[];
  verdict: Verdict;
  reason: string;
};

const file = Bun.argv[2];
if (!file) {
  console.error("usage: ledger-check.ts LEDGER.json");
  process.exit(2);
}

const entries: Entry[] = await Bun.file(file).json();
const errors: string[] = [];
const verdicts = new Set<Verdict>(["DO", "SHRINK", "DROP"]);
const filled = (text: unknown) => typeof text === "string" && text.trim() !== "" && !text.includes("…");

for (const entry of entries) {
  const fail = (message: string) => errors.push(`${entry.id ?? "?"}: ${message}`);

  if (!verdicts.has(entry.verdict)) fail(`verdict must be DO, SHRINK, or DROP, not ${entry.verdict}`);
  if (!filled(entry.reason)) fail("reason is empty");

  const premise = entry.premise;
  if (!premise || !filled(premise.command) || !filled(premise.output)) {
    fail("premise needs the command you ran and its real output");
  } else if (premise.holds !== true && premise.holds !== false && premise.holds !== "partial") {
    fail('premise.holds must be true, false, or "partial"');
  }
  if (premise?.holds === false && entry.verdict === "DO") fail("a failed premise can never be DO");
  if (premise?.holds === "partial" && entry.verdict === "DO") fail("a partial premise is SHRINK at most");

  const counts = entry.counts ?? [];
  for (const count of counts) {
    const measured = filled(count.command) && filled(count.output);
    if (!measured && count.guess !== true) fail(`count "${count.claim}" needs a command and output, or guess: true`);
    if (measured && count.guess === true) fail(`count "${count.claim}" is measured, so drop guess: true`);
    if (measured && count.card !== undefined && count.card !== count.value) {
      if (entry.verdict === "DO") fail(`count "${count.claim}" is ${count.value}, not the card's ${count.card}, so the card is SHRINK at most`);
      console.log(`${entry.id}: correct "${count.claim}" from ${count.card} to ${count.value} in the card`);
    }
  }
  if (counts.length > 0 && counts.every((count) => count.guess === true) && entry.verdict === "DO") {
    fail("every count is a guess, so the card can never be DO");
  }

  if (entry.churn) {
    if (entry.churn.length === 0) fail("churn is present but lists no commits");
    for (const commit of entry.churn) {
      if (commit.kind !== "rewording" && commit.kind !== "behavior") fail(`commit ${commit.sha} needs kind rewording or behavior`);
    }
    const rewording = entry.churn.filter((commit) => commit.kind === "rewording").length;
    if (rewording * 2 <= entry.churn.length && entry.verdict === "DO") {
      fail(`only ${rewording} of ${entry.churn.length} churn commits are rewording, so the brittleness claim is SHRINK at most`);
    }
  }

  if (!entry.artifacts || entry.artifacts.length === 0) fail("render and read at least one artifact the candidate touches");
  for (const artifact of entry.artifacts ?? []) {
    if (!filled(artifact.command)) fail(`artifact ${artifact.path} needs the command that rendered or read it`);
    for (const finding of artifact.findings ?? []) console.log(`${entry.id}: finding in ${artifact.path}: ${finding}`);
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(error);
  process.exit(1);
}
for (const entry of entries) console.log(`${entry.id}: ${entry.verdict}: ${entry.title}`);
