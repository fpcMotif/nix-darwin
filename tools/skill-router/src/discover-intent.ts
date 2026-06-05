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
  runner: string,
  precedence: number,
  global = false,
): Promise<SkillRecord[]> {
  const args = runner.split(" ").concat(["list", "--json"]);
  if (global) args.push("--global");

  const proc = Bun.spawn(args, { cwd, stdout: "pipe", stderr: "pipe" });
  const code = await proc.exited;
  if (code !== 0) return [];

  const text = await new Response(proc.stdout).text();
  let parsed: IntentListJson;
  try {
    parsed = JSON.parse(text) as IntentListJson;
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
  runner: string,
  intentId: string,
): Promise<{ content: string; path: string } | null> {
  const args = runner.split(" ").concat(["load", intentId, "--path"]);
  const proc = Bun.spawn(args, { cwd, stdout: "pipe", stderr: "pipe" });
  const code = await proc.exited;
  if (code !== 0) return null;

  const path = (await new Response(proc.stdout).text()).trim();
  if (!path) return null;

  const file = Bun.file(path);
  if (!(await file.exists())) return null;

  return { path, content: await file.text() };
}
