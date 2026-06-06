// Activates the Command-seam guard for the whole `bun test` run: if any test
// reaches bunCommandRunner (a real subprocess — including a network `bunx
// @tanstack/intent` call) instead of injecting a CommandRunner, it fails loud
// and offline here. See src/command-runner.ts.
process.env.SKILL_ROUTER_NO_REAL_SPAWN = "1";
