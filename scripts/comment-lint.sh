#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname "$0")/.." >/dev/null && pwd -P)
doc_lock="$root/modules/home/doc-lock/doc-lock.sh"

mode=all
if [ "${1:-}" = "--candidates" ]; then
  mode=candidates
  shift
fi

if [ "$#" -eq 0 ]; then
  files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(find "$root" \
    \( -name .git -o -name .jj -o -name 'result*' -o -name node_modules -o -name references -o -name .claude \) -prune \
    -o -type f -name '*.nix' -print | sort)
else
  files=("$@")
fi

jq_lint='
def stem:
  if length >= 4 then sub("s$"; "") else . end;

def stopword:
  IN(
    "the", "and", "for", "with", "from", "that", "this", "not", "are", "was",
    "were", "have", "has", "had", "into", "only", "when", "all", "use", "uses",
    "used", "via", "per", "let", "rec", "true", "false", "null", "pkgs", "lib",
    "config", "options", "types", "mkif", "mkoption", "mkforce", "mkdefault",
    "mkmerge", "inherit", "import"
  );

def words:
  gsub("(?<a>[A-Z]+)(?<b>[A-Z][a-z])"; "\(.a) \(.b)")
  | gsub("(?<a>[a-z0-9])(?<b>[A-Z])"; "\(.a) \(.b)")
  | ascii_downcase
  | [scan("[a-z]{3,}") | stem | select(stopword | not)]
  | unique;

def name_words($line):
  ($line | sub("#.*"; "") | sub("^\\s+"; "")) as $code
  | if ($code | test("^[a-zA-Z0-9_.\"-]+\\s*=")) then
      ($code | sub("\\s*=.*"; "") | words)
    elif ($code | test("^[a-zA-Z0-9_.-]+\\s*:")) then
      ($code | sub("\\s*:.*"; "") | words)
    else
      []
    end;

def group_blocks($lines):
  reduce .[] as $c ([];
    ($c.range.start.line) as $s
    | ($c.range.end.line) as $e
    | ($c.range.start.column) as $sc
    | ($c.range.end.column) as $ec
    | ((($lines[$s] // "")[:$sc] | test("\\S")) or (($lines[$e] // "")[$ec:] | test("\\S"))) as $inline
    | if (length > 0) and (.[-1].inline | not) and ($inline | not) and ($s == .[-1].end + 1) then
        .[-1].end = $e
        | .[-1].text += "\n" + $c.text
      else
        . + [{start: $s, end: $e, inline: $inline, text: $c.text}]
      end);

($raw | split("\n")) as $lines
| (.comments | group_blocks($lines)) as $blocks
| reduce $blocks[] as $b ({hard: [], candidates: []};
    ($b.end - $b.start + 1) as $n
    | "\($path):\($b.start + 1)-\($b.end + 1)" as $loc
    | ($lines[$b.end + 1] // "") as $next
    | ($b.text
       | gsub("(^|\\n)\\s*(#|//|/\\*+|\\*+/|\\*)\\s?"; " ")
       | gsub("\\s+"; " ")
       | sub("^\\s+"; "")
       | sub("\\s+$"; "")) as $clean
    | ($next | sub("^\\s+"; "") | sub("\\s+$"; "")) as $next_trim
    | (if $n > 3 then ["over 3 lines (\($n))"] else [] end
       + if ($b.text | test("\\b20[0-9]{2}-[01][0-9](-[0-3][0-9])?\\b")) then ["date stamp"] else [] end
       + if ($b.inline | not) and ($next | test("^\\s*([})\\];]+|\\u0027\\u0027+)?\\s*$")) then ["orphan comment"] else [] end
      ) as $hard_reasons
    | (if ($b.text | test("\\b(retired|used to|no longer|re-enabled|previously|formerly)\\b|\\(was\\b"; "i"))
       then ["history words"] else [] end) as $hist_reasons
    | (if ($b.inline | not) then
         (($clean | words) as $cw
          | (name_words($next)) as $nw
          | [$cw[] | select(. as $w | $nw | index($w))])
       else [] end) as $shared
    | ($hist_reasons
       + (if ($shared | length) > 0 then ["shares words with next line (\($shared | join(", ")))"] else [] end)
      ) as $cand_reasons
    | if ($hard_reasons | length) > 0 then
        .hard += ["\($loc)\t\($hard_reasons | join(", "))\t\($clean)"]
      else . end
    | if ($cand_reasons | length) > 0 then
        .candidates += ["\($loc)\t\($cand_reasons | join("; "))\tcode: \($next_trim)\tcomment: \($clean)"]
      else . end)
'

hard_out=()
cand_out=()

if [ "${#files[@]}" -gt 0 ]; then
  while IFS= read -r parsed; do
    [ -n "$parsed" ] || continue
    f=$(jq -r 'select((.comments | length) > 0) | .path' <<<"$parsed")
    [ -n "$f" ] || continue
    rel=${f#"$root/"}
    res=$(jq -r --rawfile raw "$f" --arg path "$rel" "$jq_lint | (.hard[] | \"HARD\t\" + .), (.candidates[] | \"CAND\t\" + .)" <<<"$parsed")
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "$line" in
        HARD$'\t'*) hard_out+=("${line#HARD$'\t'}") ;;
        CAND$'\t'*) cand_out+=("${line#CAND$'\t'}") ;;
      esac
    done <<<"$res"
  done < <(DOC_LOCK_OFF=1 "$doc_lock" parse "${files[@]}")
fi

if [ "$mode" = candidates ]; then
  if [ "${#cand_out[@]}" -gt 0 ]; then
    printf '%s\n' "${cand_out[@]}"
  fi
  exit 0
fi

print_section() {
  local title=$1
  shift
  echo "$title"
  if [ "$#" -gt 0 ]; then
    printf '  %s\n' "$@"
  else
    echo "  none"
  fi
}

print_section "Hard fail:" ${hard_out[@]+"${hard_out[@]}"}
print_section "Candidate list:" ${cand_out[@]+"${cand_out[@]}"}

[ "${#hard_out[@]}" -eq 0 ]
