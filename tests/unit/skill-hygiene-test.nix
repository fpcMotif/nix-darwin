{ inputs, pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs; };

  curation = import (self + "/modules/home/claude/skill-curation.nix");
  inherit (import (self + "/modules/home/skill-bundle/mattpocock.nix") { inherit lib inputs; }) upstreamIds;
  disabled = curation.disabledMattpocockSkills;
  leanExcluded = curation.leanExcludedMattpocockSkills;

  # Restated on purpose: claude.nix derives its list with readDir, so each new
  # directory under modules/home/skills must also be named here.
  vendored = [ "browser-checks" "jj" "setup-ts-deep-modules" ];

  vendoredOnDisk = builtins.attrNames (lib.filterAttrs
    (name: type:
      type == "directory"
      && builtins.pathExists (self + "/modules/home/skills/${name}/SKILL.md"))
    (builtins.readDir (self + "/modules/home/skills")));

  sorted = lib.sort (a: b: a < b);
  personalRoot = self + "/modules/home/skills/personal";
  personalPlacement = import (personalRoot + "/placement.nix");
  personalIds = lib.concatLists (builtins.attrValues (removeAttrs personalPlacement [ "hosts" ]))
    ++ builtins.attrNames personalPlacement.hosts;
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
      (personalIds != [ ] && sorted personalDirs == sorted (lib.unique personalIds)
      && lib.all
        (id:
          builtins.pathExists (personalRoot + "/${id}/SKILL.md")
          && builtins.readFile (personalRoot + "/${id}/SKILL.md") != "")
        personalIds
      && lib.all (hosts: hosts != [ ]) (builtins.attrValues personalPlacement.hosts))
      "every personal skill dir must have a nonempty SKILL.md and appear in placement.nix")

    (helpers.assertTest "skill-hygiene-prompt-coach-everywhere"
      (builtins.elem "prompt-coach" personalPlacement.everywhere)
      "prompt-coach must reach every harness, Claude Code included")
    (helpers.assertTest "skill-hygiene-ste80-targets"
      (builtins.elem "ste80" personalPlacement.outside-claude)
      "ste80 needs its .agents copy, which the non-Claude guides load by path. It needs no Claude copy, because Claude's guide omits the Plain English section that loads it.")

    # 3. claude.nix derives localSkillIds from readDir, so this checks that a
    #    new modules/home/skills/<id> directory is added deliberately.
    (helpers.assertTest "skill-hygiene-vendored-dirs-match"
      (sorted vendoredOnDisk == sorted vendored)
      "modules/home/skills/ holds ${toString vendoredOnDisk} but this test expects ${toString vendored} — add the new skill here deliberately")
  ]
)
