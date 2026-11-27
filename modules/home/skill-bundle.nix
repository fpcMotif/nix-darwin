{ inputs, lib, config, ... }:

let
  curation = import ./claude/skill-curation.nix;
  mattpocock = import ./skill-bundle/mattpocock.nix { inherit lib inputs; };

  mattpocockRows = map
    (bucket: {
      name = "mp-${bucket}";
      input = "mattpocock-skills";
      subdir = "skills/${bucket}";
    })
    curation.mattpocockBuckets;

  sourceRows = [
    {
      name = "dotfiles-pi";
      input = "dotfiles";
      subdir = "dot_pi/agent/skills";
      nameRegex = "^web-browser$";
      explicitIds = [ "web-browser" ];
    }
    { name = "better-github-skill"; input = "better-github-skill"; subdir = "."; ids = [ "better-github-skill" ]; }
    { name = "ub-mode"; input = "ub-mode"; subdir = "."; ids = [ "ub-mode" ]; }
    { name = "impeccable"; input = "impeccable"; subdir = ".agents/skills"; ids = [ "impeccable" ]; }
    { name = "interfaces"; input = "interfaces-skills"; subdir = "skills"; ids = curation.interfacesSkillNames; }
    # Effect-TS skills: defined but not enabled globally. Effect repos get them
    # per project via templates/effect-skills/devshell.flake.nix.
    { name = "effect-ts"; input = "effect-ts-skills"; subdir = "skills"; }
  ] ++ mattpocockRows;

  rowSource = row: {
    inherit (row) input subdir;
    filter = { maxDepth = 1; }
      // lib.optionalAttrs (row ? nameRegex) { inherit (row) nameRegex; };
  };

  explicitSkills = lib.listToAttrs (lib.concatMap
    (row: map
      (id: lib.nameValuePair id { from = row.name; path = id; packages = [ ]; })
      (row.explicitIds or [ ]))
    sourceRows);

  enabledIds = mattpocock.enabledIds ++ lib.concatMap (row: row.ids or [ ]) sourceRows;

  # `link` points every target at the same store SKILL.md files. Pi de-dupes
  # skills by realpath, so the shared store paths collapse across picker dirs.
  linkTarget = dest: { enable = true; inherit dest; structure = "link"; systems = [ ]; };
in
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  options.martin.agentSurface.bundleSkills.pluginProvidedIds = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    readOnly = true;
    internal = true;
    description = "Bundle skill ids that the mattpocock Claude plugin also ships.";
  };

  config = {
    martin.agentSurface.bundleSkills = {
      ids = enabledIds ++ builtins.attrNames explicitSkills;
      audience = "pickers";
      pluginProvidedIds = mattpocock.enabledIds;
    };

    programs.agent-skills = {
      enable = true;

      sources = lib.listToAttrs (map (row: lib.nameValuePair row.name (rowSource row)) sourceRows);

      skills = {
        enable = enabledIds;
        enableAll = [ ];
        explicit = explicitSkills;
      };

      targets = lib.mapAttrs (_: linkTarget) config.martin.agentSurface.skillPlacement.pickerDirs;

      # Module default (`[ "/.system" ]`); an empty list would let a future
      # `structure = "symlink-tree"` target rsync --delete over Codex's own
      # `.system` dir. Every target is `link` today, so this is a latent guard.
      excludePatterns = [ "/.system" ];
    };
  };
}
