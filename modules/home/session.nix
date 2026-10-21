{ lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  # Repeat nix-darwin's base PATH entries ahead of userInstallers so Nix-built
  # toolchains win over user-installed copies. Verify with just verify-path.
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
    # Baseline effort floor for every `claude` launched from a shell, the
    # ai-cli.nix `claude`/`cc` wrappers included: medium (Claude's recommended default).
    CLAUDE_CODE_EFFORT_LEVEL = "medium";

    OBSIDIAN_VAULT = "$HOME/Documents/obsidian";
    TERMINFO = "$HOME/.terminfo";
  } // lib.optionalAttrs isDarwin {
    SHELL = "/bin/zsh";
  };
}
