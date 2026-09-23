{ config, lib, pkgs, ... }:

let
  guideCatalog = import ./agent-instructions/guides.nix { inherit lib pkgs; };
  modelRouting = import ../shared/agent-model-routing.nix { inherit lib; };
  toml = pkgs.formats.toml { };
  yaml = pkgs.formats.yaml { };
  personalSkills = builtins.fromJSON (builtins.readFile ./skills/personal/manifest.json);
  personalFiles = builtins.listToAttrs (lib.concatLists (lib.mapAttrsToList
    (name: targets: map
      (target: {
        name = target;
        value = ./skills/personal + "/${name}";
      })
      targets)
    personalSkills));
  files = {
    "${guideCatalog.hosts.general.startup.target}" = guideCatalog.hosts.general.startup.source;
    "${guideCatalog.hosts.general.development.target}" = guideCatalog.hosts.general.development.source;
    "${guideCatalog.hosts.codex.startup.target}" = guideCatalog.hosts.codex.startup.source;
    "${guideCatalog.hosts.codex.development.target}" = guideCatalog.hosts.codex.development.source;
    ".codex/guidance/setup.md" = ./agent-instructions/codex/guidance/setup.md;
    ".codex/fast.config.toml" = toml.generate "codex-fast.config.toml"
      modelRouting.adapters.codex.profiles.fast;
    ".codex/fast-low.config.toml" = toml.generate "codex-fast-low.config.toml"
      modelRouting.adapters.codex.profiles.fast-low;
    ".codex/plan.config.toml" = toml.generate "codex-plan.config.toml"
      modelRouting.adapters.codex.profiles.plan;
    ".codex/deep.config.toml" = toml.generate "codex-deep.config.toml"
      modelRouting.adapters.codex.profiles.deep;
    ".config/agent-routing/omp.yml" = yaml.generate "omp-routing.yml"
      modelRouting.adapters.omp.normal;
    ".config/agent-routing/omp-economy.yml" = yaml.generate "omp-economy.yml"
      modelRouting.adapters.omp.economy;
    ".config/agent-routing/README.md" = ../../config/omp/README.md;
    "${guideCatalog.hosts.omp.startup.target}" = guideCatalog.hosts.omp.startup.source;
    "${guideCatalog.hosts.omp.development.target}" = guideCatalog.hosts.omp.development.source;
    "${guideCatalog.hosts.omp.humanDocuments.target}" = guideCatalog.hosts.omp.humanDocuments.source;
    ".omp/agent/agents/codex-plan-deployer.md" = ./agent-instructions/omp/agent/agents/codex-plan-deployer.md;
    ".omp/agent/agents/codex-spark-worker.md" = ./agent-instructions/omp/agent/agents/codex-spark-worker.md;
    ".omp/agent/agents/designer.md" = ./agent-instructions/omp/agent/agents/designer.md;
    ".omp/agent/agents/oracle.md" = ./agent-instructions/omp/agent/agents/oracle.md;
    ".config/agent-skills/personal-manifest.json" = ./skills/personal/manifest.json;
  } // personalFiles;
  managedPaths = builtins.attrNames files;
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.file = lib.mapAttrs (_: source: { inherit source; }) files;

  # Codex writes model, reasoning, project-trust, and UI state here. Keep this
  # user layer writable while Nix supplies lower-precedence defaults in /etc.
  home.activation.ensureWritableCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="${config.home.homeDirectory}/.codex/config.toml"
    migration_marker='# nix-config: migrate legacy full config after /etc defaults activate'
    replace_store_link=false
    migrate_legacy_file=false
    if [ -L "$target" ]; then
      resolved="$(${pkgs.coreutils}/bin/readlink -f "$target" || true)"
      case "$resolved" in /nix/store/*) replace_store_link=true ;; esac
    elif [ -f "$target" ] && ${pkgs.gnugrep}/bin/grep -qxF "$migration_marker" "$target"; then
      migrate_legacy_file=true
    fi

    if [ "$replace_store_link" = true ] || [ "$migrate_legacy_file" = true ] || { [ ! -e "$target" ] && [ ! -L "$target" ]; }; then
      if [ -n "''${DRY_RUN:-}" ]; then
        echo "codex: would create writable user overrides at $target"
      else
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
        next="$target.next"
        ${pkgs.coreutils}/bin/printf '%s\n' \
          '# Writable Codex user overrides. Nix defaults live in /etc/codex/config.toml.' \
          > "$next"
        if [ "$migrate_legacy_file" = true ]; then
          ${pkgs.gawk}/bin/awk '
            /^\[/ { exit }
            /^(model|model_reasoning_effort|service_tier) = / { print }
          ' "$target" >> "$next"
        fi
        ${pkgs.coreutils}/bin/mv -f "$next" "$target"
        ${pkgs.coreutils}/bin/chmod u+rw "$target"
        echo "codex: created writable user override file"
      fi
    fi
  '';

  # Archive existing files before Home Manager checks ownership. Never discard
  # a native app's changes, including a symlink replaced since the last switch.
  home.activation.backupAgentInstructions = lib.hm.dag.entryBefore [ "cleanupLegacyDotfiles" "checkLinkTargets" ] ''
    agent_backup=""
    for relative in ${lib.escapeShellArgs managedPaths}; do
      target="${config.home.homeDirectory}/$relative"
      if [ ! -e "$target" ] && [ ! -L "$target" ]; then continue; fi
      if [ -L "$target" ]; then
        resolved="$(${pkgs.coreutils}/bin/readlink -f "$target" || true)"
        case "$resolved" in /nix/store/*) continue ;; esac
      fi
      if [ -n "''${DRY_RUN:-}" ]; then
        echo "agent-instructions: would archive $target before linking"
        continue
      fi
      if [ -z "$agent_backup" ]; then
        backup_root="${config.home.homeDirectory}/.local/state/nix-agent-backups"
        ${pkgs.coreutils}/bin/mkdir -p "$backup_root"
        agent_backup="$(${pkgs.coreutils}/bin/mktemp -d "$backup_root/instructions.XXXXXXXX")"
      fi
      ${pkgs.coreutils}/bin/mkdir -p "$agent_backup/$(${pkgs.coreutils}/bin/dirname "$relative")"
      ${pkgs.coreutils}/bin/mv -- "$target" "$agent_backup/$relative"
      echo "agent-instructions: archived $relative in $agent_backup"
    done
  '';
}
