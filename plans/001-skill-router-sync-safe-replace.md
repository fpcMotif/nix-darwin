# Plan 001: `skill-router sync` never deletes anything except a stale symlink inside the agent skills dir

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e0b6770..HEAD -- tools/skill-router`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `e0b6770`, 2026-11-10
- **Issue**: https://github.com/fpcMotif/nix-darwin/issues/425

## Why this matters

`skill-router sync` links skills from the current project into each agent's
skills directory. It builds the link path from the `name:` field of a
`SKILL.md` file, which comes from whatever repository the user is standing in.
Before it links, it runs a recursive, forced delete on that path.

Two things go wrong today:

1. A `name:` that contains `..` segments makes the delete land outside the
   agent skills directory.
2. A `name:` that matches an existing real directory in the agent skills
   directory deletes that directory and all its contents.

Both were reproduced in a throwaway copy of the tool on 2026-11-10. After this
plan, sync removes only a symlink it is about to replace, and it reports every
skill it refused to link.

## Current state

Files:

- `tools/skill-router/src/sync.ts` — the sync command. Holds the delete.
- `tools/skill-router/src/cli.ts` — prints the sync result (lines 127-143).
- `tools/skill-router/src/discover-local.ts` — line 24 sets `id: fm.name ?? name`.
  The `name` value is read verbatim from SKILL.md frontmatter. Do not change this file.
- `tools/skill-router/test/subprocess-gating.test.ts` — the only existing test
  file. It is the style exemplar. There is no test for sync today.
- `tools/skill-router/test/support/doubles.ts` — exports `makeRecordingRunner`.

`tools/skill-router/src/sync.ts:22-37` today:

```ts
async function ensureSymlink(target: string, linkPath: string, dryRun: boolean): Promise<"linked" | "skipped"> {
  if (!(await exists(target))) return "skipped";

  try {
    if ((await readlink(linkPath)) === target) return "skipped";
  } catch {
    // Not a symlink, missing, or unreadable. Replace below.
  }

  if (dryRun) return "linked";

  await mkdir(dirname(linkPath), { recursive: true });
  await rm(linkPath, { recursive: true, force: true });
  await symlink(target, linkPath, "dir");
  return "linked";
}
```

`tools/skill-router/src/sync.ts:66-71` today:

```ts
    for (const skill of skillsForAgent(skills, agent, scopeSet)) {
      const linkPath = join(destRoot, skill.id);
      const outcome = await ensureSymlink(skill.path.replace(/\/SKILL\.md$/, ""), linkPath, dryRun);
      if (outcome === "linked") linked.push(skill.id);
      else skipped.push(skill.id);
    }
```

`tools/skill-router/src/cli.ts:138-141` today:

```ts
      for (const result of results) {
        console.log(`${result.agent}: linked=${result.linked.length} skipped=${result.skipped.length}`);
        if (result.linked.length) console.log(`  linked: ${result.linked.join(", ")}`);
      }
```

Conventions that apply:

- ADR-0007 (`docs/adr/0007-skill-router-effects-cross-injected-seams.md`):
  every test that reaches discovery must inject a `RouterContext` built with
  `resolveContext(defaultRuntime({ run, env, configPath }))`. Tests must not
  mutate `process.env.HOME` and must not spawn a real process. A preload
  guard (`test/support/preload.ts`) fails any test that spawns.
- ADR-0007 also says directory discovery and file writes use the real
  filesystem. The test fixture below therefore uses a real temp directory.
- The user config is **merged over** `config.default.json`, so the default
  agents (`cursor`, `claude`, and others) are always present. Tests must pass
  `agents: ["fixture"]` to `syncAgents` to limit the run to the fixture agent.
- This repo blocks new code comments outside docs work (a `doc-lock` hook).
  Do not add comments. The code below has none.

## Commands you will need

Run from `tools/skill-router/` unless noted.

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `bun test` | exit 0, `12 pass`, `0 fail` after step 3 |
| Typecheck (only if `node_modules/` exists) | `bun run check` | exit 0, no errors |
| Nix gate (repo root, macOS) | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-skill-router'` | exit 0 |
| Nix gate (repo root, Linux) | `nix build --no-link --print-build-logs '.#checks.x86_64-linux.unit-skill-router'` | exit 0 |

`bun test` needs no install. Do not run `bun install` in the repo. If
`node_modules/` is absent, skip the typecheck row.

Nix only sees files that Git tracks. Before the Nix gate, run
`git add tools/skill-router/test/sync.test.ts` (or `jj status` in a jj
workspace, which tracks new files automatically).

## Scope

**In scope** (the only files you may modify):

