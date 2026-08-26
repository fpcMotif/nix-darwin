# CLAUDE.md — Global Development Guidelines

## Identity

- **User**: f
- **Primary tools**: Claude Code (Opus), Droid (Factory), OpenCode
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

## Search — match the query type to the tool

- **Filename patterns** → built-in Glob.
- **Text / regex** → built-in Grep (it *is* ripgrep).
- **File discovery** (fuzzy, recently-used, git-dirty) → fff MCP `find_files`; ranked content search → fff `grep`; multi-pattern OR → fff `multi_grep`.
- **Structural code patterns** — refactors, API usage, anything where the pattern is syntax, not text → ast-grep:

  ```bash
  sg -p 'console.log($$$)' --lang ts                       # all call sites
  sg -p 'useEffect($FN, [])' --lang tsx                    # hooks with empty deps
  sg --rewrite 'logger.debug($$$)' -p 'console.log($$$)'   # structural replace
  ```

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
