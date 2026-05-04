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

  # `link` makes every target a tree of `home.file` symlinks pointing at the
  # same `/nix/store/...-agent-skills-bundle/<skill>/SKILL.md`. Pi's loader
  # de-duplicates discovered skills by `realpath`, so identical store paths
  # collapse silently — no more "skill conflict" warnings between
  # ~/.claude/skills, ~/.pi/agent/skills, and ~/.agents/skills.
  #
  # Trade-off: targets become read-only nix-store-backed trees. That is the
  # explicit policy here — every skill is declared in this file. If an agent
  # wants to write `/.system` or interactive `/skills` output into its skills
  # root, switch its target back to `symlink-tree`.
  linkTarget = dest: {
    enable = true;
    inherit dest;
    structure = "link";
    systems = [ ];
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

    # All targets use `structure = "link"` with static $HOME-relative paths so
    # the upstream module routes through `home.file` instead of an rsync'd
    # symlink-tree. That guarantees every agent's skill files share a single
    # nix-store realpath and pi's loader dedupes them silently.
    targets = {
      # Shared Open Agent Skills registry. Primary path for Codex; also
      # discovered natively by Pi and Cursor.
      agents = linkTarget ".agents/skills";

      # Tool-specific mirrors for clients that prefer their own config root.
      claude = linkTarget ".claude/skills";
      cursor = linkTarget ".cursor/skills";
      codex = linkTarget ".codex/skills";

      # Oh My Pi / Pi harness target (custom, not in upstream defaults).
      pi = linkTarget ".pi/agent/skills";
    };

    # `link` populates targets through `home.file`, which never deletes paths
    # outside the declared set, so the upstream rsync exclude has no effect
    # here. Leaving this empty documents the intent: every file under each
    # target is owned by Nix.
    excludePatterns = [ ];
  };
}