- `tools/skill-router/src/sync.ts`
- `tools/skill-router/src/cli.ts` (the three lines shown above only)
- `tools/skill-router/test/sync.test.ts` (create)

**Out of scope** (do NOT touch):

- `tools/skill-router/src/discover-local.ts` and `src/frontmatter.ts`. Other
  commands use the skill id as a display name. Validation belongs at the
  point where the id becomes a filesystem path, which is `sync.ts`.
- `tools/skill-router/src/install-agents.ts`. It has a separate known issue
  that is not part of this plan.
- `docs/agents/skill-router.md` and every other Markdown file.
- `tools/skill-router/test/subprocess-gating.test.ts`.

## Git workflow

- Branch: `advisor/001-skill-router-sync-safe-replace`.
- One commit. Message style follows the repo, for example
  `fix(zoxide): Skip the current directory in agent-shell z`. Use:
  `fix(skill-router): Refuse unsafe skill ids and real directories in sync`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Add the failing tests

Create `tools/skill-router/test/sync.test.ts` with exactly this content:

```ts
import { afterEach, expect, test } from "bun:test";
import { lstat, mkdir, mkdtemp, readlink, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { defaultRuntime, resolveContext } from "../src/config.ts";
import { syncAgents } from "../src/sync.ts";
import { makeRecordingRunner } from "./support/doubles.ts";

type Fixture = { root: string; home: string; cwd: string; destRoot: string; configPath: string };

const createdRoots: string[] = [];

afterEach(async () => {
  while (createdRoots.length > 0) {
    const root = createdRoots.pop();
    if (root) await rm(root, { recursive: true, force: true });
  }
});

async function writeRepoSkill(fixture: Fixture, dirName: string, frontmatterName: string): Promise<string> {
  const dir = join(fixture.cwd, "skills", dirName);
  await mkdir(dir, { recursive: true });
  await writeFile(join(dir, "SKILL.md"), `---\nname: ${frontmatterName}\ndescription: Fixture skill\n---\n\n# Fixture\n`);
  return dir;
}

async function makeFixture(): Promise<Fixture> {
  const root = await mkdtemp(join(tmpdir(), "skill-router-sync-"));
  createdRoots.push(root);

  const home = join(root, "home");
  const cwd = join(root, "project");
  const destRoot = join(home, "agent-skills");
  const configDir = join(home, ".config", "skill-router");

  await mkdir(cwd, { recursive: true });
  await mkdir(destRoot, { recursive: true });
  await mkdir(configDir, { recursive: true });
  await writeFile(
    join(configDir, "config.json"),
    JSON.stringify({
      scopes: {
        repo: { precedence: 4, dirs: ["skills"] },
        workspace: { precedence: 3, dirs: [] },
        user: { precedence: 2, dirs: [] },
        package: { precedence: 1, provider: "intent" },
      },
      agents: { fixture: { dir: "${HOME}/agent-skills", mode: "filesystem" } },
      catalog: { maxEntries: 48, maxDescriptionChars: 220, intentRunner: "bunx @tanstack/intent@0.0.41", packageScope: false },
    }),
  );

  return { root, home, cwd, destRoot, configPath: join(configDir, "config.json") };
}

async function ctxOutsideGitRepo(fixture: Fixture) {
  const { runner } = makeRecordingRunner(() => ({ exitCode: 1, stdout: "" }));
  return resolveContext(
    defaultRuntime({
      run: runner,
      env: { HOME: fixture.home },
      configPath: fixture.configPath,
    }),
  );
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await lstat(path);
    return true;
  } catch {
    return false;
  }
}

test("sync links a repo skill into the agent skills dir", async () => {
  const fixture = await makeFixture();
  const skillDir = await writeRepoSkill(fixture, "alpha", "alpha");

  const results = await syncAgents(fixture.cwd, { agents: ["fixture"], ctx: await ctxOutsideGitRepo(fixture) });

  expect(results).toEqual([{ agent: "fixture", linked: ["alpha"], skipped: [], refused: [] }]);
  expect(await readlink(join(fixture.destRoot, "alpha"))).toBe(skillDir);
});

test("sync replaces a stale symlink", async () => {
  const fixture = await makeFixture();
  const skillDir = await writeRepoSkill(fixture, "alpha", "alpha");
  const elsewhere = join(fixture.root, "elsewhere");
  await mkdir(elsewhere, { recursive: true });
  await symlink(elsewhere, join(fixture.destRoot, "alpha"), "dir");

  const results = await syncAgents(fixture.cwd, { agents: ["fixture"], ctx: await ctxOutsideGitRepo(fixture) });

  expect(results[0]?.linked).toEqual(["alpha"]);
  expect(await readlink(join(fixture.destRoot, "alpha"))).toBe(skillDir);
  expect(await pathExists(elsewhere)).toBe(true);
});

