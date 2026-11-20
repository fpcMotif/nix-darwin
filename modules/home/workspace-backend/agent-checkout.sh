#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
agent-checkout: parallel checkouts for agents, as JJ workspaces in .jj repositories

  agent-checkout create        WorktreeCreate hook: reads {name, cwd} on stdin, prints the new path
  agent-checkout remove        WorktreeRemove hook: reads {worktree_path} on stdin
  agent-checkout land TARGET   Move a checkout's commits under @ in this JJ repository, then remove it.
                               TARGET is a JJ workspace name, a Git branch, or a checkout path.
EOF
  exit 2
}

die() { printf 'agent-checkout: %s\n' "$1" >&2; exit 1; }

# A base commit copies the parent's @ instead of sitting on top of it.
# A workspace whose @ descends from the parent's @ goes stale on every parent edit.
base_revset() { printf 'description(exact:"agent-base: %s\\n") & mutable()' "$1"; }

link_ignored_files() {
  local src=$1 dst=$2 dir file track
  local settings=${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}
  local -a linked=()
  if [ -f "$settings" ]; then
    while IFS= read -r dir; do
      [ -n "$dir" ] && [ -e "$src/$dir" ] && [ ! -e "$dst/$dir" ] || continue
      ln -s "$src/$dir" "$dst/$dir"
      linked+=("$dir")
    done < <(jq -r '.worktree.symlinkDirectories // [] | .[]' "$settings")
  fi
  # A `node_modules/` ignore rule matches directories only, so jj would commit the symlink.
  if [ "${#linked[@]}" -gt 0 ] && jj -R "$dst" workspace root >/dev/null 2>&1; then
    track=$(jj -R "$dst" config get snapshot.auto-track 2>/dev/null || printf 'all()')
    for dir in "${linked[@]}"; do track="$track ~ root:\"$dir\""; done
    jj -R "$dst" config set --workspace snapshot.auto-track "'$track'"
  fi
  if [ -f "$src/.worktreeinclude" ] && git -C "$src" rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r file; do
      [ -e "$dst/$file" ] && continue
      mkdir -p "$dst/$(dirname "$file")"
      cp -pR "$src/$file" "$dst/$file"
    done < <(git -C "$src" ls-files --others --ignored --exclude-from=.worktreeinclude)
  fi
}

