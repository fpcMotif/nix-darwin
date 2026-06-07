// The Command seam: the one process-spawn capability every external-process
// call in skill-router flows through (the dormant-by-default intentRunner and
// `git rev-parse`). The seam expresses only HOW a process launches, never WHEN
// — the includePackage gate and the @0.0.41 pin stay above it in the callers.
// See docs/adr/0006 and CONTEXT.md "Command seam".
export type CommandRunner = (
  argv: string[],
  opts?: { cwd?: string },
) => Promise<{ exitCode: number; stdout: string }>;

// Production adapter. Offline / ENOENT / spawn failure collapses to a non-zero
// exit with empty stdout, so callers' `exitCode !== 0` graceful-empty paths fire
// without try/catch — a testable strengthening of ADR-0006's "never throws".
//
// Under `bun test` the preload sets SKILL_ROUTER_NO_REAL_SPAWN, so a forgotten
// injection fails loud and offline here instead of spawning the pinned runner
// over the network. Tests inject a recording CommandRunner instead.
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
