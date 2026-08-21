# Hermetic drift checks for the agent-skill curation lists.
#
# These are genuine CROSS-SOURCE invariants — the repo's curation lists vs. the
# pinned `mattpocock-skills` flake input vs. the working tree — not restatements
# of the module under test, so deriving them here is correct (contrast
# docs/adr/0004, which forbids deriving a test's EXPECTATION from the module it
# tests). The exclusion lists below are RESTATED by hand for exactly that
# reason: a wrong-but-self-consistent edit to claude.nix must fail here.
#
# Pure `builtins.readDir` only. Forcing `programs.agent-skills` output would
# trigger IFD and break evaluating the Linux hosts from Darwin.
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
  upstreamIds = lib.unique (lib.concatMap bucketIds [ "engineering" "productivity" "misc" ]);

  # RESTATED, not imported — must match modules/home/claude.nix by hand.
  disabled = [ "grill-me" ];
  leanExcluded = [
    "git-guardrails-claude-code"
    "migrate-to-shoehorn"
    "scaffold-exercises"
    "setup-pre-commit"
  ];
  vendored = [ "jj" "setup-ts-deep-modules" ];

  claudeNix = builtins.readFile (self + "/modules/home/claude.nix");
  cleanupNix = builtins.readFile (self + "/modules/home/cleanup.nix");

  targetDirs = [
    ".agents/skills"
    ".claude/skills"
    ".cursor/skills"
    ".codex/skills"
    ".config/agents/skills"
    ".config/crush/skills"
    ".config/opencode/skills"
    ".factory/skills"
    ".pi/agent/skills"
  ];

  vendoredOnDisk = builtins.attrNames (lib.filterAttrs
    (name: type:
      type == "directory"
      && builtins.pathExists (self + "/modules/home/skills/${name}/SKILL.md"))
    (builtins.readDir (self + "/modules/home/skills")));

  sorted = lib.sort (a: b: a < b);
in
helpers.testSuite "skill-hygiene" (
  # 1. Every exclusion term must still name a live upstream skill. A term that
  #    excludes nothing is a silent no-op the day upstream renames something —
  #    which is exactly how `caveman` and `zoom-out` rotted in the lean list.
  (map
    (id: helpers.assertTest "skill-hygiene-exclusion-live-${id}"
      (builtins.elem id upstreamIds)
      "exclusion list names '${id}', which no longer exists in any promoted mattpocock-skills bucket — delete the entry or fix the typo")
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
    # 3. Vendored dirs on disk == the ids this test knows about. claude.nix now
    #    derives localSkillIds from readDir, so this is the tripwire that a new
    #    modules/home/skills/<id> got added without a decision.
    (helpers.assertTest "skill-hygiene-vendored-dirs-match"
      (sorted vendoredOnDisk == sorted vendored)
      "modules/home/skills/ holds ${toString vendoredOnDisk} but this test expects ${toString vendored} — add the new skill here deliberately")

    # 4. cleanup.nix hand-mirrors the picker dir list; the "Keep in sync"
    #    comment was previously the entire enforcement.
    (helpers.assertTest "skill-hygiene-cleanup-mirrors-targets"
      (lib.all (d: lib.hasInfix d cleanupNix && lib.hasInfix d claudeNix) targetDirs)
      "modules/home/cleanup.nix's stale-skill-dir list drifted from skillTargetDirs in claude.nix")

    # 5. The Karpathy forks are retired. A `transform` on a mattpocock skill
    #    shadows the plugin copy and re-creates the duplicate this module
    #    exists to remove, so re-adding one must be a deliberate decision.
    (helpers.assertTest "skill-hygiene-no-mattpocock-transform"
      (!(lib.hasInfix "appendKarpathy" claudeNix)
      && !(lib.hasInfix "transformedMattpocockSkills" claudeNix))
      "a mattpocock skill regained a Nix `transform`; forks shadow the plugin copy and re-create the duplicate this change removed")

    # 6. The in-progress source must not come back by accident: upstream
    #    promoting a skill that also matches an in-progress regex makes
    #    discoverCatalog throw on a duplicate id (this is how `teach` ended up
    #    listed twice before it was promoted into productivity/).
    (helpers.assertTest "skill-hygiene-no-in-progress-source"
      (!(lib.hasInfix "mp-in-progress" claudeNix))
      "the mp-in-progress source was re-added; teach lives in productivity/ now, so its regex matches nothing and risks a duplicate-id throw")

    # 7. The Claude-only de-duplication must never be implemented by dropping
    #    ids from the bundle — that would silently strip Codex/Droid/OpenCode/
    #    Crush, which have no plugin system to fall back on.
    (helpers.assertTest "skill-hygiene-dedup-is-claude-only"
      (lib.hasInfix "skillOverrides" claudeNix
      && lib.hasInfix "pluginProvidedSkillIds = enabledMattpocockSkills" claudeNix)
      "the Claude de-duplication must hide bundle copies via settings.json skillOverrides, derived from enabledMattpocockSkills — never by removing ids from the shared bundle")
  ]
)
