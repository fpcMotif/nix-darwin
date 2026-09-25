#!/usr/bin/env bash
# Drive wt and djo against disposable Git and JJ repositories, using the config
# files and Zsh `source` lines each workspace-backend generation ships. Nothing
# here pushes, and no fixture has a remote.
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: workspace-backend-lifecycle-test.sh WT-CONFIG WT-ZSH DJO-CONFIG DJO-ZSH" >&2
  exit 2
fi
wt_config=$1
wt_zsh=$2
djo_config=$3
djo_zsh=$4

work=$(mktemp -d "${TMPDIR:-/tmp}/workspace-backend.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
work=$(cd "$work" && pwd -P)

export HOME=$work/home
export XDG_CONFIG_HOME=$HOME/.config
export JJ_CONFIG=$work/jj.toml
export GIT_CONFIG_GLOBAL=$work/gitconfig
# djo runs jj without a terminal. An editor jj opens would wait forever, so any
# editor request fails fast instead.
export JJ_EDITOR=false
mkdir -p "$XDG_CONFIG_HOME"
printf '[user]\nname = "Fixture"\nemail = "fixture@example.invalid"\n' > "$JJ_CONFIG"
git config --global user.name Fixture
git config --global user.email fixture@example.invalid
git config --global init.defaultBranch main

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}
pass() {
  printf 'ok - %s\n' "$1"
}
# Runs a command that must fail; keeps its combined output for inspection.
expect_failure() {
  local log=$1
  shift
  if "$@" >"$log" 2>&1; then
    cat "$log" >&2
    fail "expected failure: $*"
  fi
}
expect_output() {
  local log=$1 pattern=$2 message=$3
  grep -qF -- "$pattern" "$log" || { cat "$log" >&2; fail "$message"; }
}
# Runs a command from a directory without moving this script.
in_dir() {
  local dir=$1
  shift
  (cd -- "$dir" && "$@")
}
jj_workspaces() {
  in_dir "$1" jj workspace list -T 'name ++ "\n"'
}

# Home Manager swaps only its own links on a backend switch. This does the same
# with the generated files, so fixtures observe what activation would leave.
select_backend() {
  rm -f "$XDG_CONFIG_HOME/worktrunk/config.toml" "$XDG_CONFIG_HOME/dojjo/config.toml"
  case "$1" in
    worktrunk) mkdir -p "$XDG_CONFIG_HOME/worktrunk" && cp "$wt_config" "$XDG_CONFIG_HOME/worktrunk/config.toml" ;;
    dojjo) mkdir -p "$XDG_CONFIG_HOME/dojjo" && cp "$djo_config" "$XDG_CONFIG_HOME/dojjo/config.toml" ;;
  esac
}

