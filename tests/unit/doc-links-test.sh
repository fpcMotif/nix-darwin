#!/usr/bin/env bash
set -euo pipefail

root=$1

maintained_docs=$(
  cd "$root"
  find docs -type f -name '*.md' | sort
  printf '%s\n' AGENTS.md ARCHITECTURE.md GLOSSARY.md
)

# Fenced blocks and inline code spans hold examples, not links.
print_line_and_link_target() {
  awk '
    /^[ \t]*(```|~~~)/ { fenced = !fenced; next }
    fenced { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      if (match(line, /^[ \t]*\[[^]]+\]:[ \t]*/)) {
        print NR "\t" substr(line, RSTART + RLENGTH)
        next
      }
      while (match(line, /\]\([^)]*\)/)) {
        print NR "\t" substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

broken=0
checked=0
while IFS= read -r file; do
  [ -f "$root/$file" ] || {
    echo "docs: $file is missing" >&2
    broken=1
    continue
  }
  dir=$(dirname "$file")
  while IFS=$'\t' read -r line target; do
    # CommonMark allows spaces inside an angle-bracket link target.
    case $target in
      "<"*) target=${target#<}; target=${target%%>*} ;;
      *) target=${target%%[[:space:]]*} ;;
    esac
    case $target in
      "" | "#"* | mailto:* | tel:*) continue ;;
    esac
    [[ $target =~ ^[A-Za-z][A-Za-z0-9+.-]*:// ]] && continue
    path=${target%%#*}
    path=${path%%\?*}
    path=${path//%20/ }
    case $path in
      /*) resolved=$root$path ;;
      *) resolved=$root/$dir/$path ;;
    esac
    checked=$((checked + 1))
    if [ ! -e "$resolved" ]; then
      echo "$file:$line: broken link to $target" >&2
      broken=1
    fi
  done < <(print_line_and_link_target "$root/$file")
done <<<"$maintained_docs"

if [ "$broken" -ne 0 ]; then
  echo "docs: fix or remove the broken relative links above" >&2
  exit 1
fi
echo "PASS $checked relative links resolve"
