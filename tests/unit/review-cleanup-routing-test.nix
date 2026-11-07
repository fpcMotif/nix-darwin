# Tier-1 hermetic checks for the shared review/cleanup routing block and its
# posting guards (issue #367, narrowed scope: shared defaults, thin adapters,
# honest guards — no pipeline engine, no model tiers, no DSPy).
#
# NOT yet wired into tests/default.nix. Wiring is one block:
#   unit-review-cleanup-routing = callTest ./unit/review-cleanup-routing-test.nix { };
# See modules/home/agent-routing/README.md for the full integration steps.
#
# Expectations are RESTATED here by hand (route ids, guard contents), not
# derived from the files under test, so a wrong-but-self-consistent edit to the
# block or guards fails here (docs/adr/0004).
{ inputs, pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs; };
  renderAgentGuide = import ../../modules/home/agent-instructions/render-agent-guide.nix { inherit lib; };

  routingDir = ../../modules/home/agent-routing;
  block = builtins.readFile (routingDir + "/routing-block.md");
  codexAdapter = builtins.readFile (routingDir + "/adapters/codex.md");
  ompAdapter = builtins.readFile (routingDir + "/adapters/omp.md");
  ampGuide = builtins.readFile (routingDir + "/adapters/amp-AGENTS.md");
  codexRules = builtins.readFile (routingDir + "/codex/default.rules");
  ompGuard = builtins.fromJSON (builtins.readFile (routingDir + "/omp/bash-patterns.json"));

  count = marker: text: builtins.length (lib.splitString marker text) - 1;
  once = marker: text: count marker text == 1;

  # Same banned-term list as unit-agent-guides' noModelCache: the routing block
  # names skills and commands, never models.
  noModelCache = text: lib.all (term: !(lib.hasInfix term text)) [
    "gpt-"
    "Gemini"
    "Astra"
    "Sol"
    "Terra"
    "Luna"
  ];

  # Skill ids the block routes to proactively, restated. Each must resolve from
  # a delivery source a host can actually discover (mirrors skill hygiene
  # Tier 1): the personal manifest with an .agents/skills or .codex/skills
  # target, the promoted mattpocock buckets, or a restated external source with
  # in-repo evidence.
  personalRoot = self + "/modules/home/skills/personal";
  personalManifest = builtins.fromJSON (builtins.readFile (personalRoot + "/manifest.json"));
  personalTargets = id: personalManifest.${id} or [ ];
  personalVisible = id:
    builtins.hasAttr id personalManifest && lib.any
      (target: lib.hasPrefix ".agents/skills/" target || lib.hasPrefix ".codex/skills/" target)
      (personalTargets id);

  bucketIds = bucket:
    let root = inputs.mattpocock-skills + "/skills/${bucket}";
    in builtins.attrNames (lib.filterAttrs
      (name: type:
        type == "directory" && builtins.pathExists (root + "/${name}/SKILL.md"))
      (builtins.readDir root));
  upstreamIds = lib.unique (lib.concatMap bucketIds [ "engineering" "productivity" ]);

  claudeNix = builtins.readFile (self + "/modules/home/claude.nix");
  pstackNix = builtins.readFile (self + "/modules/home/claude/pstack.nix");

  # The intended wiring (README step 1): the block appended to every
  # development guide. Rendered here so the assertion fails if the renderer or
  # the block stops composing before the wiring lands.
  sharedDevelopment = ../../modules/home/agent-instructions/shared/development.md;
  developmentGuides = [
    (renderAgentGuide [ sharedDevelopment (routingDir + "/routing-block.md") ])
    (renderAgentGuide [
      ../../modules/home/agent-instructions/codex/guidance/development.md
      sharedDevelopment
      (routingDir + "/routing-block.md")
    ])
    (renderAgentGuide [
      ../../modules/home/agent-instructions/omp/agent/guidance/development.md
      sharedDevelopment
      (routingDir + "/routing-block.md")
    ])
    (renderAgentGuide [
      ../../modules/home/claude/development.md
      sharedDevelopment
      (routingDir + "/routing-block.md")
    ])
  ];
