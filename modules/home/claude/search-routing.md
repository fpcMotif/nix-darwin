# Code search routing: examples, wrappers, traps

Reference behind the "Code search routing" section of CLAUDE.md. The section carries the six routing steps; this file carries what only some branches need. Numbers and failure modes measured 2026-09: `~/.claude/search-eval.md`.

## Worked examples (nix-config, 2026-09-09)

### A symbol: codedb_explain before any file

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

### One identifier, definition and usages in one bounded reply: fff grep

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

Definition marked `[def]`, usages in code and docs, 12 lines. Read the header: `N/M matches`; `0 exact matches` means absent.

### Two or three spellings at once: fff multi_grep

`multi_grep patterns=["hunk-bin","hunkBin","hunk_bin"] constraints="!references/"` returned 8 lines across 4 files. The rg equivalent needs an alternation and a glob: `rg -n "hunk-bin|hunkBin|hunk_bin" --glob '!references/**'`.

### A half-remembered file name: fff find_files

`find_files query="hunk bin"`:

```
pkgs/hunk-bin.nix git:modified
scripts/update-hunk.sh git:modified
pkgs/bun-canary-bin.nix git:clean
```

Recent and git-dirty files rank first. Keep queries to one or two terms; each extra word narrows, it does not widen.

### Words only: rw --for

`rw --for="resolve context config runtime"` returned 33 ranked signatures in about 4k tokens: rank 1 `resolveContext` with `in=6` callers and `tested=1`, then the CONTEXT.md and ADR sections that mention it. Outline the rank-1 file next.

## Wrappers on PATH

- `tg`: tgrep with a per-repo index in `~/.cache`, same flags as rg. Use above ~20k files.
- `rw`: ripwire with node_modules excluded and legends stripped. `rw --verb=...` inside `<repo>`, `rw <repo> --verb=...` elsewhere.

## MCP or CLI

codedb, fff, and zg each run as an MCP server: same answers as the CLI, typed parameters, no shell quoting. Schemas are deferred, so the first MCP call in a session costs one ToolSearch round trip. codedb's server needs ~12 s after session start; its CLI is instant. Always pass `project=<repo>` (codedb) or `root=<repo>` (zg).

- codedb: `codedb_explain` for a symbol; `codedb_context` for a task, only with `semantic=local` (the default sends snippets to a remote reranker). Outline and read are CLI only.
- fff: `find_files` (fuzzy file names, frecency), `grep` (one bare identifier, plain text, no regex), `multi_grep` (OR over literal patterns). Hard cap 50 hits, so counts and exhaustive listings stay with `rg -c`. fff honours `.ignore`. fff has no CLI on this machine: inside a subagent, load its MCP schema with ToolSearch or use rg.
- zg: `zvec_grep_search` for word-only orientation on one TypeScript repo, `fts: SYM` when you know a name. It returns vector neighbours even when nothing matched lexically, so a zg hit never proves presence; confirm with rg.

## rg flags

One identifier per query. `-C2` for context, `-U` for multiline, `-uu` for an exhaustive scan (ignored and hidden files included).

## Traps

- codedb's enclosing-function labels are wrong inside loops and lambdas; for the enclosing function or the flags a caller tests, `rw --callers=SYM`.
- `rw --uses=CONST` returns 0 for TypeScript constants; use `rg -w`.
- `rw --callers` misses calls inside anonymous callbacks such as test `it()` blocks.
- codedb skips node_modules and files over 2 MiB; rg and tg cover them.
- `codedb word` is uncapped (27k lines for `Config`); a hook denies it without a pipe to head.
- The shell `grep` binary as a command is denied by a hook; `| grep` as a filter is fine.
- `rg -r` means `--replace`; never pass it.
- `~/devv` itself is 65k files of sibling checkouts; a hook denies rg there without a sub-path.
- A client-side limit is often mirrored by a differently named server constant joined only by a comment: after locating one, `rg -w` the identifier its comment names.
- `rw --edit-check=SYM` lists callers broken by a new arity. `rw --test-gate` exit 4 names tests to run and does not run them. `rw --quality-delta` exit 2 means a pre-existing symbol got materially worse.

## Structural patterns

ast-grep: `sg -p 'console.log($$$)' --lang ts`; rewrite with `sg --rewrite 'logger.debug($$$)' -p 'console.log($$$)'`.
