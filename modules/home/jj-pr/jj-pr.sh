usage() {
  cat <<'EOF'
Usage: jj pr [NAME] [-r REV] [-F FILE] [-t TITLE] [-B BASE] [--draft] [-n]

Push REV under bookmark NAME, then open its GitHub pull request or update the
open one. Rerun it after every rewrite; it pushes and updates again.

  NAME           PR bookmark. Defaults to the one bookmark already on REV.
  -r REV         Head commit of the PR. Defaults to NAME's bookmark when it
                 exists, else @-. Pass -r to move an existing bookmark forward.
  -F FILE        PR body. Required to open; replaces the body on update.
  -t TITLE       PR title. Defaults to REV's subject when the PR has one commit.
  -B BASE        Base branch. Defaults to the nearest pushed bookmark below REV,
                 else trunk. An open PR is retargeted to it.
  --draft        Open as a draft.
  -n, --dry-run  Print the plan and the diff to read. Push nothing.
EOF
}

die() {
  printf 'jj pr: %s\n' "$1" >&2
  exit 1
}
j() {
  jj --no-pager --color=never "$@"
}
commit_ids() {
  j log -r "$1" --no-graph -T 'commit_id ++ "\n"'
}
line_count() {
  if [ -z "$1" ]; then echo 0; else wc -l <<<"$1" | tr -d ' '; fi
}

name="" rev="" body="" title="" base="" rev_set=false title_set=false draft=false dry_run=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    -r | -F | -t | -B)
      [ "$#" -ge 2 ] || die "$1 needs a value"
      case "$1" in
        -r) rev=$2 rev_set=true ;;
        -F) body=$2 ;;
        -t) title=$2 title_set=true ;;
        -B) base=$2 ;;
      esac
      shift 2
      ;;
    --draft) draft=true; shift ;;
    -n | --dry-run) dry_run=true; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
    *)
      [ -z "$name" ] || { usage >&2; exit 2; }
      name=$1
      shift
      ;;
  esac
done
[ -z "$body" ] || [ -f "$body" ] || die "no body file at $body"

remote=$(j config get git.push 2>/dev/null) || remote=origin
url=$(git --git-dir "$(j git root)" config --get "remote.$remote.url") || die "no remote named $remote"
case "$url" in
  *github.com[:/]*) ;;
  *) die "remote $remote is not on GitHub: $url" ;;
esac
repo=${url#*github.com}
repo=${repo#[:/]}
repo=${repo%/}
repo=${repo%.git}
[[ "$repo" =~ ^[^/]+/[^/]+$ ]] || die "cannot read owner/repo from $url"
on_remote() {
  [ -n "$(commit_ids "remote_bookmarks(exact:\"$1\", exact:\"$remote\")")" ]
}

if ! $rev_set; then
  rev=@-
  if [ -n "$name" ] && [ -n "$(commit_ids "bookmarks(exact:\"$name\")")" ]; then
    rev=$name
  fi
fi
head_id=$(commit_ids "$rev") || die "cannot resolve $rev"
[ "$(line_count "$head_id")" -eq 1 ] || die "$rev must name exactly one commit"

trunk_id=$(commit_ids 'trunk()')
trunk_name=$(j log -r 'trunk()' --no-graph \
  -T "remote_bookmarks.filter(|b| b.remote() == \"$remote\").map(|b| b.name()).join(\" \")")
trunk_name=${trunk_name%% *}

[ -n "$(commit_ids "trunk()..$head_id")" ] ||
  die "$rev is already in trunk. Commit the work out of @ first (jj commit), or pass -r"
unready=$(j log -r "(trunk()..$head_id) & (description(exact:\"\") | conflicts())" --no-graph \
  -T 'change_id.short(8) ++ "\n"')
[ -z "$unready" ] || die "describe or resolve these commits first: ${unready//$'\n'/ }"

if [ -z "$name" ]; then
  name=$(j log -r "$head_id" --no-graph -T 'local_bookmarks.map(|b| b.name()).join(" ")')
  case "$name" in
    "") die "name the PR bookmark: jj pr NAME" ;;
    *" "*) die "$rev has several bookmarks ($name); name one" ;;
  esac
fi

at=$(commit_ids "bookmarks(exact:\"$name\")")
if [ -z "$at" ]; then
  action=create
elif [ "$(line_count "$at")" -gt 1 ]; then
  die "bookmark $name is conflicted; resolve it with jj bookmark set"
elif [ "$at" = "$head_id" ]; then
  action=keep
elif [ -n "$(commit_ids "$at & ::$head_id")" ]; then
  action=move
else
  die "bookmark $name is at ${at:0:12}, not below $rev; move it yourself with jj bookmark move"
fi
track=false
if [ "$action" != create ] && ! on_remote "$name"; then
  track=true
fi

if [ -z "$base" ]; then
  while read -ra candidates; do
    for candidate in "${candidates[@]}"; do
      if [ "$candidate" != "$name" ] && on_remote "$candidate"; then
        base=$candidate
        break 2
      fi
    done
  done < <(j log -r "(trunk()..$head_id-) & bookmarks()" --no-graph \
    -T 'local_bookmarks.map(|b| b.name()).join(" ") ++ "\n"')
  base=${base:-$trunk_name}
  [ -n "$base" ] || die "found no trunk branch on $remote; pass -B BASE"
fi
if [ "$base" = "$trunk_name" ]; then
  base_id=$trunk_id
else
  base_id=$(commit_ids "bookmarks(exact:\"$base\")")
  [ -n "$base_id" ] || base_id=$(commit_ids "remote_bookmarks(exact:\"$base\", exact:\"$remote\")")
  [ "$(line_count "$base_id")" -eq 1 ] || die "cannot resolve base bookmark $base"
fi

commits=$(j log -r "$base_id..$head_id" --no-graph \
  -T 'change_id.short(8) ++ " " ++ description.first_line() ++ "\n"')
count=$(line_count "$commits")
[ "$count" -gt 0 ] || die "nothing between $base and $rev"
if ! $title_set && [ "$count" -eq 1 ]; then
  title=$(j log -r "$head_id" --no-graph -T 'description.first_line()')
fi

pr=$(gh pr list -R "$repo" --head "$name" --state open --json url,baseRefName)
pr_url=$(jq -r '.[0].url // empty' <<<"$pr")
pr_base=$(jq -r '.[0].baseRefName // empty' <<<"$pr")

case $action in
  create) bookmark_plan="create bookmark" ;;
  move) bookmark_plan="move bookmark from ${at:0:12}" ;;
  keep) bookmark_plan="bookmark in place" ;;