in
helpers.testSuite "review-cleanup-routing" [
  # --- Block structure -------------------------------------------------------
  (helpers.assertTest "routing-block-sections-once"
    (once "## Review and cleanup" block
      && once "### Review procedure" block
      && once "### Cleanup procedure" block
      && once "### Posting" block)
    "routing-block.md must carry its four sections exactly once each")

  (helpers.assertTest "routing-block-no-model-ids"
    (noModelCache block)
    "routing-block.md names a model id; routes name skills and commands only")

  (helpers.assertTest "routing-block-no-automatic-thresholds"
    (!(lib.hasInfix "300" block) && !(lib.hasInfix "top-level director" block))
    "cleanup keeps no size triggers: clean by default, simplify only when the user says so (design review, 2026-09-17)")

  (helpers.assertTest "routing-block-never-auto-commit"
    (lib.hasInfix "Never auto-commit" block && lib.hasInfix "jj new" block)
    "the block must forbid auto-committing to satisfy the review host and name the jj form")

  (helpers.assertTest "routing-block-cleanup-contract"
    (lib.hasInfix "Do not commit or post" block
      && lib.hasInfix "evidence, not proof" block)
    "the cleanup contract must keep its no-commit/no-post and evidence-not-proof lines")

  # --- Defaults named in the block, restated ---------------------------------
  (helpers.assertTest "routing-block-defaults-present"
    (lib.all (id: lib.hasInfix id block) [
      "`code-review`"
      "`ripwire-change-check`"
      "`better-github-skill`"
      "`clean`"
      "`simplify`"
      "`unslop`"
      "`hunk diff --watch`"
      "`ripwire-quality-bar`"
      "`interface-review`"
    ])
    "a default route id went missing from routing-block.md")

  (helpers.assertTest "routing-block-drops-uninstalled-tools"
    (!(lib.hasInfix "calldiff" block) && !(lib.hasInfix "glimpse-changes" block))
    "calldiff and glimpse-changes are not installed anywhere on the hosts; the block must not route to them")

  # --- Placement: every proactive skill id is discoverable -------------------
  (helpers.assertTest "routing-placement-personal"
    (lib.all personalVisible [
      "clean"
      "simplify"
      "ripwire-change-check"
      "ripwire-quality-bar"
      "interface-review"
    ])
    "a personally delivered skill lost its .agents/skills or .codex/skills target")

  (helpers.assertTest "routing-placement-review-host-upstream"
    (builtins.elem "code-review" upstreamIds)
    "code-review fell out of the promoted mattpocock-skills buckets")

  (helpers.assertTest "routing-placement-external-evidence"
    (lib.hasInfix "better-github-skill" claudeNix && lib.hasInfix "unslop" pstackNix)
    "better-github-skill (claude.nix) or unslop (pstack.nix) lost its in-repo delivery evidence")

  (helpers.assertTest "routing-placement-hunk-command"
    (builtins.pathExists (self + "/scripts/update-hunk.sh"))
    "hunk is routed as a command; scripts/update-hunk.sh is its install evidence and is gone")

  # --- Renderer composition (the wiring the README describes) ----------------
  (helpers.assertTest "routing-block-renders-once-per-development-guide"
    (lib.all (once "## Review and cleanup") developmentGuides)
    "the block must render exactly once into each development guide (shared, codex, omp, claude)")

  # --- Thin adapters -----------------------------------------------------------
  (helpers.assertTest "amp-guide-points-at-shared-block"
    (lib.hasInfix "~/.config/agent-guidance/development.md" ampGuide
      && !(lib.hasInfix "## Review and cleanup" ampGuide))
    "amp-AGENTS.md must point at the shared development guide, not embed the block (no double inclusion)")

  (helpers.assertTest "codex-adapter-names-rules-file"
    (lib.hasInfix "~/.codex/rules/default.rules" codexAdapter)
    "the codex adapter must name the rules file the guide already promises")

  (helpers.assertTest "omp-adapter-names-guard-and-limits"
    (lib.hasInfix "bash.patterns" ompAdapter && lib.hasInfix "eval" ompAdapter)
    "the omp adapter must name the bash.patterns guard and its eval blind spot")

  # --- Posting guards ------------------------------------------------------------
  (helpers.assertTest "codex-rules-guard-both-posting-commands"
    (count "prefix_rule(" codexRules == 2
      && lib.hasInfix ''pattern = ["gh", "pr", "comment"]'' codexRules
      && lib.hasInfix ''pattern = ["gh", "pr", "review"]'' codexRules
      && count ''decision = "prompt"'' codexRules == 2)
    "default.rules must hold exactly the two posting prefix rules, both prompt (fail closed under approval_policy=never)")

  (helpers.assertTest "omp-guard-holds-both-posting-patterns"
    (ompGuard.bash.patterns == [
      { match = "gh pr comment*"; approval = "prompt"; }
      { match = "gh pr review*"; approval = "prompt"; }
    ])
    "omp/bash-patterns.json must hold exactly the two posting rules with approval=prompt, nested to match config.yml")
]
