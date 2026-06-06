import { afterEach, expect, test } from "bun:test";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildCatalog, renderIntentBlock } from "../src/catalog.ts";
import { defaultRuntime, resolveContext } from "../src/config.ts";
import { installAgentsMd } from "../src/install-agents.ts";
import { loadSkill } from "../src/load.ts";
import { makeRecordingRunner, type RunnerResponse } from "./support/doubles.ts";

const PINNED = "bunx @tanstack/intent@0.0.41";
// A path the intent `load` subprocess "returns"; the Skill-read seam serves its
// body from memory, so no temp skill file is staged on disk.
const PACKAGE_SKILL_PATH = "/virtual/package-skill.md";
const PACKAGE_LIST_JSON = JSON.stringify({
  skills: [{ use: "@pkg#skill", package: "@pkg", name: "skill", description: "Package skill", path: PACKAGE_SKILL_PATH }],
});

// Default Command-seam responder: the project cwd is not a git repo (git
// rev-parse fails -> workspace scope skipped), the pinned runner lists one
// package skill, and `load` returns the virtual path.
function respond(argv: string[]): RunnerResponse {
  if (argv[0] === "git") return { exitCode: 1, stdout: "" };
  if (argv.includes("list")) return { exitCode: 0, stdout: PACKAGE_LIST_JSON };
  if (argv.includes("load")) return { exitCode: 0, stdout: PACKAGE_SKILL_PATH };
  return { exitCode: 1, stdout: "" };
}

const intentSpawned = (calls: string[][]): boolean => calls.some((a) => a.includes("list") || a.includes("load"));

type Fixture = { root: string; home: string; cwd: string; configPath: string };

const createdRoots: string[] = [];

afterEach(async () => {
  while (createdRoots.length > 0) {
    const root = createdRoots.pop();
    if (root) await rm(root, { recursive: true, force: true });
  }
});

async function writeSkill(dir: string, name: string, description: string, body: string): Promise<void> {
  await mkdir(dir, { recursive: true });
  await writeFile(
    join(dir, "SKILL.md"),
    `---
name: ${name}
description: ${description}
---

${body}
`,
  );
}

async function makeFixture(options: { repoShadow?: boolean; catalog?: Record<string, unknown> } = {}): Promise<Fixture> {
  const root = await mkdtemp(join(tmpdir(), "skill-router-"));
  createdRoots.push(root);

  const home = join(root, "home");
  const cwd = join(root, "project");
  const userSkillDir = join(home, ".codex", "skills", "diagnose");
  const repoSkillDir = join(cwd, "skills", "diagnose");
  const configDir = join(home, ".config", "skill-router");

  await mkdir(cwd, { recursive: true });
  await writeSkill(userSkillDir, "diagnose", "User diagnosis", "# User diagnosis");
  if (options.repoShadow) {
    await writeSkill(repoSkillDir, "diagnose", "Repo diagnosis", "# Repo diagnosis");
  }

  await mkdir(configDir, { recursive: true });
  await writeFile(
    join(configDir, "config.json"),
    JSON.stringify(
      {
        scopes: {
          repo: { precedence: 4, dirs: ["skills"] },
          workspace: { precedence: 3, dirs: [] },
          user: { precedence: 2, dirs: ["${HOME}/.codex/skills"] },
          package: { precedence: 1, provider: "intent" },
        },
        agents: {},
        catalog: {
          maxEntries: 48,
          maxDescriptionChars: 220,
          intentRunner: PINNED,
          packageScope: false,
          ...options.catalog,
        },
      },
      null,
      2,
    ),
  );

  return { root, home, cwd, configPath: join(configDir, "config.json") };
}

async function withFixture(
  options: { repoShadow?: boolean; catalog?: Record<string, unknown> },
  fn: (fixture: Fixture) => Promise<void>,
): Promise<void> {
  const fixture = await makeFixture(options);
  await fn(fixture);
}

// Resolve a RouterContext from the fixture: HOME and config path are DATA on the
// runtime (no process.env mutation), config is read once via resolveContext, and
// the reader serves package bodies from memory with a real-file fallback.
async function ctxFor(
  fixture: Fixture,
  runner: ReturnType<typeof makeRecordingRunner>["runner"],
  memory: Record<string, string> = {},
) {
  return resolveContext(
    defaultRuntime({
      run: runner,
      env: { HOME: fixture.home },
      configPath: fixture.configPath,
      readText: async (path) => {
        if (Object.prototype.hasOwnProperty.call(memory, path)) return memory[path];
        const file = Bun.file(path);
        if (!(await file.exists())) return null;
        return file.text();
      },
    }),
  );
}

test("rendered Intent instructions use the pinned runner, not @latest", () => {
  const text = renderIntentBlock(false, PINNED);

  expect(text).toContain("bunx @tanstack/intent@0.0.41 list|load @pkg#name");
  expect(text).not.toContain("@latest");
});

