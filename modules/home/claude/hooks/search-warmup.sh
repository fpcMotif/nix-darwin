#!/bin/bash
# SessionStart: make the indexed search tools warm for the repo under $PWD, in the background, and tell the
# model (one line) what is ready. Never blocks the session. Disable: SEARCH_GUARD_OFF=1.
[ -n "${SEARCH_GUARD_OFF:-}" ] && exit 0
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
name="$(basename "$root")-$(printf '%s' "$root" | shasum | cut -c1-8)"
idx="$HOME/.cache/tgrep/$name"
have=""
command -v tgrep >/dev/null && { have="$have tg"; ( tgrep index "$root" --index-path "$idx" --exclude .tgrep --exclude node_modules >/dev/null 2>&1 & ); }
command -v ripwire >/dev/null && [ "$root" != "$HOME/devv" ] && { have="$have rw"; ( ripwire "$root" --cache="$HOME/.cache/ripwire/$name.bin" --exclude=node_modules --top-k=1 >/dev/null 2>&1 & ); }
command -v codedb >/dev/null && { have="$have codedb"; ( codedb "$root" status >/dev/null 2>&1 & ); }
umb=""; [ "$root" = "$HOME/devv" ] && umb=" WARNING: cwd is the ~/devv umbrella (65k files, sibling checkouts): cd into ONE repo before searching."
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Search tools warm for %s:%s (indexes in ~/.cache). Follow the Code search routing in CLAUDE.md; codedb MCP needs ~12s after start.%s"}}\n' "$root" "$have" "$umb"
exit 0
