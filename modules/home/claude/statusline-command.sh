#!/usr/bin/env bash
set -euo pipefail

command -v jq &>/dev/null || exit 0

input=$(cat)

# A whitespace IFS such as tab merges adjacent delimiters, so an empty field
# would shift every later field left; \x1f is not whitespace.
IFS=$'\x1f' read -r cwd used_pct cost_raw < <(
  printf '%s' "$input" | jq -r '[
    (.workspace.current_dir // .cwd // ""),
    (.context_window.used_percentage // ""),
    (((.context_window.total_input_tokens // 0) * 3 + (.context_window.total_output_tokens // 0) * 15) / 1000000)
  ] | map(tostring | gsub("[\n\u001f]"; " ")) | join("\u001f")'
)

reset='\033[0m'
dim='\033[2m'
green='\033[32m'
yellow='\033[33m'
red='\033[31m'
magenta='\033[35m'

context_bar() {
  local full="██████████" empty_chars="░░░░░░░░░░"
  if [[ -z "$used_pct" ]]; then
    printf '%s' "${dim}${empty_chars}${reset} ${dim}–%${reset}"
    return
  fi
  local pct_int=${used_pct%%.*}
  local filled=$(( (pct_int * 10 + 50) / 100 ))
  (( filled > 10 )) && filled=10
  (( filled < 0 )) && filled=0
  local empty=$(( 10 - filled ))
  local bar_color
  if (( filled >= 8 )); then bar_color="$red"
  elif (( filled >= 6 )); then bar_color="$yellow"
  else bar_color="$green"
  fi
  printf '%s' "${bar_color}${full:0:$filled}${dim}${empty_chars:0:$empty}${reset} ${bar_color}${pct_int}%${reset}"
}

cost_label() {
  [[ "$cost_raw" != "0" && -n "$cost_raw" ]] || return 0
  if awk "BEGIN { exit !($cost_raw < 0.01) }" 2>/dev/null; then
    printf '%s' " ${dim}|${reset} ${dim}<\$0.01${reset}"
  else
    printf '%s' " ${dim}|${reset} ${dim}$(printf '$%.2f' "$cost_raw")${reset}"
  fi
}

git_branch_label() {
  local branch
  if [[ -n "$cwd" ]] && branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null); then
    printf '%s' "${magenta}${branch}${reset}"
  fi
  return 0
}

# set -e ignores a failed substitution inside printf arguments. Here it stops a non-numeric used_percentage.
branch_label=$(git_branch_label)
bar=$(context_bar)
cost=$(cost_label)
# A `%` in a branch name would act as a directive inside the format string.
printf '%b\n' "$branch_label  $bar$cost"
