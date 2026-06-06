import type { CommandRunner } from "../../src/command-runner.ts";

export type RunnerResponse = { exitCode: number; stdout: string };

// Test adapter for the Command seam: records the full argv (the pinned binary
// included) before returning a scripted response, so a spawn is assertable at
// the interface — no on-disk runner script, no log file. The Skill-read seam's
// test adapter is built inline in ctxFor, which needs a real-file fallback so it
// can serve config from disk and package bodies from memory.
export function makeRecordingRunner(
  respond: (argv: string[]) => RunnerResponse,
): { runner: CommandRunner; calls: string[][] } {
  const calls: string[][] = [];
  const runner: CommandRunner = async (argv) => {
    calls.push(argv);
    return respond(argv);
  };
  return { runner, calls };
}
