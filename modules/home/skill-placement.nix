{ config, lib, pkgs, ... }:

let
  inherit (config.martin.agentSurface) skillTargetDirs;
  cfg = config.martin.agentSurface;

  # Another skill tool writes real directories into ~/.skillshub, so these
  # hosts stay out of skillTargetDirs: the name-based sweeps would delete them.
  # Home Manager still retires the links it placed.
  hostDirs = skillTargetDirs // {
    skillshub = ".skillshub";
    omp = ".omp/agent/managed-skills";
    omp-skills = ".omp/agent/skills";
  };

  audiences = {
    # Droid scans both ~/.factory/skills and ~/.agents/skills and flags
    # duplicate names, so pickers skip factory.
    pickers = lib.attrNames (removeAttrs skillTargetDirs [ "factory" ]);
    everywhere = [ "agents" "claude" "codex" "gemini" "skillshub" "omp" ];
    outside-claude = [ "agents" "gemini" "omp" ];
    codex-family = [ "agents" "codex" "gemini" ];
  };

  hostsOf = id: audience:
    let
      names =
        if builtins.isString audience
        then audiences.${audience} or (throw "skill ${id}: unknown audience '${audience}'")
        else audience;
    in
    map (host: lib.throwIfNot (hostDirs ? ${host}) "skill ${id}: unknown host '${host}'" host) names;

  personalRoot = ./skills/personal;
  personalPlacement = import ./skills/personal/placement.nix;
  personalAudienceIds = removeAttrs personalPlacement [ "hosts" ];
  personalIds = lib.concatLists (lib.attrValues personalAudienceIds) ++ lib.attrNames personalPlacement.hosts;
  duplicateIds = lib.filter (id: lib.count (x: x == id) personalIds > 1) (lib.unique personalIds);
  personalSkills =
    lib.throwIf (duplicateIds != [ ]) "skills/personal/placement.nix lists ${toString duplicateIds} more than once"
      (lib.concatMapAttrs
        (audience: ids: lib.genAttrs ids (id: { source = personalRoot + "/${id}"; inherit audience; }))
        personalAudienceIds
      // lib.mapAttrs (id: hosts: { source = personalRoot + "/${id}"; audience = hosts; }) personalPlacement.hosts);

  needsStandardCopy = source:
    builtins.isPath source
    && builtins.pathExists (source + "/SKILL.md")
    && lib.hasInfix "disable-model-invocation:" (builtins.readFile (source + "/SKILL.md"));
  standardCopy = id: source: pkgs.runCommandLocal "agent-skill-${id}-standard" { } ''
    mkdir -p "$out"
    cp -R "${source}/." "$out/"
    chmod -R u+w "$out"
    sed -i '/^[[:space:]]*disable-model-invocation:[[:space:]]*true[[:space:]]*$/d' "$out/SKILL.md"
  '';

  # The skill hosts each harness reads. A folder not confirmed for a harness
  # counts as not read, so its skills are absent there.
  harnessReads = {
    claude = [ "claude" ];
    codex = [ "codex" "agents" ];
    droid = [ "factory" "agents" ];
    antigravity = [ "gemini" ];
    omp = [ "omp" "omp-skills" ];
    pi = [ "pi" ];
    opencode = [ "opencode" ];
    crush = [ "crush" ];
    cursor = [ "cursor" ];
    amp = [ "xdg-agents" ];
  };

  placed = lib.mapAttrs (id: skill: lib.genAttrs (hostsOf id skill.audience) (host: hostDirs.${host})) cfg.skills;

  bundleHosts = hostsOf "bundle" cfg.bundleSkills.audience;
  idsInHost = host:
    lib.attrNames (lib.filterAttrs (_: dirsByHost: dirsByHost ? ${host}) placed)
    ++ lib.optionals (builtins.elem host bundleHosts) cfg.bundleSkills.ids
    ++ cfg.foreignSkills.${host} or [ ];
  hostIds = lib.genAttrs (lib.attrNames hostDirs) idsInHost;
  knownIds = lib.unique (lib.concatLists (lib.attrValues hostIds));

  offFor = harness:
    lib.throwIfNot (harnessReads ? ${harness}) "skillsOff: unknown harness '${harness}'"
      (cfg.skillsOff.${harness} or [ ]);
  visibility = lib.mapAttrs
    (harness: reads: lib.genAttrs knownIds (id:
      if !(lib.any (host: builtins.elem id hostIds.${host}) reads) then "absent"
      else if builtins.elem id (offFor harness) then "off"
      else "on"))
    harnessReads;
  offLinks = lib.mapAttrs
    (harness: reads: lib.concatMap
      (host: map (id: "${hostDirs.${host}}/${id}")
        (lib.filter (id: builtins.elem id hostIds.${host}) (offFor harness)))
      reads)
    harnessReads;
  links = lib.listToAttrs (lib.concatLists (lib.mapAttrsToList
    (id: dirsByHost: lib.mapAttrsToList
      (host: dir: {
        name = "${dir}/${id}";
        value =
          let source = cfg.skills.${id}.source;
          in if host != "claude" && needsStandardCopy source then standardCopy id source else source;
      })
      dirsByHost)
    placed));
in
{
  options.martin.agentSurface = {
    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          source = lib.mkOption { type = lib.types.either lib.types.path lib.types.package; };
          audience = lib.mkOption { type = lib.types.either lib.types.str (lib.types.listOf lib.types.str); };
        };
      });
      default = { };
      internal = true;
      description = "Skills linked by Home Manager. An audience is a name from skill-placement.nix or a list of host names.";
    };

    bundleSkills = {
      ids = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        internal = true;
        description = "Bundle skill ids. The agent-skills input links them; Skill visibility only records where they land.";
      };
      audience = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
        default = [ ];
        internal = true;
        description = "The audience the agent-skills input links the bundle into.";
      };
    };

    foreignSkills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      internal = true;
      description = "Per skill host, skill ids another tool installs there, so a harness can still turn them off.";
    };

    skillsOff = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      internal = true;
      description = "Per harness, skill ids that the harness's own settings turn off.";
    };

    skillPlacement = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      internal = true;
      description = "Resolved skill placement: host dirs, picker dirs, the home-relative links of every skill, and Skill visibility per harness.";
    };
  };

  config = {
    martin.agentSurface.skills = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin personalSkills;

    martin.agentSurface.skillPlacement = {
      inherit hostDirs links harnessReads visibility offLinks;
      offIds = lib.mapAttrs (_: states: lib.attrNames (lib.filterAttrs (_: state: state == "off") states)) visibility;
      pickerDirs = lib.getAttrs audiences.pickers hostDirs;
      targetsById = lib.mapAttrs (id: dirsByHost: map (dir: "${dir}/${id}") (lib.attrValues dirsByHost)) placed;
    };

    home.file = lib.mapAttrs (_: source: { inherit source; }) links // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      ".config/agent-skills/personal-manifest.json".source = pkgs.writeText "personal-manifest.json"
        (builtins.toJSON (lib.getAttrs (lib.attrNames personalSkills) config.martin.agentSurface.skillPlacement.targetsById));
    };
  };
}
