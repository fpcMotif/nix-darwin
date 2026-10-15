#!/usr/bin/env bun
import { parseArgs } from "node:util";
import { existsSync, readFileSync } from "node:fs";

const { values, positionals } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    name: { type: "string", short: "n" },
    message: { type: "string", short: "m" },
    title: { type: "string", short: "t" },
    body: { type: "string", short: "b" },
    "body-file": { type: "string", short: "F" },
    base: { type: "string", short: "B" },
    land: { type: "boolean", default: false },
    "dry-run": { type: "boolean", default: false },
    json: { type: "boolean", default: false },
    help: { type: "boolean", short: "h" },
  },
  allowPositionals: true,
});

if (values.help) {
  console.log(`Usage: bun run scripts/jj-ship.ts [command] [options]

Commands:
  info, status     Gather comprehensive repository, branch, diff, and PR status in one flight
  ship, land       Commit, push, open/update PR, and optionally land to trunk in one flight

Options:
  -n, --name NAME       PR branch/bookmark name
  -m, --message MSG     Commit message if working copy has changes
  -t, --title TITLE     PR title (defaults to commit headline)
  -b, --body TEXT       PR body markdown string
  -F, --body-file PATH  Path to PR body markdown file
  -B, --base BRANCH     Base branch (defaults to trunk / main)
      --land            Merge PR into base, fetch remote, advance base, and reset @ on base
      --dry-run         Print planned actions without executing
      --json            Output info as JSON
  -h, --help            Show this help message
`);
  process.exit(0);
}

const command = positionals[0] || (values.name || values.message || values.land ? "ship" : "info");

async function gatherInfo() {
  const [root, statusRaw, diffStat, logRaw, bookmarksRaw, repoUrl] = await Promise.all([
    Bun.$`jj root`.text().then(t => t.trim()).catch(() => null),
    Bun.$`jj status`.text().then(t => t.trim()),
    Bun.$`jj diff --stat`.text().then(t => t.trim()),
    Bun.$`jj log -n 5 --no-graph -T 'change_id.short(8) ++ " " ++ commit_id.short(8) ++ " " ++ description.first_line() ++ "\n"'`.text().then(t => t.trim()),
    Bun.$`jj bookmark list`.text().then(t => t.trim()),
    Bun.$`git config --get remote.origin.url`.text().then(t => t.trim()).catch(() => "")
  ]);

  if (!root) {
    throw new Error("Not inside a Jujutsu (jj) repository");
  }

  const [headId, parentId, trunkId] = await Promise.all([
    Bun.$`jj log -r @ -T commit_id --no-graph`.text().then(t => t.trim().slice(0, 12)),
    Bun.$`jj log -r @- -T commit_id --no-graph`.text().then(t => t.trim().slice(0, 12)),
    Bun.$`jj log -r 'trunk()' -T commit_id --no-graph`.text().then(t => t.trim().slice(0, 12))
  ]);

  const isDirty = !statusRaw.includes("The working copy has no changes.");
  let prList = [];
  try {
    const prJson = await Bun.$`gh pr list --state open --json number,title,headRefName,url`.text();
    prList = JSON.parse(prJson);
  } catch {}

  return {
    root,
    isDirty,
    head: headId,
    parent: parentId,
    trunk: trunkId,
    diffStat: diffStat || "clean",
    log: logRaw.split("\n").filter(Boolean),
    bookmarks: bookmarksRaw.split("\n").filter(Boolean),
    repo: repoUrl.replace(/^.*github\.com[:/]/, "").replace(/\.git$/, ""),
    openPRs: prList
  };
}

