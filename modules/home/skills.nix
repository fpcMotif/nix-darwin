{ inputs, pkgs, ... }:

let
  filteredSource = input: subdir: nameRegex: {
    inherit input subdir;
    filter = {
      inherit nameRegex;
      maxDepth = 1;
    };
  };

  rootSkillSource = input: subdir: {
    inherit input subdir;
  };

  mkSkill = from: path: packages: {
    inherit from path packages;
  };
in
{
  imports = [
    inputs.agent-skills.homeManagerModules.default
  ];

  # Keep this module on the upstream agent-skills-nix Home Manager DSL instead of
  # hand-rolled activation scripts. See ARCHITECTURE.md#agent-skills
  # for target policy, revision notes, and citable upstream references.
  programs.agent-skills = {
    enable = true;

    sources = {
      dotfiles-pi = filteredSource "dotfiles" "dot_pi/agent/skills"
        "^(git-workflow|review|ralph-loop|web-browser)$";

      dotfiles-claude = filteredSource "dotfiles" "dot_claude/skills"
        "^(lazygit)$";

      grill-me = rootSkillSource "mattpocock-skills" "skills/productivity/grill-me";
    };

    skills = {
      # Keep every skill allowlisted explicitly. This lets Nix attach runtime
      # CLI dependencies to skills whose instructions call local tools, while
      # still avoiding `enableAll` drift from third-party sources.
      enable = [ ];
      enableAll = false;
      explicit = {
        git-workflow = mkSkill "dotfiles-pi" "git-workflow" [
          pkgs.git
          pkgs.gh
          pkgs.jq
        ];
        review = mkSkill "dotfiles-pi" "review" [
          pkgs.git
          pkgs.gh
          pkgs.jq
        ];
        lazygit = mkSkill "dotfiles-claude" "lazygit" [
          pkgs.git
          pkgs.lazygit
        ];
        ralph-loop = mkSkill "dotfiles-pi" "ralph-loop" [ ];
        web-browser = mkSkill "dotfiles-pi" "web-browser" [ ];
        grill-me = mkSkill "grill-me" "." [ ];
      };
    };

    targets = {
      # Shared Open Agent Skills registry. This is the primary Codex path and
      # is also supported by Cursor.
      agents.enable = true;

      # Tool-specific mirrors keep discovery predictable in clients that prefer
      # or require their own config root.
      claude.enable = true;
      cursor.enable = true;
      codex.enable = true;

      # Oh My Pi / Pi harness target is not an upstream default target, so keep
      # it explicit while sharing the same declarative bundle and sync logic.
      pi = {
        enable = true;
        dest = "$HOME/.pi/agent/skills";
        structure = "symlink-tree";
        systems = [ ];
      };
    };
  };
}
