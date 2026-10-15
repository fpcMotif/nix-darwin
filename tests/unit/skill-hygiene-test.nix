{ inputs, pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs; };

  bucketIds = bucket:
    let root = inputs.mattpocock-skills + "/skills/${bucket}";
    in builtins.attrNames (lib.filterAttrs
      (name: type:
        type == "directory" && builtins.pathExists (root + "/${name}/SKILL.md"))
      (builtins.readDir root));

  # The promoted buckets claude.nix discovers from.
  upstreamIds = lib.unique (lib.concatMap bucketIds [ "engineering" "productivity" ]);

  # RESTATED, not imported — must match modules/home/claude.nix by hand.
  disabled = [ "grill-me" ];
  leanExcluded = [ ];
  vendored = [ "browser-checks" "jj" "setup-ts-deep-modules" ];

  claudeNix = builtins.readFile (self + "/modules/home/claude.nix");

  vendoredOnDisk = builtins.attrNames (lib.filterAttrs
    (name: type:
      type == "directory"
      && builtins.pathExists (self + "/modules/home/skills/${name}/SKILL.md"))
    (builtins.readDir (self + "/modules/home/skills")));

  sorted = lib.sort (a: b: a < b);
  personalRoot = self + "/modules/home/skills/personal";
  personalManifest = builtins.fromJSON (builtins.readFile (personalRoot + "/manifest.json"));
  personalIds = builtins.attrNames personalManifest;
  personalTargets = lib.concatLists (builtins.attrValues personalManifest);
  personalDirs = builtins.attrNames (lib.filterAttrs (_: type: type == "directory")
    (builtins.readDir personalRoot));
in
helpers.testSuite "skill-hygiene" (
  # 1. Every exclusion term must still name a live upstream skill so upstream
  #    renames do not leave silent no-ops in the exclusion lists.
  (map
    (id: helpers.assertTest "skill-hygiene-exclusion-live-${id}"
      (builtins.elem id upstreamIds)
      "exclusion list names '${id}', which is missing from promoted mattpocock-skills buckets — delete the entry or fix the typo")
    (disabled ++ leanExcluded))

  # 2. A vendored fork must not shadow a promoted upstream skill. Both would
  #    write the same picker path, which is a conflicting-definition eval error
  #    thrown far from its cause.
  ++ (map
    (id: helpers.assertTest "skill-hygiene-vendored-not-upstream-${id}"
      (!(builtins.elem id upstreamIds))
      "vendored skill '${id}' collides with a promoted upstream bucket id; if upstream promoted it, retire the fork instead")
    vendored)

  ++ [
    (helpers.assertTest "skill-hygiene-personal-source-complete"
      (personalIds != [ ] && sorted personalDirs == sorted personalIds
      && lib.all
        (id:
          builtins.pathExists (personalRoot + "/${id}/SKILL.md")
          && builtins.readFile (personalRoot + "/${id}/SKILL.md") != ""
          && personalManifest.${id} != [ ])
        personalIds)
      "every personal skill must have a nonempty source and at least one declared target")

    (helpers.assertTest "skill-hygiene-personal-target-ownership"
      (builtins.length personalTargets == builtins.length (lib.unique personalTargets)
      && lib.all
        (target:
          !(lib.hasPrefix "/" target)
          && !(builtins.elem ".." (lib.splitString "/" target))
          && !(lib.hasInfix "/plugins/" target)
          && !(lib.hasInfix "/.system" target))
        personalTargets)
      "personal skill targets must be unique home-relative paths outside native plugin and system-skill directories")

    (helpers.assertTest "skill-hygiene-ste80-targets"
      (personalManifest ? ste80
      && builtins.elem ".agents/skills/ste80" personalManifest.ste80
      && !(lib.any (target: lib.hasPrefix ".claude/" target) personalManifest.ste80))
      "ste80 needs its .agents copy, which the non-Claude guides load by path. It needs no Claude copy, because Claude's Writing section already covers it.")

    # 3. claude.nix derives localSkillIds from readDir, so this checks that a
    #    new modules/home/skills/<id> directory is added deliberately.
    (helpers.assertTest "skill-hygiene-vendored-dirs-match"
      (sorted vendoredOnDisk == sorted vendored)
      "modules/home/skills/ holds ${toString vendoredOnDisk} but this test expects ${toString vendored} — add the new skill here deliberately")

    # 4. A transform on a mattpocock skill shadows the plugin copy and
    #    duplicates the entry in the skill picker.
    (helpers.assertTest "skill-hygiene-no-mattpocock-transform"
      (!(lib.hasInfix "appendKarpathy" claudeNix)
      && !(lib.hasInfix "transformedMattpocockSkills" claudeNix))
      "a mattpocock skill regained a Nix `transform`; forks shadow the plugin copy and re-create the duplicate this change removed")

    # 5. Upstream promoting a skill that also matches an in-progress regex
    #    makes discoverCatalog throw on a duplicate id.
    (helpers.assertTest "skill-hygiene-no-in-progress-source"
      (!(lib.hasInfix "mp-in-progress" claudeNix))
      "the mp-in-progress source was re-added; teach lives in productivity/ now, so its regex matches nothing and risks a duplicate-id throw")

    # 6. Dropping ids from the shared bundle would strip Codex, Droid,
    #    OpenCode, and Crush, which have no plugin system to fall back on.
    (helpers.assertTest "skill-hygiene-dedup-is-claude-only"
      (lib.hasInfix "skillOverrides" claudeNix
      && lib.hasInfix "pluginProvidedSkillIds = enabledMattpocockSkills;" claudeNix)
      "the Claude de-duplication must hide bundle copies via settings.json skillOverrides, derived from enabledMattpocockSkills — never by removing ids from the shared bundle")
  ]
)
