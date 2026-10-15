{ config, lib, pkgs, ... }:

let
  cfg = config.martin.agentSurface;
  hookSpec = lib.types.attrsOf lib.types.str;
in
{
  options.martin.agentSurface = {
    skillTargetDirs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      internal = true;
      description = "Home-relative skill picker dirs, shared by agent-skills targets and every sweep.";
      default = {
        agents = ".agents/skills";
        claude = ".claude/skills";
        cursor = ".cursor/skills";
        codex = ".codex/skills";
        xdg-agents = ".config/agents/skills";
        crush = ".config/crush/skills";
        factory = ".factory/skills";
        opencode = ".config/opencode/skills";
        pi = ".pi/agent/skills";
        # Antigravity CLI (`agy`) and Desktop scan this dir globally.
        gemini = ".gemini/config/skills";
      };
    };

    guideSections = {
      startup = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        internal = true;
        description = "Sections appended to every host's startup guide.";
      };
      development = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        internal = true;
        description = "Sections appended to every host's development guide.";
      };
    };

    guideCatalog = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      internal = true;
      description = "The rendered Agent guides for every host, evaluated once.";
    };

    claudeHooks = {
      add = lib.mkOption {
        type = lib.types.listOf hookSpec;
        default = [ ];
        internal = true;
        description = "Claude Code hooks the settings reconciler adds.";
      };
      remove = lib.mkOption {
        type = lib.types.listOf hookSpec;
        default = [ ];
        internal = true;
        description = "Claude Code hooks the settings reconciler removes.";
      };
    };

    codexRequirements = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = "TOML for /etc/codex/requirements.toml; empty writes no file.";
    };
  };

  config.martin.agentSurface.guideCatalog = import ./agent-instructions/guides.nix {
    inherit lib pkgs;
    startupSections = cfg.guideSections.startup;
    developmentSections = cfg.guideSections.development;
  };
}
