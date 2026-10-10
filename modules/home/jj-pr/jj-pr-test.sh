#!/usr/bin/env bash
# Drive jj-pr against a disposable jj repository. Its GitHub remote is rewritten
# to a local bare repository, and a stub gh records calls and keeps PR state.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: jj-pr-test.sh JJ-PR" >&2
  exit 2
fi
jj_pr=$1

work=$(mktemp -d "${TMPDIR:-/tmp}/jj-pr.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
work=$(cd "$work" && pwd -P)

export HOME=$work/home
export JJ_CONFIG=$work/jj.toml
export GIT_CONFIG_GLOBAL=$work/gitconfig
export JJ_EDITOR=false
export GH_LOG=$work/gh.log
export GH_STATE=$work/gh-state
mkdir -p "$HOME" "$GH_STATE" "$work/bin"
printf '[user]\nname = "Fixture"\nemail = "fixture@example.invalid"\n' >"$JJ_CONFIG"
git config --global init.defaultBranch main
git init -q --bare "$work/remote.git"
git config --global url."file://$work/remote.git".insteadOf https://github.com/acme/widget.git

cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GH_LOG"
flag() {
  local want=$1
  shift
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "$want" ]; then printf '%s' "$2"; return; fi
    shift
  done
}
key() { printf '%s/%s' "$GH_STATE" "${1//\//_}"; }
case "$1 $2" in
  "pr list")
    state=$(key "$(flag --head "$@")")
    if [ -f "$state" ]; then
      printf '[{"url":"https://github.com/acme/widget/pull/%s","baseRefName":"%s"}]\n' \
        "$(flag --head "$@")" "$(cat "$state")"
    else
      echo '[]'
    fi
    ;;
  "pr create")
    flag --base "$@" >"$(key "$(flag --head "$@")")"
    echo "https://github.com/acme/widget/pull/$(flag --head "$@")"
    ;;
  "pr edit")
    base=$(flag --base "$@")
    [ -z "$base" ] || printf '%s' "$base" >"$(key "$3")"
    echo "https://github.com/acme/widget/pull/$3"
    ;;
  *) echo "gh stub: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH=$work/bin:$PATH

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}
pass() {
  printf 'ok - %s\n' "$1"
}
expect_output() {
  local log=$1 pattern=$2 message=$3
  grep -qF -- "$pattern" "$log" || { cat "$log" >&2; fail "$message"; }
}
expect_failure() {
  local log=$1
  shift
  if "$@" >"$log" 2>&1; then
    cat "$log" >&2
    fail "expected failure: $*"
  fi
}
j() {
  jj --no-pager --color=never "$@"
}
remote_at() {
  git --git-dir="$work/remote.git" rev-parse -q --verify "refs/heads/$1" || true
}
commit_id() {
  j log -r "$1" --no-graph -T commit_id
}
write() {
  printf '%s\n' "$2" >"$1"
}

repo=$work/repo
j git init --colocate "$repo" >/dev/null 2>&1
cd "$repo"
j git remote add origin https://github.com/acme/widget.git
write base.txt base
j commit -m "chore: base" >/dev/null 2>&1
j git push --named main=@- >/dev/null 2>&1
body=$work/body.md
write "$body" "Body."
write a.txt a
write scratch.txt scratch

expect_failure "$work/out" "$jj_pr" feat/a -F "$body"
expect_output "$work/out" "already in trunk" "uncommitted work in @ is refused"
pass "work still in @ is refused with a hint"

j commit -m "feat(a): add a" a.txt >/dev/null 2>&1
"$jj_pr" feat/a -F "$body" -n >"$work/out" 2>&1
expect_output "$work/out" "base     main" "dry run names trunk as base"
expect_output "$work/out" "title    feat(a): add a" "dry run takes the single commit's subject"
expect_output "$work/out" "note     @ has changes outside this PR" "dry run notes scratch.txt left in @"
[ -z "$(remote_at feat/a)" ] || fail "dry run pushed"
if grep -qv '^pr list' "$GH_LOG"; then fail "dry run called more than gh pr list"; fi
pass "dry run prints the plan and pushes nothing"