test("sync refuses a skill id that escapes the agent skills dir", async () => {
  const fixture = await makeFixture();
  await writeRepoSkill(fixture, "evil", "../../victim");
  const victim = join(fixture.root, "victim");
  await mkdir(victim, { recursive: true });
  await writeFile(join(victim, "keep.txt"), "keep");

  const results = await syncAgents(fixture.cwd, { agents: ["fixture"], ctx: await ctxOutsideGitRepo(fixture) });

  expect(results[0]?.linked).toEqual([]);
  expect(results[0]?.refused).toEqual(["../../victim"]);
  expect((await lstat(victim)).isDirectory()).toBe(true);
  expect(await pathExists(join(victim, "keep.txt"))).toBe(true);
});

test("sync refuses to replace a real directory", async () => {
  const fixture = await makeFixture();
  await writeRepoSkill(fixture, "alpha", "alpha");
  const existing = join(fixture.destRoot, "alpha");
  await mkdir(existing, { recursive: true });
  await writeFile(join(existing, "keep.txt"), "keep");

  const results = await syncAgents(fixture.cwd, { agents: ["fixture"], ctx: await ctxOutsideGitRepo(fixture) });

  expect(results[0]?.linked).toEqual([]);
  expect(results[0]?.refused).toEqual(["alpha"]);
  expect((await lstat(existing)).isSymbolicLink()).toBe(false);
  expect(await pathExists(join(existing, "keep.txt"))).toBe(true);
});

test("sync --dry-run reports the link without creating it", async () => {
  const fixture = await makeFixture();
  await writeRepoSkill(fixture, "alpha", "alpha");

  const results = await syncAgents(fixture.cwd, { agents: ["fixture"], dryRun: true, ctx: await ctxOutsideGitRepo(fixture) });

  expect(results[0]?.linked).toEqual(["alpha"]);
  expect(await pathExists(join(fixture.destRoot, "alpha"))).toBe(false);
});
```

**Verify**: from `tools/skill-router/`, run `bun test`. Expected: `9 pass`,
`3 fail`. The three failing tests must be exactly:

- `sync links a repo skill into the agent skills dir`
- `sync refuses a skill id that escapes the agent skills dir`
- `sync refuses to replace a real directory`

The fixture lives in a temp directory, so the failing run deletes nothing real.

### Step 2: Make `sync.ts` refuse unsafe ids and real directories

Replace the whole content of `tools/skill-router/src/sync.ts` with:

```ts
import { lstat, mkdir, readlink, symlink, unlink } from "node:fs/promises";
import { basename, dirname, join } from "node:path";
import { expandPath, resolveContext } from "./config.ts";
import { discoverSkills } from "./discover.ts";
import type { RouterContext, SkillRecord } from "./types.ts";

type SyncOutcome = "linked" | "skipped" | "refused";

type SyncResult = {
  agent: string;
  linked: string[];
  skipped: string[];
  refused: string[];
};

async function exists(path: string): Promise<boolean> {
  try {
    await lstat(path);
    return true;
  } catch {
    return false;
  }
}

async function isSymlink(path: string): Promise<boolean | null> {
  try {
    return (await lstat(path)).isSymbolicLink();
  } catch {
    return null;
  }
}

function isSafeSkillId(id: string): boolean {
  return id !== "" && id !== "." && id !== ".." && id === basename(id) && !id.includes("\\");
}

async function ensureSymlink(target: string, linkPath: string, dryRun: boolean): Promise<SyncOutcome> {
  if (!(await exists(target))) return "skipped";

  const linkIsSymlink = await isSymlink(linkPath);
  if (linkIsSymlink === false) return "refused";
  if (linkIsSymlink && (await readlink(linkPath)) === target) return "skipped";

  if (dryRun) return "linked";

  await mkdir(dirname(linkPath), { recursive: true });
  if (linkIsSymlink) await unlink(linkPath);
  await symlink(target, linkPath, "dir");
  return "linked";
}

function skillsForAgent(skills: SkillRecord[], agent: string, scopes: Set<string>): SkillRecord[] {
  if (agent === "all") {
    return skills.filter((s) => scopes.has(s.scope) && s.path && !s.intentId);
  }
  return skills.filter((s) => scopes.has(s.scope) && s.path && !s.intentId);
}

