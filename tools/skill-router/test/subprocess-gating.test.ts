import { afterEach, expect, test } from "bun:test";
import { chmod, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildCatalog, renderIntentBlock } from "../src/catalog.ts";
import { installAgentsMd } from "../src/install-agents.ts";
import { loadSkill } from "../src/load.ts";

type Fixture = {
  root: string;
  home: string;
  cwd: string;
  runner: string;
  spawnLog: string;
  packageSkillPath: string;
};

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

function shQuote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

async function makeFixture(options: { packageScope?: boolean; repoShadow?: boolean } = {}): Promise<Fixture> {
  const root = await mkdtemp(join(tmpdir(), "skill-router-"));
  createdRoots.push(root);

  const home = join(root, "home");
  const cwd = join(root, "project");
  const userSkillDir = join(home, ".codex", "skills", "diagnose");
  const repoSkillDir = join(cwd, "skills", "diagnose");
  const configDir = join(home, ".config", "skill-router");
  const packageSkillPath = join(root, "package-skill.md");
  const spawnLog = join(root, "intent.log");
  const runner = join(root, "intent-runner");

  await mkdir(cwd, { recursive: true });
  await writeSkill(userSkillDir, "diagnose", "User diagnosis", "# User diagnosis");
  if (options.repoShadow) {
    await writeSkill(repoSkillDir, "diagnose", "Repo diagnosis", "# Repo diagnosis");
  }
  await writeFile(packageSkillPath, "# Package skill\n");
  await writeFile(
    runner,
    `#!/bin/sh
INTENT_LOG=${shQuote(spawnLog)}
INTENT_SKILL_PATH=${shQuote(packageSkillPath)}
printf '%s\\n' "$*" >> "$INTENT_LOG"
if [ "$1" = "list" ]; then
  printf '{"skills":[{"use":"@pkg#skill","package":"@pkg","name":"skill","description":"Package skill","path":"%s"}]}\\n' "$INTENT_SKILL_PATH"
  exit 0
fi
if [ "$1" = "load" ]; then
  printf '%s\\n' "$INTENT_SKILL_PATH"
  exit 0
fi
exit 1
`,
  );
  await chmod(runner, 0o755);

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
          intentRunner: runner,
          packageScope: options.packageScope ?? false,
        },
      },
      null,
      2,
    ),
  );

  return { root, home, cwd, runner, spawnLog, packageSkillPath };
}

async function writeUserConfig(fixture: Fixture, catalog: Record<string, unknown>): Promise<void> {
  await writeFile(
    join(fixture.home, ".config", "skill-router", "config.json"),
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
          ...catalog,
        },
      },
      null,
      2,
    ),
  );
}

async function withFixture(
  options: { packageScope?: boolean; repoShadow?: boolean },
  fn: (fixture: Fixture) => Promise<void>,
): Promise<void> {
  const fixture = await makeFixture(options);
  const previousHome = process.env.HOME;

  process.env.HOME = fixture.home;

  try {
    await fn(fixture);
  } finally {
    if (previousHome === undefined) delete process.env.HOME;
    else process.env.HOME = previousHome;
  }
}

async function spawnLog(path: string): Promise<string> {
  const file = Bun.file(path);
  return await file.exists() ? file.text() : "";
}

test("rendered Intent instructions use the pinned runner, not @latest", () => {
  const text = renderIntentBlock(false, "bunx @tanstack/intent@0.0.41");

  expect(text).toContain("bunx @tanstack/intent@0.0.41 list|load @pkg#name");
  expect(text).not.toContain("@latest");
});

test("catalog is local-only unless package scope is explicitly requested", async () => {
  await withFixture({}, async (fixture) => {
    const local = await buildCatalog(fixture.cwd, { format: "all" });

    expect(local.skills.map((skill) => `${skill.scope}:${skill.id}`)).toEqual(["user:diagnose"]);
    expect(local.text).toContain(`${fixture.runner} list|load @pkg#name`);
    expect(await spawnLog(fixture.spawnLog)).toBe("");

    const withPackage = await buildCatalog(fixture.cwd, { format: "agents", includePackage: true });

    expect(withPackage.skills.some((skill) => skill.intentId === "@pkg#skill")).toBe(true);
    expect(await spawnLog(fixture.spawnLog)).toContain("list --json");
  });
});

test("stale @latest user config falls back to the bundled pinned runner", async () => {
  await withFixture({}, async (fixture) => {
    await writeUserConfig(fixture, { intentRunner: "bunx @tanstack/intent@latest", packageScope: false });

    const local = await buildCatalog(fixture.cwd, { format: "compact" });

    expect(local.text).toContain("bunx @tanstack/intent@0.0.41 list|load @pkg#name");
    expect(local.text).not.toContain("@latest");
    expect(await spawnLog(fixture.spawnLog)).toBe("");
  });
});

test("local loads do not spawn Intent and scoped IDs bypass shadowing", async () => {
  await withFixture({ repoShadow: true }, async (fixture) => {
    const unscoped = await loadSkill(fixture.cwd, "diagnose");
    const scoped = await loadSkill(fixture.cwd, "user:diagnose");

    expect(unscoped?.content).toContain("# Repo diagnosis");
    expect(unscoped?.source).toBe("repo:diagnose");
    expect(scoped?.content).toContain("# User diagnosis");
    expect(scoped?.source).toBe("user:diagnose");
    expect(await spawnLog(fixture.spawnLog)).toBe("");
  });
});

test("package loads spawn Intent only for package IDs", async () => {
  await withFixture({}, async (fixture) => {
    const loaded = await loadSkill(fixture.cwd, "@pkg#skill");

    expect(loaded?.content).toContain("# Package skill");
    expect(loaded?.source).toBe("intent");
    expect(await spawnLog(fixture.spawnLog)).toContain("load @pkg#skill --path");
  });
});

test("install-agents stays local-only and removes legacy available_skills blocks", async () => {
  await withFixture({ packageScope: true }, async (fixture) => {
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

    const result = await installAgentsMd(fixture.cwd, target, { dryRun: true });

    expect(result.text).toContain("<!-- intent-skills:start -->");
    expect(result.text).not.toContain("<available_skills>");
    expect(await spawnLog(fixture.spawnLog)).toBe("");
  });
});