"$jj_pr" feat/a -F "$body" >"$work/out" 2>&1
[ "$(remote_at feat/a)" = "$(commit_id feat/a)" ] || fail "feat/a not pushed"
expect_output "$GH_LOG" "pr create -R acme/widget --head feat/a --base main --title feat(a): add a --body-file $body" \
  "gh pr create got the wrong arguments"
expect_output "$work/out" "https://github.com/acme/widget/pull/feat/a" "the PR URL is printed"
pass "opens a PR from a detached HEAD with --head, --base, and -R"

write b.txt b
j commit -m "feat(b): add b" b.txt >/dev/null 2>&1
"$jj_pr" feat/b -F "$body" >"$work/out" 2>&1
expect_output "$GH_LOG" "--head feat/b --base feat/a" "stacked PR is not based on its parent bookmark"
pass "a stacked PR is based on the pushed bookmark below it"

: >"$GH_LOG"
write a.txt a2
j squash --into feat/a a.txt >/dev/null 2>&1
"$jj_pr" feat/a >"$work/out" 2>&1
"$jj_pr" feat/b >"$work/out" 2>&1
[ "$(commit_id feat/a)" != "$(commit_id feat/b)" ] || fail "rerunning feat/a moved it up to @-"
[ "$(remote_at feat/a)" = "$(commit_id feat/a)" ] || fail "rewritten feat/a not pushed"
[ "$(remote_at feat/b)" = "$(commit_id feat/b)" ] || fail "rebased feat/b not pushed"
if grep -q '^pr edit' "$GH_LOG"; then fail "an update with nothing new called gh pr edit"; fi
expect_output "$work/out" "https://github.com/acme/widget/pull/feat/b" "update prints the PR URL"
pass "rerunning after a rewrite keeps each bookmark, pushes both, and leaves the PRs alone"

write c.txt c
j commit -m "feat(b): add c" c.txt >/dev/null 2>&1
"$jj_pr" feat/b -n >"$work/out" 2>&1
expect_output "$work/out" "bookmark in place" "an existing bookmark moved without -r"
expect_output "$work/out" "pass -r @- to include it" "the commit above the bookmark is not pointed out"
"$jj_pr" feat/b -r @- -F "$body" >"$work/out" 2>&1
expect_output "$work/out" "move bookmark from" "-r @- does not advance the bookmark"
[ "$(remote_at feat/b)" = "$(commit_id @-)" ] || fail "advanced feat/b not pushed"
expect_output "$GH_LOG" "pr edit feat/b -R acme/widget --body-file $body" "body was not refreshed"
pass "a commit on top is pointed out, and -r @- advances the bookmark and refreshes the body"

j new 'trunk()' >/dev/null 2>&1
write d.txt d
j commit -m "feat(d): add d" d.txt >/dev/null 2>&1
j bookmark create feat/d -r @- >/dev/null 2>&1
"$jj_pr" -F "$body" >"$work/out" 2>&1
[ "$(remote_at feat/d)" = "$(commit_id feat/d)" ] || fail "local-only feat/d not tracked and pushed"
expect_output "$work/out" "track on origin" "plan does not say it tracks the bookmark"
pass "NAME defaults to REV's bookmark, and a local-only bookmark is tracked before the push"

j new 'trunk()' >/dev/null 2>&1
write e.txt e
j commit -m "" e.txt >/dev/null 2>&1
expect_failure "$work/out" "$jj_pr" feat/e -F "$body"
expect_output "$work/out" "describe or resolve these commits first" "undescribed commit was not refused"
pass "an undescribed commit is refused before any push"

: >"$GH_LOG"
git --git-dir="$work/remote.git" update-ref refs/heads/main "$(commit_id feat/a)"
git --git-dir="$work/remote.git" update-ref -d refs/heads/feat/a
j git fetch >/dev/null 2>&1
"$jj_pr" -r feat/b >"$work/out" 2>&1
expect_output "$work/out" "retarget feat/a -> main" "plan does not show the retarget"
expect_output "$GH_LOG" "pr edit feat/b -R acme/widget --base main" "merged parent did not retarget the PR to trunk"
pass "after the parent merges, the stacked PR is retargeted to trunk"

expect_failure "$work/out" "$jj_pr" -r feat/b -t
expect_output "$work/out" "-t needs a value" "a missing flag value is not reported"
pass "a flag without its value is refused"
