#!/usr/bin/env bash
set -euo pipefail

command -v jq &>/dev/null || exit 0

input=$(cat)

# Single jq pass — extracts all fields + computes cost in one fork
IFS=$'\t' read -r model cwd used_pct total_in total_out cost_raw < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // .cwd // ""),
    (.context_window.used_percentage // ""),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0),
    (((.context_window.total_input_tokens // 0) * 3 + (.context_window.total_output_tokens // 0) * 15) / 1000000)
  ] | @tsv'
)

# ANSI colors
reset='\033[0m'
dim='\033[2m'
green='\033[32m'
yellow='\033[33m'
red='\033[31m'
magenta='\033[35m'

# Context progress bar (pure bash, no seq/bc)
full="██████████"
empty_chars="░░░░░░░░░░"
if [[ -n "$used_pct" ]]; then
  pct_int=${used_pct%%.*}
  filled=$(( (pct_int * 10 + 50) / 100 ))
  (( filled > 10 )) && filled=10
  (( filled < 0 )) && filled=0
  empty=$(( 10 - filled ))

  if (( filled >= 8 )); then bar_color="$red"
  elif (( filled >= 6 )); then bar_color="$yellow"
  else bar_color="$green"
  fi

  bar="${bar_color}${full:0:$filled}${dim}${empty_chars:0:$empty}${reset} ${bar_color}${pct_int}%${reset}"
else
  bar="${dim}${empty_chars}${reset} ${dim}–%${reset}"
fi

# Cost (already computed by jq)
cost=""
if [[ "$cost_raw" != "0" && -n "$cost_raw" ]]; then
  if awk "BEGIN { exit !($cost_raw < 0.01) }" 2>/dev/null; then
    cost=" ${dim}|${reset} ${dim}<\$0.01${reset}"
  else
    cost=" ${dim}|${reset} ${dim}$(printf '$%.2f' "$cost_raw")${reset}"
  fi
fi

# Git branch
git_branch=""
if [[ -n "$cwd" ]] && git_out=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null); then
  git_branch="${magenta}${git_out}${reset}"
fi

# Output — %b interprets \033 escapes; user data is in the argument, not format string
printf '%b\n' "${git_branch}  ${bar}${cost}"
