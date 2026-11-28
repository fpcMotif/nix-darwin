// Activates the Command-seam guard for `bun test`: if any test reaches
// bunCommandRunner instead of injecting a CommandRunner, it fails offline
// instead of spawning a real subprocess (see src/command-runner.ts).
process.env.SKILL_ROUTER_NO_REAL_SPAWN = "1";