# Loads a backend's shipped Zsh lines after compinit, the order zshrc uses, then
# runs a snippet. Prints the snippet's stdout.
in_zsh() {
  local lines=$1 dir=$2 snippet=$3
  (cd "$dir" && zsh -f -c "
    autoload -Uz compinit && compinit -u -d \"\$HOME/.zcompdump\"
    source ${lines}
    ${snippet}
  ")
}

snapshot_tree() {
  (cd "$1" && find . -path ./.git -prune -o -path ./.jj -prune -o -print | LC_ALL=C sort)
}

# Worktrunk records approvals here. dojjo has no approval mechanism, so this
# file must survive both switches byte for byte.
approvals=$XDG_CONFIG_HOME/worktrunk/approvals.toml
mkdir -p "$(dirname -- "$approvals")"
printf '[projects."example"]\napproved-commands = ["make setup"]\n' > "$approvals"
cp "$approvals" "$work/approvals.before"

# ---------------------------------------------------------------------------
# Worktrunk against a Git fixture.
# ---------------------------------------------------------------------------
select_backend worktrunk
git_repo=$work/gitrepo
mkdir "$git_repo"
git -C "$git_repo" init -q
echo base > "$git_repo/shared.txt"
git -C "$git_repo" add shared.txt
git -C "$git_repo" commit -qm base

(cd "$git_repo" && wt switch --create feat --no-cd >"$work/wt-create.log" 2>&1) \
  || { cat "$work/wt-create.log" >&2; fail "wt could not create a worktree"; }
[ -f "$work/gitrepo.feat/shared.txt" ] || fail "wt did not create the sibling worktree"
git -C "$git_repo" worktree list --porcelain | grep -qxF "worktree $work/gitrepo.feat" \
  || fail "git does not register the wt worktree"
(cd "$git_repo" && wt list --format json) | jq -e 'any(.items[]; .branch == "feat")' >/dev/null \
  || fail "wt list does not show the worktree"
pass "wt creates and lists a sibling Git worktree"

out=$(in_zsh "$wt_zsh" "$git_repo" '
  print -r -- "$_comps[wt]"
  wt switch feat >/dev/null 2>&1
  print -r -- "$PWD"
')
[ "$(printf '%s\n' "$out" | sed -n 1p)" = "_wt_lazy_complete" ] || fail "wt completion is not registered: $out"
[ "$(printf '%s\n' "$out" | sed -n 2p)" = "$work/gitrepo.feat" ] || fail "wt switch did not change directory: $out"
pass "wt Zsh wrapper changes directory and registers completion"

mkdir "$work/gitrepo.taken"
echo keep > "$work/gitrepo.taken/keep.txt"
expect_failure "$work/wt-taken.log" wt -C "$git_repo" switch --create taken --no-cd
expect_output "$work/wt-taken.log" "already exists" "wt did not explain the existing destination"
[ "$(cat "$work/gitrepo.taken/keep.txt")" = keep ] || fail "wt changed an existing destination"
pass "wt refuses an existing destination and leaves it intact"

echo dirty > "$work/gitrepo.feat/dirty.txt"
expect_failure "$work/wt-dirty.log" wt -C "$git_repo" remove feat --foreground
expect_output "$work/wt-dirty.log" "uncommitted changes" "wt did not explain the dirty refusal"
[ -f "$work/gitrepo.feat/dirty.txt" ] || fail "wt removed dirty work"
rm "$work/gitrepo.feat/dirty.txt"

git -C "$git_repo" switch -q -c other
echo other > "$git_repo/shared.txt"
git -C "$git_repo" commit -qam other
git -C "$git_repo" switch -q main
(cd "$work/gitrepo.feat" && echo feat > shared.txt && git commit -qam feat && ! git merge -q other >/dev/null 2>&1)
expect_failure "$work/wt-conflict.log" wt -C "$git_repo" remove feat --foreground
[ -f "$work/gitrepo.feat/shared.txt" ] || fail "wt removed a conflicted worktree"
git -C "$work/gitrepo.feat" merge --abort
pass "wt refuses dirty and conflicted worktrees"

mkdir -p "$git_repo/.config"
printf '[pre-start]\ncount = "echo run >> %s/wt-hook-count"\n' "$work" > "$git_repo/.config/wt.toml"
git -C "$git_repo" add .config && git -C "$git_repo" commit -qm hooks
expect_failure "$work/wt-unapproved.log" wt -C "$git_repo" switch --create unapproved --no-cd
expect_output "$work/wt-unapproved.log" "approval" "wt ran an unapproved project hook without saying so"
[ ! -e "$work/wt-hook-count" ] || fail "wt ran an unapproved project hook"
wt -C "$git_repo" switch --create hooked --no-cd --yes >"$work/wt-hooked.log" 2>&1 \
  || { cat "$work/wt-hooked.log" >&2; fail "wt --yes did not run the project hook"; }
[ "$(wc -l < "$work/wt-hook-count")" -eq 1 ] || fail "wt ran the project hook more than once"
cmp -s "$work/approvals.before" "$approvals" || fail "wt --yes rewrote approvals"
pass "wt gates project hooks behind approval and runs them once"

(cd "$git_repo" && wt remove hooked --foreground --no-hooks >/dev/null 2>&1) || fail "wt could not remove a clean worktree"
[ ! -e "$work/gitrepo.hooked" ] || fail "wt left a removed worktree directory"
if git -C "$git_repo" worktree list --porcelain | grep -qxF "worktree $work/gitrepo.hooked"; then
  fail "git still registers a removed worktree"
fi
pass "wt removes a clean worktree and its registration"

jj_only=$work/jjonly
mkdir "$jj_only"
(cd "$jj_only" && jj git init --no-colocate >/dev/null 2>&1)
expect_failure "$work/wt-mismatch.log" wt -C "$jj_only" switch --create x --no-cd
[ ! -e "$jj_only/.git" ] || fail "wt initialized Git inside a JJ-only repository"
pass "wt fails visibly in a JJ-only repository"

expect_failure "$work/wt-no-git.log" env PATH="$(dirname -- "$(command -v wt)")" wt -C "$git_repo" list
pass "wt fails visibly without git"

git -C "$git_repo" worktree list --porcelain > "$work/git-worktrees.before"
snapshot_tree "$work/gitrepo.feat" > "$work/feat-tree.before"

# ---------------------------------------------------------------------------
# Switch to dojjo. Existing worktrees and approvals stay untouched.
# ---------------------------------------------------------------------------
select_backend dojjo
git -C "$git_repo" worktree list --porcelain | cmp -s - "$work/git-worktrees.before" \
  || fail "switching to dojjo changed Git worktree registration"
snapshot_tree "$work/gitrepo.feat" | cmp -s - "$work/feat-tree.before" \
  || fail "switching to dojjo changed an existing worktree"
cmp -s "$work/approvals.before" "$approvals" || fail "switching to dojjo changed approvals"
pass "switching to dojjo leaves worktrees and approvals intact"

# ---------------------------------------------------------------------------
# dojjo against JJ fixtures: one JJ-only, one colocated with Git.
# ---------------------------------------------------------------------------
new_jj_repo() {
  local dir=$1 mode=$2
  mkdir "$dir"
  (
    cd "$dir"
    jj git init "$mode" >/dev/null 2>&1
    echo base > shared.txt
    jj commit -m base >/dev/null 2>&1
    jj bookmark create main -r @- >/dev/null 2>&1
  )
}
jj_repo=$work/jjrepo
new_jj_repo "$jj_repo" --no-colocate

(cd "$jj_repo" && djo config show) > "$work/djo-config.log" 2>&1
expect_output "$work/djo-config.log" "dojjo user: $XDG_CONFIG_HOME/dojjo/config.toml" "djo did not load the generated user config"

(cd "$jj_repo" && djo switch --create a --base main >/dev/null 2>&1) || fail "djo could not create workspace a"
(cd "$jj_repo" && djo switch --create b --base main >/dev/null 2>&1) || fail "djo could not create workspace b"
for name in a b; do
  [ -f "$work/jjrepo.$name/shared.txt" ] || fail "djo did not create the sibling workspace $name"
done
jj_workspaces "$jj_repo" > "$work/jj-workspaces.log"
for name in a b default; do
  grep -qxF "$name" "$work/jj-workspaces.log" || fail "jj does not register workspace $name"
done
(cd "$jj_repo" && djo list --json) | jq -e '[.[].name] | index("a") and index("b")' >/dev/null \
  || fail "djo list does not show both workspaces"
pass "djo creates and lists sibling JJ workspaces"

echo only-a > "$work/jjrepo.a/only-a.txt"
echo only-b > "$work/jjrepo.b/only-b.txt"
(cd "$work/jjrepo.a" && jj status >/dev/null)
(cd "$work/jjrepo.b" && jj status >/dev/null)
commit_a=$(cd "$jj_repo" && jj log --no-graph -r 'a@' -T commit_id)
commit_b=$(cd "$jj_repo" && jj log --no-graph -r 'b@' -T commit_id)
[ "$commit_a" != "$commit_b" ] || fail "two workspaces share one working-copy commit"
files_a=$(cd "$jj_repo" && jj file list -r 'a@')
files_b=$(cd "$jj_repo" && jj file list -r 'b@')
printf '%s\n' "$files_a" | grep -qxF only-a.txt || fail "workspace a lost its own file"
printf '%s\n' "$files_a" | grep -qxF only-b.txt && fail "workspace a recorded workspace b's file"
printf '%s\n' "$files_b" | grep -qxF only-a.txt && fail "workspace b recorded workspace a's file"
[ ! -e "$work/jjrepo.a/only-b.txt" ] || fail "workspace b's file appeared in workspace a"
pass "two JJ workspaces keep independent files and working-copy commits"

(cd "$jj_repo" && djo switch --create rooted >/dev/null 2>&1) || fail "djo could not create a trunk()-based workspace"
[ -z "$(find "$work/jjrepo.rooted" -mindepth 1 -maxdepth 1 ! -name .jj -print -quit)" ] \
  || fail "trunk() without a remote no longer resolves to the empty root; update the guidance"
pass "djo --create without --base starts from the empty root when no remote trunk exists"

out=$(in_zsh "$djo_zsh" "$jj_repo" '
  print -r -- "$_comps[djo]"
  djo switch a >/dev/null 2>&1
  print -r -- "$PWD"
')
[ "$(printf '%s\n' "$out" | sed -n 1p)" = "_djo" ] || fail "djo completion is not registered: $out"
[ "$(printf '%s\n' "$out" | sed -n 2p)" = "$work/jjrepo.a" ] || fail "djo switch did not change directory: $out"
pass "djo Zsh wrapper changes directory and registers completion"

colocated=$work/colorepo
new_jj_repo "$colocated" --colocate
(cd "$colocated" && djo switch --create c --base main >/dev/null 2>&1) || fail "djo could not create a colocated workspace"
[ -d "$work/colorepo.c/.jj" ] && [ ! -e "$work/colorepo.c/.git" ] \
  || fail "the colocated JJ workspace is not a plain JJ workspace"
[ "$(git -C "$colocated" worktree list --porcelain | grep -c '^worktree ')" -eq 1 ] \
  || fail "a JJ workspace was registered as a Git worktree"
jj_workspaces "$colocated" | grep -qxF c \
  || fail "jj does not register the colocated workspace"
pass "a colocated repository gets a JJ workspace, not a Git worktree"

mkdir "$work/jjrepo.taken"
echo keep > "$work/jjrepo.taken/keep.txt"
expect_failure "$work/djo-taken.log" in_dir "$jj_repo" djo switch --create taken --base main
expect_output "$work/djo-taken.log" "not an empty directory" "djo did not explain the existing destination"
[ "$(cat "$work/jjrepo.taken/keep.txt")" = keep ] || fail "djo changed an existing destination"
jj_workspaces "$jj_repo" | grep -qxF taken && fail "djo registered a failed workspace"
pass "djo refuses an existing destination and leaves it intact"

echo unsnapshotted > "$work/jjrepo.b/dirty.txt"
expect_failure "$work/djo-dirty.log" in_dir "$jj_repo" djo remove b </dev/null
expect_output "$work/djo-dirty.log" "Aborted" "djo remove did not abort without confirmation"
[ -f "$work/jjrepo.b/dirty.txt" ] || fail "djo remove deleted dirty work"
jj_workspaces "$jj_repo" | grep -qxF b || fail "djo remove forgot b without confirmation"

(cd "$jj_repo" && echo trunk-side > shared.txt && jj commit -m trunk-side >/dev/null 2>&1)
(cd "$work/jjrepo.a" && echo a-side > shared.txt && jj describe -m a-side >/dev/null 2>&1)
(cd "$jj_repo" && jj rebase -r 'a@' -d @- >/dev/null 2>&1)
[ "$(cd "$jj_repo" && jj log --no-graph -r 'a@' -T conflict)" = true ] || fail "fixture did not produce a conflict"
(cd "$jj_repo" && djo list) | grep -F ' a ' | grep -qF '✘' || fail "djo list does not flag the conflict"
expect_failure "$work/djo-conflict.log" in_dir "$jj_repo" djo remove a </dev/null
[ -d "$work/jjrepo.a" ] || fail "djo remove deleted a conflicted workspace"
pass "djo remove refuses dirty and conflicted workspaces without confirmation"

# The cleanup the guidance names: snapshot, forget, then delete by hand.
(cd "$work/jjrepo.b" && jj status >/dev/null)
kept=$(cd "$jj_repo" && jj log --no-graph -r 'b@' -T change_id)
(cd "$jj_repo" && jj workspace forget b)
(cd "$jj_repo" && jj log --no-graph -r "$kept" -T 'change_id') >/dev/null 2>&1 \
  || fail "jj workspace forget lost the workspace's change"
(cd "$jj_repo" && jj file list -r "$kept") | grep -qxF dirty.txt || fail "forgotten change lost the dirty file"
[ -f "$work/jjrepo.b/dirty.txt" ] || fail "jj workspace forget deleted files"
rm -rf -- "$work/jjrepo.b"
pass "jj workspace forget keeps the change and files for manual cleanup"

mkdir -p "$jj_repo/.config"
printf '[hooks]\npre-start = "echo run >> %s/djo-hook-count"\n' "$work" > "$jj_repo/.config/wt.toml"
(cd "$jj_repo" && djo switch --create hooked --base main </dev/null >"$work/djo-hooked.log" 2>&1) \
  || { cat "$work/djo-hooked.log" >&2; fail "djo did not run the project hook"; }
[ "$(wc -l < "$work/djo-hook-count")" -eq 1 ] || fail "djo ran the project hook more than once"
cmp -s "$work/approvals.before" "$approvals" || fail "djo changed Worktrunk approvals"
printf 'ignore-worktrunk-hooks = true\n[hooks]\npre-start = "echo dup >> %s/djo-hook-count"\n' "$work" > "$jj_repo/dojjo.toml"
(cd "$jj_repo" && djo switch --create hooked2 --base main </dev/null >/dev/null 2>&1) || fail "djo failed with dojjo.toml hooks"
[ "$(grep -c . "$work/djo-hook-count")" -eq 2 ] && grep -qx dup "$work/djo-hook-count" \
  || fail "ignore-worktrunk-hooks did not leave exactly one hook run"
rm "$jj_repo/dojjo.toml"
printf '[hooks]\npre-start = "exit 3"\n' > "$jj_repo/.config/wt.toml"
expect_failure "$work/djo-hook-fail.log" in_dir "$jj_repo" djo switch --create broken --base main
expect_output "$work/djo-hook-fail.log" "failed with exit code 3" "djo hid a failing hook"
[ ! -e "$work/jjrepo.broken" ] || fail "djo created a workspace after a failing pre-start hook"
pass "djo runs project wt.toml hooks once, without approval, and surfaces failures"

printf 'worktree-path = "{{ repo_path }}/../project-path.{{ branch }}"\n' > "$jj_repo/.config/wt.toml"
(cd "$jj_repo" && djo switch --create precedence --base main >/dev/null 2>&1) || fail "djo failed under a project worktree-path"
[ -d "$work/jjrepo.precedence" ] && [ ! -e "$work/project-path.precedence" ] \
  || fail "a project worktree-path overrode the generated dojjo workspace-path"
rm -rf "$jj_repo/.config"
pass "the generated dojjo workspace-path outranks a project worktree-path"

printf 'workspace-path = "{{ repo_path }}/../project.{{ branch }}"\n' > "$jj_repo/dojjo.toml"
printf 'workspace-path = "{{ repo_path }}/../local.{{ branch }}"\n' > "$jj_repo/dojjo.local.toml"
(cd "$jj_repo" && djo switch --create ranked --base main >/dev/null 2>&1) || fail "djo failed under project dojjo files"
[ -d "$work/local.ranked" ] || fail "dojjo.local.toml did not outrank dojjo.toml"
rm "$jj_repo/dojjo.local.toml"
(cd "$jj_repo" && djo switch --create ranked2 --base main >/dev/null 2>&1) || fail "djo failed under project dojjo.toml"
[ -d "$work/project.ranked2" ] || fail "project dojjo.toml did not outrank the generated user config"
pass "dojjo.local.toml outranks dojjo.toml, which outranks the generated user config"

# The global Worktrunk keys, plus a key nothing reads, parse without a word.
printf 'skip-shell-integration-prompt = true\nbogus-key = 1\n[commit.generation]\ncommand = "unused"\n[list]\njson-schema = 2\n' \
  > "$jj_repo/dojjo.toml"
(cd "$jj_repo" && djo list >/dev/null 2>"$work/djo-unknown.log") \
  || { cat "$work/djo-unknown.log" >&2; fail "djo rejected Worktrunk-only or unknown keys"; }
[ ! -s "$work/djo-unknown.log" ] || { cat "$work/djo-unknown.log" >&2; fail "djo warned about unknown keys"; }
rm "$jj_repo/dojjo.toml"
pass "djo ignores Worktrunk-only and unknown keys without a warning"

# `wt step NAME` becomes `djo run NAME`; any other `wt ` word becomes `djo `,
# even inside unrelated text.
mkdir -p "$jj_repo/.config"
printf '[aliases]\ngreet = "echo alias-ran >> %s/djo-rewrite"\n[hooks]\npre-start = [{ step = "wt step greet" }, { word = "echo wt ok >> %s/djo-rewrite" }]\n' \
  "$work" "$work" > "$jj_repo/.config/wt.toml"
(cd "$jj_repo" && djo switch --create rewritten --base main </dev/null >"$work/djo-rewrite.log" 2>&1) \
  || { cat "$work/djo-rewrite.log" >&2; fail "djo failed to run rewritten hooks"; }
[ "$(printf 'alias-ran\ndjo ok')" = "$(< "$work/djo-rewrite")" ] \
  || { cat "$work/djo-rewrite" >&2; fail "djo did not rewrite wt commands as documented"; }
rm -rf "$jj_repo/.config"
pass "djo rewrites wt step to djo run, and rewrites wt inside other hook text"

# Squashing a described working copy into a described parent asks jj for an
# editor. djo gives jj no terminal, so the merge stops at its first step.
(cd "$work/jjrepo.precedence" && echo draft > draft.txt && jj describe -m draft >/dev/null 2>&1)
expect_failure "$work/djo-merge-editor.log" in_dir "$work/jjrepo.precedence" djo merge main --yes
expect_output "$work/djo-merge-editor.log" "jj op undo" "djo merge hid the squash failure"
jj_workspaces "$jj_repo" | grep -qxF precedence \
  || fail "a failed merge forgot the workspace"
(cd "$work/jjrepo.precedence" && rm draft.txt && jj describe -m '' >/dev/null 2>&1)
pass "djo merge stops visibly when jj squash needs an editor"

(cd "$work/jjrepo.precedence" && echo merged > merged.txt && jj commit -m merged >/dev/null 2>&1)
(cd "$work/jjrepo.precedence" && djo merge main --yes >"$work/djo-merge.log" 2>&1) \
  || { cat "$work/djo-merge.log" >&2; fail "djo merge failed in a fixture"; }
[ -f "$work/jjrepo.precedence/merged.txt" ] || fail "merge.remove = false still deleted the workspace directory"
(cd "$jj_repo" && jj file list -r main) | grep -qxF merged.txt || fail "djo merge did not move main"
# djo 0.2.2 forgets with `jj workspace forget @`; jj reads "@" as a workspace
# name, warns, and exits 0. Upstream's merge.remove = true would then delete a
# still-registered workspace. Revisit docs/workspace-backends.md when this fails.
jj_workspaces "$jj_repo" | grep -qxF precedence \
  || fail "djo merge now forgets the workspace; update docs/workspace-backends.md"
(cd "$jj_repo" && jj git remote list) | grep -q . && fail "a fixture gained a remote"
pass "djo merge moves main, keeps the directory, and pushes nowhere under the generated config"

jj_before=$(jj_workspaces "$jj_repo")
expect_failure "$work/djo-no-jj.log" in_dir "$jj_repo" env PATH="$(dirname -- "$(command -v djo)")" djo list
expect_output "$work/djo-no-jj.log" "Failed to run jj" "djo hid the missing jj binary"
expect_failure "$work/djo-mismatch.log" in_dir "$git_repo" djo list
expect_output "$work/djo-mismatch.log" "There is no jj repo" "djo did not name the repository mismatch"
[ ! -e "$git_repo/.jj" ] || fail "djo initialized JJ inside a Git repository"
pass "djo fails visibly without jj and in a Git-only repository"

snapshot_tree "$work/jjrepo.a" > "$work/a-tree.before"

# ---------------------------------------------------------------------------
# Roll back to Worktrunk. JJ workspaces and Git worktrees both survive.
# ---------------------------------------------------------------------------
select_backend worktrunk
[ "$(jj_workspaces "$jj_repo")" = "$jj_before" ] \
  || fail "rollback changed JJ workspace registration"
snapshot_tree "$work/jjrepo.a" | cmp -s - "$work/a-tree.before" || fail "rollback changed a JJ workspace"
git -C "$git_repo" worktree list --porcelain | cmp -s - "$work/git-worktrees.before" \
  || fail "rollback changed Git worktree registration"
cmp -s "$work/approvals.before" "$approvals" || fail "rollback changed approvals"
(cd "$git_repo" && wt list --format json) | jq -e 'any(.items[]; .branch == "feat")' >/dev/null \
  || fail "wt no longer lists the worktree after rollback"
pass "rollback to Worktrunk keeps every workspace, worktree, and approval"

printf 'PASS unit-workspace-backend-lifecycle\n'
