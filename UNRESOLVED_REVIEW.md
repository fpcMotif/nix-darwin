# Unresolved review items

These items were reviewed but not merged because confidence was not high enough for this pass.

- `get best part and merge to my setup nix/users/shared/opencode.nix`: contains a Home Manager activation script that clones `obra/superpowers` from the network and rewrites OpenCode plugin/skills paths. Needs a pure Nix or explicitly opt-in design before merging.
- `get best part and merge to my setup nix/users/shared/.config/claude/settings.json`: grants broad Claude permissions and enables project MCP servers/plugins. Needs security review before Nix owns `~/.claude/settings.json`.
- `get best part and merge to my setup nix/users/shared/.config/codex/config.toml`: includes user-specific trusted project paths and model choices. Needs Martin-specific paths and policy before merging.
- `mimate and migae the good prace setup of dotfiles config in a nix way/`: large dotfiles dump. Needs tool-by-tool migration with Home Manager ownership guards; do not bulk import.
- `nixosConfigurations.vm-aarch64-utm`: scaffold added from `references/nixos-config-mitchellh`, but not build-validated here because this environment has no `nix` command.
