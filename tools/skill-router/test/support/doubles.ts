import type { CommandRunner } from "../../src/command-runner.ts";

export type RunnerResponse = { exitCode: number; stdout: string };

// Test adapter for the Command seam: records the full argv before returning a
// scripted response, so spawns are assertable at the interface with no on-disk
// runner script or log file.
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
