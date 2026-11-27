ctx:

let
  inherit (ctx) helpers lib darwinConfig darwinHome user guideCatalog;
  inherit (import ../../../modules/home/claude/skill-curation.nix) handInstalledPluginSkillIds;
in
[
  (helpers.assertTest "darwin-doc-lock-adapters"
    (darwinConfig.environment.etc ? "codex/requirements.toml"
      && darwinHome.xdg.configFile ? "hk/config.pkl"
      && darwinHome.home.file ? ".claude/hooks/doc-lock.sh"
      && lib.hasInfix "## Docs lock" darwinHome.home.file.".claude/CLAUDE.md".source.text)
    "host f should wire doc-lock into Codex, hk, Claude hooks, and the agent guides")

  (helpers.assertTest "darwin-cleanup-covers-every-skill-target"
    (
      let
        targetDirs = lib.attrValues darwinHome.martin.agentSurface.skillTargetDirs;
        purgeLine = lib.findFirst (lib.hasInfix "for skills_rel in ") ""
          (lib.splitString "\n" darwinHome.home.activation.cleanupLegacyDotfiles.data);
        purgedDirs = lib.splitString " " (lib.removeSuffix "; do" (lib.trim purgeLine));
      in
      lib.all (dir: builtins.elem dir purgedDirs) targetDirs
      && builtins.elem ".gemini/config/skills" targetDirs
    )
    "cleanupLegacyDotfiles should sweep every skill picker dir from the Agent surface catalog, .gemini/config/skills included")

  (helpers.assertTest "darwin-skill-visibility-states"
    (
      let visibility = darwinHome.martin.agentSurface.skillPlacement.visibility or { };
      in (visibility.codex.qa or null) == "off"
        && (visibility.codex.request-refactor-plan or null) == "off"
        && (visibility.codex.show-me or null) == "on"
        && (visibility.claude.notebooklm or null) == "off"
        && (visibility.antigravity.notebooklm or null) == "on"
        && (visibility.claude.show-me or null) == "on"
        && (visibility.omp.jj or null) == "on"
        && (visibility.claude.varlock-setup or null) == "absent"
        && lib.all
        (harness: lib.all (id: (visibility.${harness}.${id} or "absent") == "off")
          darwinHome.martin.agentSurface.skillsOff.${harness})
        (lib.attrNames darwinHome.martin.agentSurface.skillsOff)
    )
    "Skill visibility should give each harness on, off, or absent: Codex turns qa off, only Claude turns notebooklm off, omp sees jj through ~/.agents/skills, and Claude cannot see the outside-claude varlock-setup")

  (helpers.assertTest "darwin-codex-skill-off-entries"
    (
      let
        codexToml = darwinConfig.environment.etc."codex/config.toml".text;
        offEntry = path: lib.hasInfix "path = \"/Users/${user}/${path}/SKILL.md\"\nenabled = false" codexToml;
      in
      lib.all offEntry [
        ".agents/skills/qa"
        ".codex/skills/qa"
        ".agents/skills/request-refactor-plan"
        ".codex/skills/request-refactor-plan"
        ".agents/skills/review"
      ]
      && !(lib.hasInfix "migrate-to-shoehorn" codexToml)
      && !(lib.hasInfix ".codex/skills/review/" codexToml)
    )
    "the Codex config should disable each Codex off skill in every folder Codex reads that holds it, and nothing that is not installed")

  (helpers.assertTest "darwin-claude-hidden-matches-visibility"
    (
      let
        manifest = builtins.fromJSON darwinHome.home.file.".config/agent-skills/manifest.json".source.text;
        claudeOff = lib.attrNames (lib.filterAttrs (_: state: state == "off")
          (darwinHome.martin.agentSurface.skillPlacement.visibility.claude or { }));
      in
      claudeOff != [ ]
      && builtins.elem "notebooklm" claudeOff
      && lib.sort lib.lessThan (lib.unique manifest.claudeHidden) == lib.sort lib.lessThan claudeOff
    )
    "Claude's hidden list should be exactly the skills Skill visibility marks off for Claude")

  (helpers.assertTest "darwin-guide-pointers-resolve"
    (
      let
        placement = darwinHome.martin.agentSurface.skillPlacement;
        manifest = builtins.fromJSON darwinHome.home.file.".config/agent-skills/manifest.json".source.text;
        installed = lib.attrNames darwinHome.home.file;
        userOwned = [ "devv" "nix-config" ".codex/config.toml" ];
        readers = {
          claude = "claude";
          codex = "codex";
          omp = "omp";
          antigravity = "antigravity";
          general = null;
        };
        matches = regex: text: lib.concatMap (m: if builtins.isList m then [ (builtins.head m) ] else [ ]) (builtins.split regex text);
        under = prefix: path: path == prefix || lib.hasPrefix "${prefix}/" path;
        fileResolves = pointer:
          let path = lib.removeSuffix "/" (lib.removePrefix "~/" (lib.removeSuffix "." pointer));
          in lib.any (key: under key path || under path key) installed || lib.any (owned: under owned path) userOwned;
        skillResolves = harness: id:
          if harness == null then builtins.elem id (placement.idsByHost.agents or [ ])
          else (placement.visibility.${harness}.${id} or "absent") == "on"
            || (harness == "claude" && builtins.elem id (manifest.pluginProvided ++ handInstalledPluginSkillIds));
        failures = lib.concatLists (lib.mapAttrsToList
          (name: harness:
            let
              host = guideCatalog.hosts.${name};
              linkedFromStartup = guide: !(builtins.elem guide host.extras)
                || lib.hasInfix "~/${guide.target}" host.startup.content;
              text = lib.concatMapStrings (guide: guide.content) (builtins.filter linkedFromStartup host.guides);
            in
            map (p: "${name}: ${p}") (builtins.filter (p: !(fileResolves p)) (matches "(~/[A-Za-z0-9._/-]+)" text))
            ++ map (id: "${name}: `${id}` skill") (builtins.filter (id: !(skillResolves harness id)) (matches "`([a-z0-9-]+)` skill" text))
            ++ map (p: "${name}: ${p}") (matches "(/Users/[A-Za-z0-9._/-]+)" text))
          readers);
      in
      lib.warnIf (failures != [ ]) "unresolved guide pointers: ${lib.concatStringsSep ", " failures}" (failures == [ ])
    )
    "every skill and file a guide points to should be reachable by the harness that reads the guide")
]