create() {
  local input name cwd root path base
  input=$(cat)
  name=$(jq -r '.name // empty' <<<"$input")
  cwd=$(jq -r '.cwd // empty' <<<"$input")
  [[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid worktree name '$name'"
  [ -d "$cwd" ] || die "cwd '$cwd' is not a directory"

  if root=$(jj -R "$cwd" root 2>/dev/null); then
    path=$(dirname "$root")/$(basename "$root").$name
    [ -e "$path" ] && die "$path already exists"
    base=$(base_revset "$name")
    jj -R "$root" new --no-edit -m "agent-base: $name" @- >&2
    jj -R "$root" restore --from @ --into "$base" >&2
    jj -R "$root" workspace add --name "$name" -r "$base" "$path" >&2
  elif root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
    if command -v wt >/dev/null 2>&1; then
      path=$( (cd "$root" && wt switch --create "$name" --base HEAD --no-cd --format json) | jq -r '.path')
    else
      path=$(dirname "$root")/$(basename "$root").$name
      git -C "$root" worktree add -b "$name" "$path" HEAD >&2
    fi
  else
    die "'$cwd' is not inside a JJ or Git repository"
  fi
  [ -d "$path" ] || die "checkout '$path' was not created"
  link_ignored_files "$root" "$path"
  printf '%s\n' "$path"
}

workspace_name_at() {
  local path=$1 name
  while IFS= read -r name; do
    [ "$(jj -R "$path" workspace root --name "$name" 2>/dev/null)" = "$path" ] && { printf '%s\n' "$name"; return 0; }
  done < <(jj -R "$path" workspace list -T 'name ++ "\n"' 2>/dev/null)
  return 1
}

# Commits the agent made in workspace NAME, excluding the copied base and empty commits.
workspace_work() { printf '(%s)::%s@ ~ (%s) ~ empty()' "$(base_revset "$1")" "$1" "$(base_revset "$1")"; }

forget_workspace() {
  local repo=$1 name=$2 path=$3 base
  base=$(base_revset "$name")
  jj -R "$repo" workspace forget "$name" >&2
  jj -R "$repo" abandon "($base)::" >&2
  rm -rf -- "$path"
}

remove() {
  local path name count repo branch
  path=$(jq -r '.worktree_path // empty')
  [ -d "$path" ] || exit 0
  if name=$(workspace_name_at "$path"); then
    jj -R "$path" status >/dev/null
    count=$(jj -R "$path" log --no-graph -r "$(workspace_work "$name")" -T '"x\n"' | wc -l)
    [ "$count" -eq 0 ] || die "workspace '$name' holds $count unlanded commits; run 'agent-checkout land $name' in the main workspace"
    repo=$(jj -R "$path" workspace root --name default)
    forget_workspace "$repo" "$name" "$path"
  else
    repo=$(dirname "$(git -C "$path" rev-parse --path-format=absolute --git-common-dir)")
    branch=$(git -C "$path" branch --show-current)
    git -C "$repo" worktree remove "$path" >&2
    if [ -n "$branch" ] && ! git -C "$repo" branch -d "$branch" >&2; then
      printf 'agent-checkout: kept branch %s, which has unmerged commits\n' "$branch" >&2
    fi
  fi
}

land() {
  local target=${1:-} repo name path rev revs count branch
  [ -n "$target" ] || usage
  repo=$(jj root 2>/dev/null) || die "land runs inside a JJ repository; in a Git-only repository use 'wt merge'"

  if [ -d "$target" ]; then
    path=$(cd "$target" && pwd -P)
    if name=$(workspace_name_at "$path"); then target=$name; fi
  fi

  if path=$(jj workspace root --name "$target" 2>/dev/null); then
    name=$target
    jj -R "$path" status >/dev/null
    revs=$(workspace_work "$name")
  else
    path=""
    if [ -d "$target" ]; then
      path=$(cd "$target" && pwd -P)
      [ -z "$(git -C "$path" status --porcelain)" ] || die "$path has uncommitted changes; commit them there first"
      branch=$(git -C "$path" branch --show-current)
      if [ -z "$branch" ]; then
        branch=land/$(basename "$path")
        git -C "$path" branch -f "$branch" HEAD
      fi
      target=$branch
    fi
    jj git import >&2
    jj log --no-graph -r "bookmarks(exact:\"$target\")" -T '"x"' | grep -q x || die "no JJ workspace, Git branch, or checkout named '$target'"
    if [ -z "$path" ]; then
      path=$(git -C "$repo" worktree list --porcelain | awk -v b="branch refs/heads/$target" '/^worktree /{p=substr($0, 10)} $0 == b {print p}')
      [ -z "$path" ] || [ -z "$(git -C "$path" status --porcelain)" ] || die "$path has uncommitted changes; commit them there first"
    fi
    rev="bookmarks(exact:\"$target\")"
    revs="(::$rev ~ ::@) ~ empty()"
  fi

  count=$(jj log --no-graph -r "$revs" -T '"x\n"' | wc -l)
  if [ "$count" -gt 0 ]; then
    jj rebase -r "$revs" --insert-before @ >&2
  fi
  if [ -n "${name:-}" ]; then
    forget_workspace "$repo" "$name" "$path"
  elif [ -n "$path" ] && [ "$path" != "$repo" ]; then
    # The rebase moved the checked-out branch, so its files now differ from HEAD.
    # The checkout was verified clean before the rebase.
    git -C "$repo" worktree remove --force "$path" >&2
  fi
  printf 'agent-checkout: landed %s commits from %s under @\n' "$count" "$target"
  if jj log --no-graph -r 'conflicts() & ::@' -T '"x"' | grep -q x; then
    printf 'agent-checkout: conflicts below @; inspect with: jj log -r "conflicts() & ::@"\n'
  fi
}

case "${1:-}" in
  create) create ;;
  remove) remove ;;
  land) shift; land "$@" ;;
  *) usage ;;
esac
