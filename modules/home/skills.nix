{ lib, pkgs, inputs, currentSystem ? pkgs.stdenv.hostPlatform.system, ... }:

let
  agentLib = inputs.agent-skills.lib.agent-skills;

  filteredSource = path: subdir: nameRegex: {
    inherit path subdir;
    filter = {
      inherit nameRegex;
      maxDepth = 1;
    };
  };

  singleSkillSource = path: subdir: {
    inherit path subdir;
    filter.maxDepth = 0;
  };

  sources = {
    dotfiles-pi = filteredSource inputs.dotfiles "dot_pi/agent/skills"
      "^(git-workflow|review|ralph-loop|web-browser)$";
    dotfiles-claude = filteredSource inputs.dotfiles "dot_claude/skills"
      "^(lazygit)$";

    grill-me = singleSkillSource inputs.mattpocock-skills "grill-me";
  };

  enabledSkillIds = [
    "git-workflow"
    "grill-me"
    "lazygit"
    "ralph-loop"
    "review"
    "web-browser"
  ];

  bundle =
    let
      catalog = agentLib.discoverCatalog sources;
      allowlist = agentLib.allowlistFor {
        inherit catalog sources;
        enable = enabledSkillIds;
        enableAll = false;
      };
      selection = agentLib.selectSkills {
        inherit catalog allowlist sources;
        skills = { };
      };
    in
    agentLib.mkBundle {
      inherit pkgs selection;
      name = "martin-agent-skills-bundle";
    };

  syncTargets = {
    pi = {
      dest = "$HOME/.pi/agent/skills";
      enable = true;
      structure = "symlink-tree";
      systems = [ ];
    };
    claude = {
      dest = "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills";
      enable = true;
      structure = "symlink-tree";
      systems = [ ];
    };
    shared = {
      dest = "$HOME/.agents/skills";
      enable = true;
      structure = "symlink-tree";
      systems = [ ];
    };
  };

  syncScript = agentLib.mkSyncScript {
    inherit pkgs bundle;
    targets = syncTargets;
    system = currentSystem;
    excludePatterns = agentLib.defaultExcludePatterns;
  };
in
{
  # Known but intentionally omitted until their source and name are verified:
  # agent-browser, ast-grep, crush, doc, every-team-compounding, figma,
  # find-skills, gh-address-comments, gh-fix-ci, github-mcp, linear,
  # manim-skill, mgrep, modern-bash, notebooklm, oracle, qmd, remotion,
  # stitch-mcp.

  home.activation.agentSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] syncScript;
}
