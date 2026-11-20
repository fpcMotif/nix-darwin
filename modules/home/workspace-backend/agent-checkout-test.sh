#!/usr/bin/env bash
# The nix check passes the packaged binary; a local run uses the script beside this file.
set -u
AC=${1:-$(dirname "$0")/agent-checkout.sh}
TMP=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$TMP"' EXIT
export HOME=$TMP/home JJ_CONFIG=$TMP/jj.toml CLAUDE_SETTINGS=$TMP/settings.json
mkdir -p "$HOME"
printf '[user]\nname = "t"\nemail = "t@example.com"\n' >"$JJ_CONFIG"
git config --global user.name t; git config --global user.email t@example.com; git config --global init.defaultBranch main
printf '{"worktree":{"symlinkDirectories":["node_modules"]}}' >"$CLAUDE_SETTINGS"
fail=0; n=0
ok() { n=$((n + 1)); if ! eval "$2" >/dev/null 2>&1; then fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; tail -3 "$TMP/err" 2>/dev/null; fi; }
hook() { jq -cn --arg n "$2" --arg d "$3" --arg p "$3" "$1" | bash "$AC" "$4" 2>"$TMP/err"; }
desc() { jj log --no-graph -r "$1" -T 'description.first_line() ++ "\n"'; }

# JJ: the subagent sees the parent's uncommitted work, stays usable while the parent edits, and lands under @.
R=$TMP/jjrepo; jj git init --colocate "$R" >/dev/null 2>&1; cd "$R" || exit 1
echo a >f; printf 'node_modules/\n.env\n' >.gitignore; mkdir node_modules; echo s >.env; printf '.env\n' >.worktreeinclude
jj commit -m base >/dev/null 2>&1; echo wip >w
P=$(hook '{name:$n,cwd:$d}' sub "$R" create)
ok "jj create prints the sibling path" '[ "$P" = "$TMP/jjrepo.sub" ]'
ok "jj create copies the parent's uncommitted file" '[ "$(cat "$P/w")" = wip ]'
ok "jj create links symlinkDirectories" '[ -L "$P/node_modules" ]'
ok "jj create copies .worktreeinclude files" '[ "$(cat "$P/.env")" = s ]'
ok "jj create registers the workspace" 'jj workspace list -T "name ++ \"\n\"" | grep -qx sub'
echo more >>w; jj status >/dev/null 2>&1
ok "subagent workspace stays fresh after a parent edit" 'jj -R "$P" status'
(cd "$P" && echo x >s && jj commit -m "sub work" >/dev/null 2>&1)
ok "remove refuses a workspace with unlanded commits" '! hook "{worktree_path:\$p}" "" "$P" remove'
ok "refused remove keeps the directory" '[ -d "$P" ]'
bash "$AC" land sub >/dev/null 2>&1
ok "land puts the subagent commit under @" '[ "$(desc @-)" = "sub work" ]'
ok "land keeps the parent's working copy" '[ "$(cat w)" = "$(printf "wip\nmore")" ] && [ -f s ]'
ok "land forgets the workspace" '! jj workspace list -T "name ++ \"\n\"" | grep -qx sub'
ok "land deletes the directory" '[ ! -e "$P" ]'
ok "land abandons the base copy" '[ -z "$(jj log --no-graph -r "description(substring:\"agent-base\")" -T change_id)" ]'

P=$(hook '{name:$n,cwd:$d}' idle "$R" create)
ok "remove deletes an unused workspace" 'hook "{worktree_path:\$p}" "" "$P" remove && [ ! -e "$P" ]'
ok "remove forgets the workspace" '! jj workspace list -T "name ++ \"\n\"" | grep -qx idle'

# Git branch from a host's own worktree, as Antigravity subagents make.
git worktree add -q -b feat "$TMP/feat" HEAD >/dev/null 2>&1
(cd "$TMP/feat" && echo g >g && git add g && git commit -qm "agy work")
ok "land accepts a clean branch" 'bash "$AC" land feat'
ok "land puts the branch commit under @" '[ "$(desc @-)" = "agy work" ]'
ok "land removes the Git worktree" '[ ! -e "$TMP/feat" ]'
git worktree add -q -b dirty "$TMP/dirty" HEAD >/dev/null 2>&1; echo d >"$TMP/dirty/d"
ok "land refuses a checkout with uncommitted changes" '! bash "$AC" land "$TMP/dirty"'

# Git-only repository: wt when installed, plain git worktree otherwise. Both use the sibling path.
G=$TMP/gitrepo; git init -q "$G"; git -C "$G" commit -q --allow-empty -m init
P=$(hook '{name:$n,cwd:$d}' gsub "$G" create)
ok "git create prints the sibling path" '[ "$P" = "$TMP/gitrepo.gsub" ] && [ -d "$P" ]'
ok "git remove deletes the worktree and its merged branch" 'hook "{worktree_path:\$p}" "" "$P" remove && [ ! -e "$P" ] && ! git -C "$G" rev-parse -q --verify gsub'
ok "create rejects a name with a slash" '! hook "{name:\$n,cwd:\$d}" "../x" "$G" create'

printf '%d/%d agent-checkout checks passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
