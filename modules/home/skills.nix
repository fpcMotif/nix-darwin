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

  syncTargets = dest: {
    default = {
      inherit dest;
      enable = true;
      structure = "symlink-tree";
      systems = [ ];
    };
  };

  syncScript = dest:
    agentLib.mkSyncScript {
      inherit pkgs bundle;
      targets = syncTargets dest;
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

  home.activation.agentSkillsPi = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (syncScript "$HOME/.pi/agent/skills");

  home.activation.agentSkillsClaude = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (syncScript "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills");

  home.activation.agentSkillsShared = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (syncScript "$HOME/.agents/skills");
}