esac
if $track; then
  bookmark_plan="$bookmark_plan, track on $remote"
fi
if [ -z "$pr_url" ]; then
  pr_plan="open new"
elif [ "$pr_base" != "$base" ]; then
  pr_plan="update $pr_url, retarget $pr_base -> $base"
else
  pr_plan="update $pr_url"
fi
printf 'repo     %s\nhead     %s -> %s (%s)\nbase     %s\ntitle    %s\npr       %s\ncommits\n' \
  "$repo" "$name" "${head_id:0:12}" "$bookmark_plan" "$base" "${title:-(pass -t TITLE)}" "$pr_plan"
while IFS= read -r commit; do
  printf '  %s\n' "$commit"
done <<<"$commits"
printf 'diff     jj diff --from %s --to %s\n' "${base_id:0:12}" "${head_id:0:12}"
if [ -n "$(commit_ids "@ & ~empty() & ~::$head_id")" ]; then
  printf 'note     @ has changes outside this PR\n'
fi
if ! $rev_set && [ "$rev" = "$name" ] && [ -n "$(commit_ids "@- & $head_id:: & ~$head_id")" ]; then
  printf 'note     @- is above %s; pass -r @- to include it\n' "$name"
fi
if $dry_run; then
  exit 0
fi

if [ -z "$pr_url" ]; then
  [ -n "$body" ] || die "opening a PR needs a body: -F FILE"
  [ -n "$title" ] || die "the PR has $count commits; pass -t TITLE"
fi

if [ "$action" = move ]; then
  j bookmark move "exact:$name" --to "$head_id"
fi
if $track; then
  j bookmark track "exact:$name" --remote "exact:$remote"
fi
if [ "$action" = create ]; then
  j git push --remote "$remote" --named "$name=$head_id"
else
  j git push --remote "$remote" --bookmark "exact:$name"
fi

if [ -z "$pr_url" ]; then
  create=(pr create -R "$repo" --head "$name" --base "$base" --title "$title" --body-file "$body")
  if $draft; then
    create+=(--draft)
  fi
  gh "${create[@]}"
else
  edit=()
  if [ -n "$body" ]; then
    edit+=(--body-file "$body")
  fi
  if $title_set; then
    edit+=(--title "$title")
  fi
  if [ "$pr_base" != "$base" ]; then
    edit+=(--base "$base")
  fi
  if [ "${#edit[@]}" -gt 0 ]; then
    gh pr edit "$name" -R "$repo" "${edit[@]}"
  else
    printf '%s\n' "$pr_url"
  fi
fi