export async function syncAgents(
  cwd: string,
  opts: { agents?: string[]; scopes?: string[]; dryRun?: boolean; ctx?: RouterContext },
): Promise<SyncResult[]> {
  const ctx = opts.ctx ?? (await resolveContext());
  const { runtime, config } = ctx;
  const skills = await discoverSkills({ cwd, includePackage: false, ctx });
  const scopeSet = new Set(opts.scopes ?? ["repo", "workspace"]);
  const agentNames = opts.agents ?? Object.keys(config.agents);
  const dryRun = opts.dryRun ?? false;
  const results: SyncResult[] = [];

  for (const agent of agentNames) {
    const agentConfig = config.agents[agent];
    if (!agentConfig || agentConfig.mode !== "filesystem") continue;

    const destRoot = expandPath(agentConfig.dir, runtime.env);
    const linked: string[] = [];
    const skipped: string[] = [];
    const refused: string[] = [];

    for (const skill of skillsForAgent(skills, agent, scopeSet)) {
      if (!isSafeSkillId(skill.id)) {
        refused.push(skill.id);
        continue;
      }
      const linkPath = join(destRoot, skill.id);
      const outcome = await ensureSymlink(skill.path.replace(/\/SKILL\.md$/, ""), linkPath, dryRun);
      if (outcome === "linked") linked.push(skill.id);
      else if (outcome === "refused") refused.push(skill.id);
      else skipped.push(skill.id);
    }

    results.push({ agent, linked, skipped, refused });
  }

  return results;
}
```

What changed, so you can check your edit:

- `rm` is no longer imported or called. `unlink` removes only a symlink.
- A destination that exists and is not a symlink returns `"refused"`.
- An id that is empty, `.`, `..`, or contains a path separator is refused
  before any path is built.
- `SyncResult` gains `refused: string[]`.
- `skillsForAgent` is unchanged.

**Verify**: `bun test` → `12 pass`, `0 fail`.
**Verify**: `grep -n "rm(" tools/skill-router/src/sync.ts` (from repo root) → no output.

### Step 3: Print refused skills in the CLI

In `tools/skill-router/src/cli.ts`, replace the loop shown in "Current state"
(lines 138-141) with:

```ts
      for (const result of results) {
        console.log(
          `${result.agent}: linked=${result.linked.length} skipped=${result.skipped.length} refused=${result.refused.length}`,
        );
        if (result.linked.length) console.log(`  linked: ${result.linked.join(", ")}`);
        if (result.refused.length) console.log(`  refused: ${result.refused.join(", ")}`);
      }
```

**Verify**: `bun test` → `12 pass`, `0 fail`.
**Verify** (only if `node_modules/` exists): `bun run check` → exit 0.

### Step 4: Run the Nix gate

From the repo root, track the new file, then build the check for your platform
(see "Commands you will need").

**Verify**: the `nix build` command exits 0.

## Test plan

- New file `tools/skill-router/test/sync.test.ts`, five tests: happy path,
  stale symlink replaced, id with `..` refused and the outside directory kept,
  real directory kept, dry run.
- The two "refuses" tests are the regression tests for this plan. Step 1
  proves they fail on the old code.
- Structural pattern: `tools/skill-router/test/subprocess-gating.test.ts`.
- Verification: `bun test` → `12 pass`, `0 fail` (7 existing plus 5 new).

## Done criteria

ALL must hold:

- [ ] `bun test` in `tools/skill-router/` exits 0 with `12 pass`, `0 fail`
- [ ] `grep -n "rm(" tools/skill-router/src/sync.ts` returns no matches
- [ ] `grep -c "refused" tools/skill-router/src/cli.ts` returns `2` or more
- [ ] The Nix check `unit-skill-router` builds for the current platform
- [ ] `git status --short` lists only the three in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `sync.ts` or the `cli.ts` loop does not match the "Current state" excerpts.
- Step 1 shows a different set of failing tests than the three listed.
- `bun test` reports a count other than `12 pass` after step 2, and one
  reasonable fix attempt does not resolve it.
- A hook blocks an edit because it sees an added comment. Remove the comment.
  If the block persists, stop.
- You find another caller of `syncAgents` besides `src/cli.ts`.
  At planning time there was none.

## Maintenance notes

- Behavior change to review: sync used to replace a real directory with a
  link. It now leaves the directory and reports the id as refused. A user who
  wants the link must remove the directory by hand.
- If skill ids ever need a namespace separator such as `/`, `isSafeSkillId`
  must change together with a check that the resolved path stays under the
  agent skills directory.
- Deferred: `docs/agents/skill-router.md` does not mention refusals. Add one
  sentence in a docs change.
- Deferred: `src/install-agents.ts` replaces its marker block with a greedy
  pattern and a non-atomic write. That is a separate finding.
