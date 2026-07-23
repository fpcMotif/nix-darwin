## 2024-06-25 - Native regex for in-memory multiline strings in Bash
**Learning:** For shell scripts where a multiline string is already captured in memory (e.g. `log=$(nix build ...)`), piping it through `printf | grep | head | sed` is a massive anti-pattern that spawns multiple subprocesses. Because the string is already in memory, native bash regex `[[ "$log" =~ $re ]]` can extract substrings natively without any forks.
**Action:** Always prefer `[[ "$var" =~ $re ]]` with `${BASH_REMATCH[1]}` over subprocess pipelines for variables already in memory. Store the pattern in a variable (`local re="..."`) for compatibility with macOS Bash 3.2.

## 2024-07-23 - GitHub API `/releases?per_page=1` includes prereleases
**Learning:** The comment in `scripts/lib/auto-update.sh` claiming "GitHub floats the newest full (non-prerelease) release to .[0] of /releases" is factually incorrect. GitHub's `/releases` list includes prereleases at index 0 if they are the most recently published. As a result, the "stable" channel logic in `au_latest_github_release` was incorrectly picking up unstable prereleases (like `pr-38252-videos` for `sst/opencode`).
**Action:** Use GitHub's dedicated `/releases/latest` endpoint to reliably fetch the latest stable release, avoiding the `/releases?per_page=1` quirk entirely.
