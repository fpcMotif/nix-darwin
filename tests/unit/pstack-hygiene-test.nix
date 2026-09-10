# Cross-source tripwire for the pstack skill source: the pinned pstack-claude
# input text vs. the rewrite rules in modules/home/claude/pstack.nix.
#
# The rules anchor on exact upstream sentences. A port sync that rewords one
# would otherwise leave a plugin-only spelling (a `pstack:` agent id, a Claude
# model slug, `/setup-pstack`) in the installed skill and nothing would notice
# until a subagent call failed. Expectations below are RESTATED by hand
# (docs/adr/0004): none is read from the module's own lists.
#
# Pure readFile/readDir on the flake input; no derivation is forced.
{ inputs, pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs; };

  mkSource = input: subdir: nameRegex: {
    inherit input subdir;
    filter = { maxDepth = 1; } // lib.optionalAttrs (nameRegex != null) { inherit nameRegex; };
  };
  mkSkill = from: path: packages: { inherit from path packages; };
  pstack = import (self + "/modules/home/claude/pstack.nix") { inherit lib pkgs inputs mkSource mkSkill; };

  root = inputs.pstack-claude + "/plugins/pstack/skills";
  built = id: pstack.pstackTransform id {
    original = builtins.readFile (root + "/${id}/SKILL.md");
    dependencies = "";
  };
  has = text: needle: lib.hasInfix needle text;

  # RESTATED: the ids claude.nix installs from pstack.
  installedIds = [
    "poteto-mode"
    "how"
    "why"
    "architect"
    "arena"
    "swarm"
    "interrogate"
    "figure-it-out"
    "unslop"
    "show-me-your-work"
    "create-verification-skill"
    "maintain-verification-skill"
  ];

  # Spellings that must never reach an installed SKILL.md. The alias section
  # poteto-mode carries names foreign spellings on purpose, as lookup keys,
  # so the scan covers the text above it.
  residue = [
    "pstack:"
    "plugin-dev:"
    "/setup-pstack"
    "claude-opus-5"
    "claude-fable-5"
    "claude-sonnet-5"
    "claude-haiku-4-5"
    "playbooks/prototype.md"
    "**deslop**"
    "**no-comments**"
    "**technical-writing**"
    "leaf SKILL.md"
    "—"
  ];
  aboveAliases = text: builtins.head (lib.splitString "## Names used in the playbooks" text);
  residueHits = lib.concatMap
    (id: let text = aboveAliases (built id); in map (r: "${id}: ${r}") (builtins.filter (r: has text r) residue))
    installedIds;

  # Rewrites poteto-mode must carry after the transform.
  poteto = built "poteto-mode";
  expected = [
    "subagent_type: \"poteto-agent\""
    "the **prototype** skill (`/prototype`)"
    "**diagnosing-bugs**"
    "the **tdd** skill (`/tdd`)"
    "the **simplify** skill (`/simplify`)"
    "**writing-for-agents**"
    "**pstack-principles**"
    "## Names used in the playbooks"
    "## Nix install"
    "`fable` is Fable 5.1"
  ];
  missing = builtins.filter (e: !(has poteto e)) expected;

  principleDirs = builtins.filter (lib.hasPrefix "principle-") (builtins.attrNames (builtins.readDir root));
  principlesSkill = pstack.pstackPrinciplesSkill;
  sectionCount = builtins.length
    (builtins.filter (l: lib.hasPrefix "## principle-" l) (lib.splitString "\n" principlesSkill));

  agent = pstack.pstackAgentText "poteto-agent.md";

  roleLine = l: builtins.match "[a-z ,-]+: (opus|fable|sonnet|haiku)(, (opus|fable|sonnet|haiku))*" l != null;
  sheetLines = builtins.filter roleLine (lib.splitString "\n" pstack.pstackModelsSheetText);
in
helpers.testSuite "pstack-hygiene" [
  (helpers.assertTest "pstack-hygiene-ids-exist"
    (lib.all (id: builtins.pathExists (root + "/${id}/SKILL.md")) installedIds)
    "a selected pstack id no longer exists upstream; update pstackSkills in modules/home/claude/pstack.nix")

  (helpers.assertTest "pstack-hygiene-no-residue"
    (residueHits == [ ])
    "a plugin-only or upstream spelling survived the transform, so an upstream reword moved an anchor: ${lib.concatStringsSep ", " residueHits}")

  (helpers.assertTest "pstack-hygiene-rewrites-present"
    (missing == [ ])
    "an expected rewrite is missing from poteto-mode: ${lib.concatStringsSep " | " missing}")

  (helpers.assertTest "pstack-hygiene-principles-complete"
    (sectionCount == builtins.length principleDirs)
    "pstack-principles has ${toString sectionCount} sections but upstream ships ${toString (builtins.length principleDirs)} principle-* leaves")

  (helpers.assertTest "pstack-hygiene-principles-anchors"
    (!(has principlesSkill "../principle-"))
    "a sibling link in a principle leaf was not turned into a section anchor")

  (helpers.assertTest "pstack-hygiene-agent-pointer"
    (has agent "description: Subagent for poteto-mode playbook steps" && has agent "pstack-principles")
    "poteto-agent.md was not rewritten; upstream changed its description or body")

  (helpers.assertTest "pstack-hygiene-role-sheet"
    (builtins.length sheetLines == 15)
    "pstack-models.md has ${toString (builtins.length sheetLines)} role lines, expected 15")
]