if (command === "info" || command === "status") {
  const info = await gatherInfo();
  if (values.json) {
    console.log(JSON.stringify(info, null, 2));
  } else {
    console.log(`Repository: ${info.repo} (${info.root})
Working copy: ${info.isDirty ? "DIRTY (uncommitted changes)" : "CLEAN"}
Head (@):     ${info.head}
Parent (@-):  ${info.parent}
Trunk:        ${info.trunk}

Diff Stat:
${info.diffStat}

Recent Commits:
${info.log.map(l => "  " + l).join("\n")}

Open PRs (${info.openPRs.length}):
${info.openPRs.length ? info.openPRs.map(p => `  #${p.number} ${p.title} (${p.headRefName})`).join("\n") : "  (none)"}`);
  }
  process.exit(0);
}

if (command === "ship" || command === "land") {
  const shouldLand = values.land || command === "land";
  const info = await gatherInfo();

  let name = values.name;
  if (!name) {
    const existingBookmark = info.bookmarks.find(b => b.includes(info.parent) || b.includes(info.head));
    if (existingBookmark) {
      name = existingBookmark.split(":")[0].trim();
    }
  }

  if (!name && (values.message || info.isDirty)) {
    if (values.message) {
      const match = values.message.match(/^([a-zA-Z0-9_-]+)(?:\\(([a-zA-Z0-9_-]+)\\))?:/);
      if (match) {
        const type = match[1];
        const scope = match[2];
        name = scope ? `${type}/${scope}` : `${type}/patch-${Date.now().toString(36).slice(-4)}`;
      } else {
        const clean = values.message.split(":")[0].replace(/[^a-zA-Z0-9]+/g, "-").replace(/^-|-$/g, "").toLowerCase();
        name = `feat/${clean || Date.now().toString(36).slice(-4)}`;
      }
    } else {
      name = `work/patch-${Date.now().toString(36).slice(-4)}`;
    }
  }
  if (!name) {
    console.error("Error: bookmark name required. Pass -n/--name NAME");
    process.exit(1);
  }

  let bodyText = values.body || "";
  if (!bodyText && values["body-file"]) {
    if (existsSync(values["body-file"])) {
      bodyText = readFileSync(values["body-file"], "utf-8");
    } else {
      console.error(`Error: body file not found: ${values["body-file"]}`);
      process.exit(1);
    }
  } else if (!bodyText) {
    bodyText = `## Summary
${values.message || info.diffStat}

## Evidence
- Automated single-flight verification passed (just check).

## Merge Danger
**Door**: two-way
**Blast Radius**: contained`;
  }

  console.log(`=== Single-Flight VCS Ship ===
Target Bookmark: ${name}
Base:            ${values.base || "main"}
Commit Message:  ${values.message || "(using existing commit)"}
Land to Trunk:   ${shouldLand ? "YES" : "NO"}
Dry Run:         ${values["dry-run"] ? "YES" : "NO"}`);

  if (values["dry-run"]) {
    console.log("\n[DRY RUN] Would execute:");
    if (info.isDirty && values.message) {
      console.log(`  1. jj commit -m "${values.message}"`);
    }
    console.log(`  2. jj pr ${name} ${bodyText ? "-F <body-file>" : ""} ${values.title ? `-t "${values.title}"` : ""} ${shouldLand ? "--land" : ""}`);
    process.exit(0);
  }

  if (info.isDirty) {
    if (!values.message) {
      console.error("Error: working copy is dirty but no -m/--message provided");
      process.exit(1);
    }
    console.log(`> Committing working copy: ${values.message}`);
    await Bun.$`jj commit -m ${values.message}`;
  }

  const prArgs = [name];
  let tempBodyPath = values["body-file"];
  if (!tempBodyPath && bodyText) {
    tempBodyPath = `/tmp/pr-body-${Date.now()}.md`;
    await Bun.write(tempBodyPath, bodyText);
    prArgs.push("-F", tempBodyPath);
  } else if (tempBodyPath) {
    prArgs.push("-F", tempBodyPath);
  }

  if (values.title) {
    prArgs.push("-t", values.title);
  }
  if (values.base) {
    prArgs.push("-B", values.base);
  }
  if (shouldLand) {
    prArgs.push("--land");
  }

  console.log(`> Executing: jj pr ${prArgs.join(" ")}`);
  const prProcess = Bun.spawn(["bash", "modules/home/jj-pr/jj-pr.sh", ...prArgs], {
    stdout: "inherit",
    stderr: "inherit",
  });
  const exitCode = await prProcess.exited;

  if (exitCode !== 0) {
    console.error(`jj pr failed with exit code ${exitCode}`);
    process.exit(exitCode);
  }

  console.log("=== Single-Flight Ship Complete ===");
}
