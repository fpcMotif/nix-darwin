import { afterEach, expect, test } from "bun:test";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildCatalog, renderCompactBlock } from "../src/catalog.ts";
import { bunCommandRunner } from "../src/command-runner.ts";
import { defaultRuntime, resolveContext } from "../src/config.ts";
import { installAgentsMd } from "../src/install-agents.ts";
import { loadSkill } from "../src/load.ts";
import { makeRecordingRunner, type RunnerResponse } from "./support/doubles.ts";

type Fixture = { root: string; home: string; gitRoot: string; cwd: string; configPath: string };

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

async function makeFixture(options: { repoShadow?: boolean; workspaceSkill?: boolean } = {}): Promise<Fixture> {
  const root = await mkdtemp(join(tmpdir(), "skill-router-"));
  createdRoots.push(root);

  const home = join(root, "home");
  const gitRoot = join(root, "monorepo");
  const cwd = join(gitRoot, "packages", "app");
  const userSkillDir = join(home, ".codex", "skills", "diagnose");
  const workspaceSkillDir = join(gitRoot, ".agents", "skills", "diagnose");
  const repoSkillDir = join(cwd, "skills", "diagnose");
  const configDir = join(home, ".config", "skill-router");

  await mkdir(cwd, { recursive: true });
  await writeSkill(userSkillDir, "diagnose", "User diagnosis", "# User diagnosis");
  if (options.workspaceSkill) {
    await writeSkill(workspaceSkillDir, "diagnose", "Workspace diagnosis", "# Workspace diagnosis");
  }
  if (options.repoShadow) {
    await writeSkill(repoSkillDir, "diagnose", "Repo diagnosis", "# Repo diagnosis");
  }

  await mkdir(configDir, { recursive: true });
  await writeFile(
    join(configDir, "config.json"),
    JSON.stringify(
      {
        scopes: {
          repo: { precedence: 3, dirs: ["skills"] },
          workspace: { precedence: 2, dirs: [".agents/skills"] },
          user: { precedence: 1, dirs: ["${HOME}/.codex/skills"] },
        },
        agents: {},
        catalog: {
          maxEntries: 48,
          maxDescriptionChars: 220,
        },
      },
      null,
      2,
    ),
  );

  return { root, home, gitRoot, cwd, configPath: join(configDir, "config.json") };
}

async function withFixture(
  options: { repoShadow?: boolean; workspaceSkill?: boolean },
  fn: (fixture: Fixture) => Promise<void>,
): Promise<void> {
  const fixture = await makeFixture(options);
  await fn(fixture);
}

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

test("preload guard blocks un-injected bunCommandRunner calls under bun test", async () => {
  await expect(bunCommandRunner(["git", "rev-parse", "--show-toplevel"])).rejects.toThrow(
    "bunCommandRunner refused under test",
  );
});

test("compact instructions list only local repo > workspace > user scopes", () => {
  const text = renderCompactBlock(false);

  expect(text).toContain("<!-- skill-router:compact:start -->");
  expect(text).toContain("Scope order: repo > workspace > user.");
  expect(text).not.toContain("intent");
  expect(text).not.toContain("package");
});

test("workspace discovery queries git root through the Command seam", async () => {
  await withFixture({ workspaceSkill: true }, async (fixture) => {
    const { runner, calls } = makeRecordingRunner(() => ({
      exitCode: 0,
      stdout: `${fixture.gitRoot}\n`,
    }));
    const cat = await buildCatalog(fixture.cwd, { format: "all", ctx: await ctxFor(fixture, runner) });

    expect(calls).toEqual([["git", "-C", fixture.cwd, "rev-parse", "--show-toplevel"]]);
    expect(cat.skills.map((skill) => `${skill.scope}:${skill.id}`)).toEqual(["workspace:diagnose"]);
  });
});

test("scoped IDs bypass repo shadowing and load through the Skill-read seam", async () => {
  await withFixture({ repoShadow: true }, async (fixture) => {
    const { runner } = makeRecordingRunner(() => ({ exitCode: 1, stdout: "" }));
    const ctx = await ctxFor(fixture, runner);
    const unscoped = await loadSkill(fixture.cwd, "diagnose", ctx);
    const scoped = await loadSkill(fixture.cwd, "user:diagnose", ctx);

    expect(unscoped?.content).toContain("# Repo diagnosis");
    expect(unscoped?.source).toBe("repo:diagnose");
    expect(scoped?.content).toContain("# User diagnosis");
    expect(scoped?.source).toBe("user:diagnose");
  });
});

test("missing git binary or non-repo cwd degrades to repo and user scopes without throwing", async () => {
  await withFixture({ workspaceSkill: true }, async (fixture) => {
    const { runner } = makeRecordingRunner((): RunnerResponse => ({ exitCode: 127, stdout: "" }));
    const ctx = await ctxFor(fixture, runner);
    const cat = await buildCatalog(fixture.cwd, { format: "agents", ctx });

    expect(cat.skills.map((skill) => `${skill.scope}:${skill.id}`)).toEqual(["user:diagnose"]);
  });
});

test("install-agents writes compact block and removes legacy available_skills and intent-skills blocks", async () => {
  await withFixture({}, async (fixture) => {
    const target = join(fixture.cwd, "AGENTS.md");
    await writeFile(
      target,
      `# AGENTS.md

<!-- intent-skills:start -->
legacy intent block
<!-- intent-skills:end -->

<available_skills>
  <skill>
    <name>legacy</name>
  </skill>
</available_skills>
`,
    );

    const { runner } = makeRecordingRunner(() => ({ exitCode: 1, stdout: "" }));
    const result = await installAgentsMd(fixture.cwd, target, {
      dryRun: true,
      ctx: await ctxFor(fixture, runner),
    });

    expect(result.text).toContain("<!-- skill-router:compact:start -->");
    expect(result.text).not.toContain("<!-- intent-skills:start -->");
    expect(result.text).not.toContain("<available_skills>");
  });
});
