import { bunCommandRunner, type CommandRunner } from "./command-runner.ts";
import { bunReadText, type ReadText } from "./file-reader.ts";
import type { SkillRecord } from "./types.ts";

type IntentListJson = {
  skills: Array<{
    use: string;
    package: string;
    name: string;
    description?: string;
    path?: string;
  }>;
};

export async function discoverIntentSkills(
  cwd: string,
  runnerCmd: string,
  precedence: number,
  global = false,
  run: CommandRunner = bunCommandRunner,
): Promise<SkillRecord[]> {
  const args = runnerCmd.split(" ").concat(["list", "--json"]);
  if (global) args.push("--global");

  const { exitCode, stdout } = await run(args, { cwd });
  if (exitCode !== 0) return [];

  let parsed: IntentListJson;
  try {
    parsed = JSON.parse(stdout) as IntentListJson;
  } catch {
    return [];
  }

  return (parsed.skills ?? []).map((skill) => ({
    id: skill.name,
    scope: "package" as const,
    description: skill.description ?? "",
    path: skill.path ?? "",
    intentId: skill.use,
    package: skill.package,
    precedence,
  }));
}

export async function loadIntentSkill(
  cwd: string,
  runnerCmd: string,
  intentId: string,
  run: CommandRunner = bunCommandRunner,
  read: ReadText = bunReadText,
): Promise<{ content: string; path: string } | null> {
  const args = runnerCmd.split(" ").concat(["load", intentId, "--path"]);
  const { exitCode, stdout } = await run(args, { cwd });
  if (exitCode !== 0) return null;

  const path = stdout.trim();
  if (!path) return null;

  const content = await read(path);
  if (content === null) return null;

  return { path, content };
}
