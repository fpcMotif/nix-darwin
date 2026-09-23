# Search routing examples (nix-config, 2026-09-09)

Dated traces of the routes in `~/.claude/search-routing.md`, recorded on nix-config. They show each tool's output shape on that date. The routing rules live in `search-routing.md` and win on any conflict.

## A symbol: codedb_explain for structural context

`codedb_explain name=resolveContext project=/Users/martinfan/nix-config`, one call:

```
## definition
tools/skill-router/src/config.ts:53 (function) resolveContext
   53 | export async function resolveContext(runtime: RouterRuntime = defaultRuntime()): Promise<RouterContext> {
   54 |   return { runtime, config: await loadConfig(runtime) };
   55 | }
## callers
6 call sites for 'resolveContext':
  tools/skill-router/src/catalog.ts:75: const ctx = opts.ctx ?? (await resolveContext());  [in ctx (constant)]
  tools/skill-router/src/discover.ts:13: ... [in discoverAllSkills (function, L12-L65)]
  tools/skill-router/test/subprocess-gating.test.ts:116: return resolveContext(  [in ctxFor (function, L111-L129)]
```

`rg -n -w resolveContext` returned the same 17 lines flat: no definition body, no enclosing function, docs mixed with code.

## One identifier, definition and usages in one bounded reply: fff grep

`fff grep query=resolveContext`:

```
→ Read tools/skill-router/src/config.ts [def]
tools/skill-router/src/config.ts
 53: export async function resolveContext(runtime: RouterRuntime = defaultRuntime()): Promise<RouterContext> {
CONTEXT.md
 82: …pair resolved at the `cli.ts` edge by `resolveContext` and threaded through every module…
tools/skill-router/src/cli.ts
 65: const ctx = await resolveContext();
```

Definition marked `[def]`, usages in code and docs, 12 lines.

## Two or three spellings at once: fff multi_grep

`multi_grep patterns=["hunk-bin","hunkBin","hunk_bin"] constraints="!references/"` returned 8 lines across 4 files. The rg equivalent needs an alternation and a glob: `rg -n "hunk-bin|hunkBin|hunk_bin" --glob '!references/**'`.

## A half-remembered file name: fff find_files

`find_files query="hunk bin"`:

```
pkgs/hunk-bin.nix git:modified
scripts/update-hunk.sh git:modified
pkgs/bun-canary-bin.nix git:clean
```

## Words only: rw --for

`rw --for="resolve context config runtime"` returned 33 ranked signatures in about 4k tokens: rank 1 `resolveContext` with `in=6` callers and `tested=1`, then the CONTEXT.md and ADR sections that mention it.
