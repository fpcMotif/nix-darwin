# CLAUDE.md — Global Development Guidelines

## Identity

- **User**: f
- **Primary tools**: Claude Code (Opus), Droid (Factory), OpenCode, Zed
- **Package managers**: bun/bunx (never npm/npx), pnpm, uv (Python), cargo (Rust)
- **Terminal**: Ghostty + Kitty | Shell: Zsh | Prompt: Starship

## Tooling defaults

Rust CLIs replace the classic tools — use these in Bash:

| Classic | Use |
|---------|-----|
| `find` | `fd` |
| `grep` | `rg` |
| `cat` | `bat` |
| `ls` / `tree` | `eza` / `eza --tree` |
| `du` | `dust` |
| `ps` | `procs` |
| `top` | `btm` |
| `curl` (API calls) | `xh` |
| diff viewing | `delta` |
| ad-hoc benchmarks | `hyperfine` |

## Code search routing (measured 2026-09 on this machine; evidence in ~/.claude/search-eval.md)

<repo> = the ABSOLUTE path of the git repo root you are working in (substitute it; it is not a shell variable). Never search the ~/devv umbrella itself (65k files, sibling checkouts of the same repo).
Wrappers on PATH: `tg` = tgrep with a per-repo index kept in ~/.cache, same flags as rg (-n -w -c -l -C2 -U -t ts).
`rw` = ripwire with node_modules excluded and XML legends stripped: `rw --verb=...` inside <repo>, or `rw <repo> --verb=...`.

Procedure. Stop as soon as you can act; three lookups usually suffice.
1. Know a symbol name -> `codedb <repo> explain SYM` (MCP: codedb_explain name=SYM project=<repo>): definition body + every call site, one call.
   Its enclosing labels `[in for (constant)]` are wrong for loops/lambdas. Need the enclosing function or tested flags -> `rw --callers=SYM`.
2. Know a file -> `codedb <repo> outline FILE`: every symbol with line numbers. Then read ONLY that span: Read with offset/limit, or `codedb <repo> read FILE -L A-B`.
3. Know only words -> `rw --for="the words + any identifier you know"`: ranked signatures, r=1 is the anchor (finds constants via doc comments). Then step 2 on that file.
4. Need EVERY mention of a text (re-exports/barrels, docs, comments, string literals, constants, counts) -> `tg -c PAT <repo>` first, then `tg -n -w PAT <repo>`.
   One identifier per query. `-C2` context, `-U` multiline, `-c` counts lines. Inside one repo `rg -n PAT <repo>` is equivalent (both under 50 ms up to ~4k files, rg 175 ms at 19k files); tg is what stays fast at the umbrella scale, where rg takes 0.6-2 s.
   To claim a text is ABSENT, only an exhaustive scan counts: `tg -c PAT <repo>` (text files up to 64 MiB, ignore rules applied) or `rg -uu PAT <repo>` (hidden and ignored files too). Never codedb or fff for absence. Name the tool and scope behind every "not found".
5. Before saying done: `rw --edit-check=SYM` (callers broken by a new arity), `rw --test-gate` (exit 4 = it names tests to run and an untested radius; it does not run them, so run them), `rw --quality-delta` (exit 2 = a pre-existing symbol got materially worse; new-symbol debt is printed but never gates; a renamed symbol reads as new).

Do not:
- The shell `grep` binary, ever: slower and weaker than every other tool here (no ignore rules, no index, no symbols). Use `rg` with the same flags (but never `-r`: rg reads it as --replace), or `tg`. The built-in Grep tool is rg and is fine. A hook denies a leading `grep`; `| grep` as a pipe filter is allowed.
- Read whole files to learn one thing; read spans (step 2). Do not re-verify with a second tool unless the first said counts_floor or `[in for (constant)]`.
- `codedb word X` (uncapped: 27k lines for Config). `rg` from the ~/devv root (1.8 s, floods). Listing (-n) 4+ alternations with no -c/-l/-w or -g/-t narrowing (30-300 KB spills).
- MCP fff `grep` to enumerate (hard cap 50 hits; "0 exact matches" means absent). fff is for `find_files` by fuzzy name.
- `rw --uses=CONST` for TypeScript constants (returns 0): use `tg -w CONST <repo>`. `rw --callers` misses calls inside anonymous callbacks (test it() blocks); `tg` catches them.
- Expect codedb to see files > 2 MiB or node_modules; tg/rg cover them (tg caps at 64 MiB). Files of 1-2 MiB have no trigram entry: `codedb search` still finds them through a 2-7 s first-time scan, `codedb word` instantly.
- `codedb context` / MCP codedb_context without `--local` / semantic=local: the default hybrid mode sends ~3 KB of path+snippet items to a remote reranker.
Batch independent lookups in ONE Bash call separated by `;`. A grep after a pipe (`| grep`) is a filter and is never blocked.

Structural / syntax patterns (refactors, API usage) -> ast-grep: `sg -p 'console.log($$$)' --lang ts`, `sg --rewrite 'logger.debug($$$)' -p 'console.log($$$)'`.
A client-side limit is often mirrored by a differently named server constant joined only by a comment: after locating one, `tg -w` the identifier its comment names.
Inside one repo the built-in Grep/Glob tools (rg underneath) are fine: 12 ms at 600 files, 175 ms at 19k. The routing above is about token shape (bodies + callers in one call); tg is for the 65k-file umbrella.

## Git

- Review changes before any commit; conventional format `type(scope): message`
- Jujutsu repos: the `/jj` skill covers the jj workflow and hunk-level review

## Code Quality

- Comments only for what code can't say; no defensive checks
- Match existing codebase patterns; confirm a library is installed before using it
- Never expose secrets, keys, or tokens in code or logs
- bun/bunx for all package management and script execution (never npm/npx)

## Writing Style

Be concise. Sacrifice grammar for concision. Short sentences, plain words, define or cut jargon. McCloskey/Pinker standard, not academic hedging. Never touch facts, quotes, citations, or code for style — only the words around them.
