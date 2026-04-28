{ inputs, ... }:

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

  enabledSkillIds = [
    "git-workflow"
    "grill-me"
    "lazygit"
    "ralph-loop"
    "review"
    "web-browser"
  ];
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

      grill-me = rootSkillSource "mattpocock-skills" "grill-me";
    };

    skills = {
      enable = enabledSkillIds;
      enableAll = false;
      explicit = { };
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