test("catalog is local-only unless package scope is explicitly requested", async () => {
  await withFixture({}, async (fixture) => {
    const { runner, calls } = makeRecordingRunner(respond);
    const local = await buildCatalog(fixture.cwd, { format: "all", ctx: await ctxFor(fixture, runner) });

    expect(local.skills.map((skill) => `${skill.scope}:${skill.id}`)).toEqual(["user:diagnose"]);
    expect(local.text).toContain(`${PINNED} list|load @pkg#name`);
    expect(intentSpawned(calls)).toBe(false);

    const { runner: pkgRunner, calls: pkgCalls } = makeRecordingRunner(respond);
    const withPackage = await buildCatalog(fixture.cwd, {
      format: "agents",
      includePackage: true,
      ctx: await ctxFor(fixture, pkgRunner),
    });

    expect(withPackage.skills.some((skill) => skill.intentId === "@pkg#skill")).toBe(true);
    // The pinned binary is asserted at the interface — the ADR-0006 question.
    expect(pkgCalls).toContainEqual(["bunx", "@tanstack/intent@0.0.41", "list", "--json"]);
  });
});

test("stale @latest user config falls back to the bundled pinned runner", async () => {
  await withFixture({ catalog: { intentRunner: "bunx @tanstack/intent@latest" } }, async (fixture) => {
    const { runner, calls } = makeRecordingRunner(respond);
    const local = await buildCatalog(fixture.cwd, { format: "compact", ctx: await ctxFor(fixture, runner) });

    expect(local.text).toContain("bunx @tanstack/intent@0.0.41 list|load @pkg#name");
    expect(local.text).not.toContain("@latest");
    expect(intentSpawned(calls)).toBe(false);
  });
});

test("local loads do not spawn Intent and scoped IDs bypass shadowing", async () => {
  await withFixture({ repoShadow: true }, async (fixture) => {
    const { runner, calls } = makeRecordingRunner(respond);
    const ctx = await ctxFor(fixture, runner);
    const unscoped = await loadSkill(fixture.cwd, "diagnose", ctx);
    const scoped = await loadSkill(fixture.cwd, "user:diagnose", ctx);

    expect(unscoped?.content).toContain("# Repo diagnosis");
    expect(unscoped?.source).toBe("repo:diagnose");
    expect(scoped?.content).toContain("# User diagnosis");
    expect(scoped?.source).toBe("user:diagnose");
    expect(intentSpawned(calls)).toBe(false);
  });
});

test("package loads spawn the pinned runner and read the body in-memory", async () => {
  await withFixture({}, async (fixture) => {
    const { runner, calls } = makeRecordingRunner(respond);
    const loaded = await loadSkill(
      fixture.cwd,
      "@pkg#skill",
      await ctxFor(fixture, runner, { [PACKAGE_SKILL_PATH]: "# Package skill\n" }),
    );

    expect(loaded?.content).toContain("# Package skill");
    expect(loaded?.source).toBe("intent");
    expect(calls.at(-1)).toEqual(["bunx", "@tanstack/intent@0.0.41", "load", "@pkg#skill", "--path"]);
  });
});

test("offline or missing runner degrades to graceful empty, never throws", async () => {
  await withFixture({}, async (fixture) => {
    const offline = (argv: string[]): RunnerResponse =>
      argv[0] === "git" ? { exitCode: 1, stdout: "" } : { exitCode: 127, stdout: "" };
    const { runner } = makeRecordingRunner(offline);

    const ctx = await ctxFor(fixture, runner);
    const cat = await buildCatalog(fixture.cwd, { format: "agents", includePackage: true, ctx });
    expect(cat.skills.some((skill) => skill.scope === "package")).toBe(false);

    const loaded = await loadSkill(fixture.cwd, "@pkg#skill", ctx);
    expect(loaded).toBeNull();
  });
});

test("install-agents stays local-only and removes legacy available_skills blocks", async () => {
  await withFixture({ catalog: { packageScope: true } }, async (fixture) => {
    const target = join(fixture.cwd, "AGENTS.md");
    await writeFile(
      target,
      `# AGENTS.md

<available_skills>
  <skill>
    <name>legacy</name>
  </skill>
</available_skills>
`,
    );

    const { runner, calls } = makeRecordingRunner(respond);
    const result = await installAgentsMd(fixture.cwd, target, {
      dryRun: true,
      ctx: await ctxFor(fixture, runner),
    });

    expect(result.text).toContain("<!-- intent-skills:start -->");
    expect(result.text).not.toContain("<available_skills>");
    // install-agents ignores packageScope:true — never reaches the intent runner.
    expect(intentSpawned(calls)).toBe(false);
  });
});
