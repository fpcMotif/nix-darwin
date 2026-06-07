import { bunCommandRunner, type CommandRunner } from "./command-runner.ts";

export async function findGitRoot(start: string, run: CommandRunner = bunCommandRunner): Promise<string | null> {
  const { exitCode, stdout } = await run(["git", "-C", start, "rev-parse", "--show-toplevel"]);
  if (exitCode !== 0) return null;
  return stdout.trim() || null;
}
