{ config, lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  # PATH tiers (CONTEXT.md), in order: an earlier tier wins every command name
  # it shares with a later one. The Nix-profile entries repeat nix-darwin's
  # base PATH on purpose: their earlier position keeps the Nix copies of
  # cargo, rustc, bun, and others ahead of user-installed ones. Check with
  # `just verify-path`.
  pathTiers = {
    # mbx's cargo shim, so plain `cargo` runs through mbx's build cache
    # (docs/adr/0016).
    shims = lib.optionals isDarwin [
      "$HOME/Library/Application Support/mbx/bin"
    ];
    # Same order as nix-darwin's base PATH (set-environment).
    nixProfiles = [
      "$HOME/.nix-profile/bin"
      "/etc/profiles/per-user/$USER/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
    ];
    userInstallers = [
      "$HOME/.local/bin"
      "/usr/local/bin"
      "$HOME/bin"
      "$HOME/.bun/bin"
      "$HOME/.cargo/bin"
      "$HOME/go/bin"
    ];
  };

  # pnpm's platform-native global dir: ~/Library on macOS, XDG data on Linux.
  pnpmHome = if isDarwin then "$HOME/Library/pnpm" else "$HOME/.local/share/pnpm";

in
{
  home.sessionPath = pathTiers.shims ++ pathTiers.nixProfiles ++ pathTiers.userInstallers;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim +Man!";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";

    BAT_THEME = "Catppuccin Macchiato";
    EZA_CONFIG_DIR = "$HOME/.config/eza";
    RANGER_LOAD_DEFAULT_RC = "FALSE";
    PNPM_HOME = pnpmHome;
    LESSKEYIN = "$HOME/.config/less/.lesskey";
    LESSHISTFILE = "$HOME/.config/less/.lesshst";
    POWERLINE_NERD_FONTS = "1";

    HOMEBREW_NO_ANALYTICS = "1";

    CDPATH = ".:$HOME:$HOME/Developer:$HOME/Downloads:$HOME/Documents";

    AGENT_BROWSER_CDP_URL = "http://localhost:9222";
    BUN_INSTALL = "$HOME/.bun";

    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    CLAUDE_CODE_NO_FLICKER = "1";
    # Baseline effort floor for any `claude` launched OUTSIDE the ai-cli.nix
    # wrappers (IDE, raw ~/.local/bin/claude, inherited shells): xhigh, never
    # max. The `claude`/`cc` wrappers `unset` this so they run full ultracode
    # (xhigh + dynamic-workflow orchestration) instead. See modules/home/ai-cli.nix.
    CLAUDE_CODE_EFFORT_LEVEL = "xhigh";

    OBSIDIAN_VAULT = "$HOME/Documents/obsidian";
    TERMINFO = "$HOME/.terminfo";
  } // lib.optionalAttrs isDarwin {
    # The login shell modules/darwin/shell.nix writes for this user: the
    # system profile path in /etc/shells, not a store path that changes.
    SHELL =
      if config.martin.shell.interactive == "fish"
      then "/run/current-system/sw/bin/fish"
      else "/bin/zsh";
  };
}
