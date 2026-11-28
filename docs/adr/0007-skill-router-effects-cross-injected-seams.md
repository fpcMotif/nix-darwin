# Skill-router subprocess and file-read effects cross injected seams

Status: accepted

`skill-router` previously called `Bun.spawn` and `Bun.file` directly inside leaf modules. Tests had to write temporary shell scripts to disk and mutate `process.env.HOME`. We moved process spawning (`git rev-parse --show-toplevel` for workspace discovery) and file reads (`config.json` and `SKILL.md`) behind an injected **Router runtime** (`RouterRuntime` with `CommandRunner` and `ReadText` seams). The CLI entry point resolves config once into a **Router context** (`RouterContext = { runtime, config }`). A `bunfig.toml` test preload (`SKILL_ROUTER_NO_REAL_SPAWN=1`) throws if any test reaches the production spawner.

## Considered options

- **Thread `RouterRuntime` everywhere but let leaf modules call `loadConfig` themselves.** Rejected: `catalog` and `install` commands parsed `config.json` twice per run, and leaf modules still read ambient env.
- **Virtualize all filesystem operations (directory walks and symlinks).** Rejected: directory discovery and `sync` symlinks need real filesystem semantics; scoping `ReadText` to file contents keeps the seam small.
- **Plain module default with no test preload guard.** Rejected: an un-injected test could spawn a real `git` subprocess against the outer working tree instead of failing hermetically.
- **One `CommandRunner` seam + one `ReadText` seam in `RouterContext` with a test preload guard (chosen).** Cuts test runtime from ~970ms to ~20ms in memory and runs offline inside `nix flake check`.

## Consequences and trade-offs

- Every internal `skill-router` command function accepts `ctx: RouterContext` instead of reading globals, which adds one parameter across call chains.
- Directory discovery still walks the real filesystem, so discovery tests use a small temp directory while file-content reads stay injectable.
- **Reversal trigger:** If `skill-router` adds commands that mutate large directory trees slowly on disk, widen the seam to directory listings.
