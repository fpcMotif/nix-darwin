# Autoresearch Ideas

- The recent Agent Skills and hotkeys metrics are saturated. Avoid another narrow wording metric unless a fresh code/doc audit finds a real contradiction a maintainer would trip over.
- Prefer the next target to broaden beyond Agent Skills: audit generated config docs and behavioral assertions for zsh, git, tmux, yazi, prompt, and editor modules.
- If adding coverage, measure only active Nix-managed behavior that checks can evaluate, such as managed files, activation scripts, or generated config fragments; do not enumerate every upstream app default.
- Revisit `statix.toml` only if Home Manager dotted assignments become harder to scan; the current `repeated_keys` opt-out remains justified.
