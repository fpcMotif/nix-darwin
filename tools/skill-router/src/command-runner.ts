// The Command seam: every external process call in skill-router (`git rev-parse`
// for workspace root detection) flows through this capability (ADR-0007).
export type CommandRunner = (
  argv: string[],
  opts?: { cwd?: string },
) => Promise<{ exitCode: number; stdout: string }>;

// Offline, ENOENT, and spawn failures collapse to a non-zero exit with empty
// stdout so callers need no try/catch. Under `bun test`,
// SKILL_ROUTER_NO_REAL_SPAWN fails any un-injected call offline.
export const bunCommandRunner: CommandRunner = async (argv, opts) => {
  if (process.env.SKILL_ROUTER_NO_REAL_SPAWN) {
    throw new Error(
      `bunCommandRunner refused under test: inject a CommandRunner instead of spawning \`${argv.join(" ")}\``,
    );
  }
  try {
    const proc = Bun.spawn(argv, { cwd: opts?.cwd, stdout: "pipe", stderr: "ignore" });
    const exitCode = await proc.exited;
    const stdout = await new Response(proc.stdout).text();
    return { exitCode, stdout };
  } catch {
    return { exitCode: 127, stdout: "" };
  }
};
