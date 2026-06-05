#!/usr/bin/env bun
import { buildCatalog } from "./catalog.ts";
import { discoverSkills, resolveSkill, toLogicalId } from "./discover.ts";
import { loadSkill, loadSkillPathOnly } from "./load.ts";
import { defaultAgentsPath, installAgentsMd } from "./install-agents.ts";
import { syncAgents } from "./sync.ts";

const USAGE = `skill-router - unified agent skill discovery and loading

Usage:
  skill-router discover [--json] [--cwd <path>] [--package | --no-package]
  skill-router catalog [--map] [--format compact|agents|intent|all] [--package | --no-package] [--cwd <path>]
  skill-router load <id> [--path] [--cwd <path>]
  skill-router sync [--agent <name>] [--scope repo,workspace] [--dry-run] [--cwd <path>]
  skill-router install-agents [--map] [--dry-run] [--target <AGENTS.md>] [--cwd <path>]

Identity formats:
  user:diagnose          local scope skill
  repo:jj                repository skill (highest precedence)
  @tanstack/query#core   package skill via TanStack Intent

Precedence: repo > workspace > user > package

Package scope (TanStack Intent) is opt-in and dormant by default. Pass
--package to discover or catalog installed intent-enabled npm packages via
the pinned \`bunx @tanstack/intent\` runner, or load a package skill directly
with \`skill-router load @pkg#skill\`.
`;

function parseArgs(argv: string[]) {
  const args = [...argv];
  const flags: Record<string, string | boolean> = {};
  const positionals: string[] = [];

  while (args.length > 0) {
    const arg = args.shift()!;
    if (arg === "--json") flags.json = true;
    else if (arg === "--map") flags.map = true;
    else if (arg === "--dry-run") flags.dryRun = true;
    else if (arg === "--no-package") flags.noPackage = true;
    else if (arg === "--package") flags.package = true;
    else if (arg === "--path") flags.path = true;
    else if (arg === "--cwd") flags.cwd = args.shift() ?? process.cwd();
    else if (arg === "--format") flags.format = args.shift() ?? "all";
    else if (arg === "--agent") flags.agent = args.shift() ?? "all";
    else if (arg === "--scope") flags.scope = args.shift() ?? "repo,workspace";
    else if (arg === "--target") flags.target = args.shift() ?? "";
    else if (arg.startsWith("-")) throw new Error(`Unknown flag: ${arg}`);
    else positionals.push(arg);
  }

  return {
    cmd: positionals[0] ?? "help",
    rest: positionals.slice(1),
    flags,
  };
}

async function main() {
  const { cmd, rest, flags } = parseArgs(process.argv.slice(2));
  const cwd = (flags.cwd as string | undefined) ?? process.cwd();

  switch (cmd) {
    case "discover": {
      const skills = await discoverSkills({
        cwd,
        // Opt-in: --package forces the TanStack Intent scope on, --no-package
        // forces it off, neither defers to config.catalog.packageScope (false).
        includePackage: flags.package === true ? true : flags.noPackage === true ? false : undefined,
      });
      if (flags.json) {
        console.log(JSON.stringify(skills.map((s) => ({ ...s, logical: toLogicalId(s) })), null, 2));
      } else {
        for (const skill of skills) {
          const logical = toLogicalId(skill);
          const lines = skill.lines ? ` (${skill.lines} lines)` : "";
          console.log(`${logical.padEnd(36)} [${skill.scope}]${lines}`);
          if (skill.description) console.log(`  ${skill.description.slice(0, 120)}`);
        }
        console.log(`\n${skills.length} skills`);
      }
      break;
    }

    case "catalog": {
      const { text, skills } = await buildCatalog(cwd, {
        map: !!flags.map,
        format: (flags.format as "compact" | "agents" | "intent" | "all" | undefined) ?? "all",
        includePackage: flags.package === true ? true : flags.noPackage === true ? false : undefined,
      });
      console.log(text);
      if (!flags.json) {
        console.error(`\n# ${skills.length} routable skills`);
      }
      break;
    }

    case "load": {
      const query = rest[0];
      if (!query) throw new Error("load requires a skill id");

      if (flags.path) {
        const path = await loadSkillPathOnly(cwd, query);
        if (!path) {
          console.error(`skill not found: ${query}`);
          process.exit(1);
        }
        console.log(path);
        break;
      }

      const loaded = await loadSkill(cwd, query);
      if (!loaded) {
        console.error(`skill not found: ${query}`);
        process.exit(1);
      }
      console.log(loaded.content);
      break;
    }

    case "sync": {
      const agentFlag = flags.agent as string | undefined;
      const scopeFlag = flags.scope as string | undefined;
      const agents = agentFlag?.split(",").filter(Boolean);
      const scopes = scopeFlag?.split(",").filter(Boolean);
      const results = await syncAgents(cwd, {
        agents,
        scopes,
        dryRun: !!flags.dryRun,
      });
      for (const result of results) {
        console.log(`${result.agent}: linked=${result.linked.length} skipped=${result.skipped.length}`);
        if (result.linked.length) console.log(`  linked: ${result.linked.join(", ")}`);
      }
      break;
    }

    case "install-agents": {
      const target = (flags.target as string) || defaultAgentsPath(cwd);
      const result = await installAgentsMd(cwd, target, {
        map: !!flags.map,
        dryRun: !!flags.dryRun,
      });
      if (flags.dryRun) {
        console.log(result.text);
      } else {
        console.log(`updated ${result.path}`);
      }
      break;
    }

    case "help":
    default:
      console.log(USAGE);
      if (cmd !== "help") process.exit(1);
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
