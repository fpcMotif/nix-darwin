# pstack (Lauren Tan's Cursor plugin) as a nix skill source, reuse first.
# Imported by modules/home/claude.nix for the live config and by
# tests/unit/pstack-hygiene-test.nix, which asserts on the same rewrite
# results, so a port sync that moves a transform anchor fails the build.
# Pure string work on the pinned input; nothing here is realized at eval.
{ lib, pkgs, inputs, mkSource, mkSkill }:

let
  # pstack (Lauren Tan's Cursor plugin, cursor/plugins/pstack) through
  # michael-denyer/pstack-claude, the Claude Code port that keeps all 23
  # principles and re-applies its documented substitutions on every upstream
  # sync. Installed as plain skills, not as a plugin, so the plugin-only
  # spellings are rewritten at build time (pstackTransform): the
  # plugin-namespaced agent id becomes the bare id ~/.claude/agents registers,
  # Claude model slugs become the Agent tool's aliases, and
  # `plugin-dev:skill-development` becomes writing-for-agents, the authoring
  # reference in this bundle (ADR-0008 keeps skill-creator off the global
  # catalog).
  #
  # Scope: only what nothing installed here already does. poteto-mode (the
  # router), the orchestration skills it routes to, and its principles as ONE
  # module (pstack-principles, built below from the 23 upstream leaves: 23
  # shallow catalog entries become one deep one). Everything with an installed
  # equivalent is left out and poteto-mode is pointed at the equivalent:
  #   tdd, teach          mattpocock tdd, teach
  #   deslop              simplify (built-in)
  #   no-comments         the CLAUDE.md Code Quality comment rule
  #   technical-writing   CLAUDE.md Writing Style + mattpocock writing-for-agents
  #   bro                 mattpocock wait-what
  #   blast-radius        ripwire --edit-check (ripwire-change-check)
  #   setup-pstack        hand-written ~/.claude/pstack-models.md
  #   Prototype playbook  mattpocock prototype
  #   verify (no skill)   dotfiles web-browser, or the harness's browser tools
  # Also out: bot tooling (make-bot-ui, automate-me), transcript mining
  # (recall), reflect, typescript-best-practices, and the port's PR extras
  # (babysit would collide with the brooklyn id; fix-ci and friends duplicate
  # better-github-skill). The source regex keeps unselected ids out of
  # discoverCatalog, which throws on a duplicate id.
  pstackSkillsRoot = inputs.pstack-claude + "/plugins/pstack/skills";
  pstackPrinciples = builtins.filter (lib.hasPrefix "principle-")
    (builtins.attrNames (builtins.readDir pstackSkillsRoot));
  pstackSkills = [
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

  # Names the playbooks and references still use for skills that are not
  # installed. The module only rewrites SKILL.md, so poteto-mode carries this
  # table and every playbook resolves through it. Keep the trigger-line
  # rewrites in pstackTransform in step with it.
  pstackAliases = [
    { name = "`verify`"; use = "the **web-browser** skill, or the harness's browser and simulator tools"; }
    { name = "`/deslop`"; use = "the **simplify** skill (`/simplify`)"; }
    { name = "`/no-comments`"; use = "the Code Quality comment rule in CLAUDE.md: a comment only for what the code cannot say"; }
    { name = "`/technical-writing`"; use = "the Writing Style section of CLAUDE.md; agent-facing docs follow the **writing-for-agents** skill"; }
    { name = "the bundled `babysit` skill"; use = "the Babysit playbook; no babysit skill is installed"; }
    { name = "`/tdd`"; use = "the mattpocock **tdd** skill: red-green slices, tests at seams"; }
    { name = "`plugin-dev:skill-development`, `skill-creator`"; use = "the **writing-for-agents** skill"; }
    { name = "`~/.claude/pstack-models.md`"; use = "installed by nix; the role sheet every Models section defers to, and the one place to change a model"; }
    { name = "a leaf `principle-*` skill"; use = "the matching section of the **pstack-principles** skill"; }
  ];
  pstackPotetoAppendix = ''

    ## Names used in the playbooks

    The playbooks and references name skills from the original plugin. Each resolves here as follows.

  '' + lib.concatMapStringsSep "\n" (a: "- ${a.name} → ${a.use}") pstackAliases + ''


    ## Nix install

    This skill lives in a read-only Nix store, so `scripts/` cannot install its own `node_modules`. Before the first `orch` or `watch-pr` call, copy it somewhere writable: `cp -RL ~/.claude/skills/poteto-mode/scripts /tmp/pstack-scripts && cd /tmp/pstack-scripts && bun install`, then run the tools from there.
  '';
  pstackTddTrigger = "- Test-first work, or a bug with a cheap local test target → the **tdd** skill (`/tdd`). It is the mattpocock skill installed here: one red-green slice at a time, tests at seams, and the failing run quoted before the fix.\n";
  pstackModelsIntro = "Role defaults. The Agent tool's `model` parameter takes an alias: `fable` is Fable 5.1, `opus` is Opus 5, `sonnet` is Sonnet 5, `haiku` is Haiku 4.5. `~/.claude/pstack-models.md` is installed by nix with every role and overrides each line below; change a model there, not here.";
  pstackTransform = id: { original, dependencies }:
    let
      body = lib.replaceStrings
        [
          "\"pstack:poteto-agent\""
          "Plugin agents register under the plugin namespace; the bare name `poteto-agent` errors."
          "plugin-dev:skill-development"
          "- Before commit → the **deslop** skill (`/deslop`).\n"
          "- Before review → the **no-comments** skill (`/no-comments`).\n"
          "- Docs, RFCs, readmes, PR descriptions, commit messages → the **technical-writing** skill (`/technical-writing`) for structure and sentence discipline, on top of **unslop**.\n"
          "- Shipping UI / IDE / CLI → the driver skill (`run` for CLIs/TUIs, `verify` for UIs). Both ship as Claude Code built-ins."
          "Sketch it via the Prototype playbook (`playbooks/prototype.md`) and let the result decide."
          "(\"prototype\", \"mock it up\", \"try this layout\", \"sketch it to decide\"). `playbooks/prototype.md`."
          "- **Bug fix.** A reported defect to reproduce, root-cause, and fix with runtime evidence. `playbooks/bug-fix.md`."
          "Read the leaf skill in full for any principle you apply. Each entry names when it applies."
          "Cite only principles whose leaf SKILL.md you read this session."
          "Role defaults, stamped from `plugins/pstack/models.json` (edit there, rerun `tools/generate.mjs`). A matching role line in `~/.claude/pstack-models.md` overrides each at runtime; see `/setup-pstack`."
          "`/setup-pstack`"
          "claude-opus-5"
          "claude-opus-4-8"
          "claude-opus-4-6"
          "claude-fable-5"
          "claude-sonnet-5"
          "claude-sonnet-4-6"
          "claude-haiku-4-5"
          " — "
          "—"
        ]
        [
          "\"poteto-agent\""
          "The agent lives in `~/.claude/agents`, so the bare name resolves."
          "writing-for-agents"
          (pstackTddTrigger + "- Before commit → the **simplify** skill (`/simplify`).\n")
          "- Before review → sweep comments to the Code Quality rule in CLAUDE.md: a comment only for what the code cannot say.\n"
          "- Docs, RFCs, readmes, PR descriptions, commit messages → the Writing Style section of CLAUDE.md, on top of **unslop**. Agent-facing docs → the **writing-for-agents** skill.\n"
          "- Shipping UI / IDE / CLI → the driver skill: `run` (a Claude Code built-in) for CLIs and TUIs; for UIs the **web-browser** skill or the harness's browser and simulator tools, which the playbooks call `verify`."
          "Sketch it via the **prototype** skill (`/prototype`) and let the result decide."
          "(\"prototype\", \"mock it up\", \"try this layout\", \"sketch it to decide\"). Route: the **prototype** skill (`/prototype`), which keeps the sketch as a primary source on a `prototype/<name>` branch."
          "- **Bug fix.** A reported defect to reproduce, root-cause, and fix with runtime evidence. `playbooks/bug-fix.md`. A bug that resists a first look builds its red loop with the **diagnosing-bugs** skill first, then the regression test with **tdd**."
          "Every **principle-…** id below is a section of the **pstack-principles** skill. Read that section in full for any principle you apply. Each entry names when it applies."
          "Cite only principles whose section you read this session."
          pstackModelsIntro
          "`~/.claude/pstack-models.md`"
          "opus"
          "opus"
          "opus"
          "fable"
          "sonnet"
          "sonnet"
          "haiku"
          ", "
          ", "
        ]
        original;
    in
    body + lib.optionalString (id == "poteto-mode") pstackPotetoAppendix;

  # The 23 principle leaves as one module. Each leaf's body (frontmatter
  # dropped, sibling links turned into section anchors) becomes a section
  # headed by its upstream id, so poteto-mode's index bullets still name the
  # exact id. Built from the input at eval time, so upstream edits flow through.
  pstackPrincipleSections = lib.concatMapStringsSep "\n"
    (id:
      let
        raw = builtins.readFile (pstackSkillsRoot + "/${id}/SKILL.md");
        leafBody = lib.concatStringsSep "\n---\n" (lib.drop 1 (lib.splitString "\n---\n" raw));
        linked = lib.replaceStrings [ "(../principle-" "/SKILL.md)" ] [ "(#principle-" ")" ] leafBody;
      in
      "## ${id}\n${linked}")
    pstackPrinciples;
  pstackPrinciplesSkill = ''
    ---
    name: pstack-principles
    description: pstack's 23 engineering principles as sections (laziness protocol, prove it works, model the domain, guard the context window, and more). Read a section when poteto-mode's Principles index names its id.
    ---

    # pstack principles

    One section per principle, headed by its upstream id. poteto-mode's Principles index says when each applies.

  '' + pstackPrincipleSections;

  # One role sheet, nix-owned. pstack's own contract: a matching role line in
  # ~/.claude/pstack-models.md overrides the default each skill's Models
  # section states. Shipping every role here makes the sheet the single place
  # model routing lives at runtime; the sections stay as upstream documents
  # them. Tiering is deliberate: a role's default model does the work, the
  # hardest changes in any role go to strongest judgment.
  pstackModelRoles = [
    { role = "feature, refactoring"; models = "opus"; }
    { role = "bug-fix"; models = "fable"; }
    { role = "perf-issue"; models = "fable"; }
    { role = "hillclimb"; models = "fable"; }
    { role = "judgment and prose"; models = "opus"; }
    { role = "strongest judgment"; models = "fable"; }
    { role = "how explorer"; models = "opus"; }
    { role = "how explainer"; models = "opus"; }
    { role = "why investigators"; models = "opus"; }
    { role = "why synthesizer"; models = "opus"; }
    { role = "arena runners"; models = "opus, fable, sonnet"; }
    { role = "arena cross-judge pool"; models = "opus, fable, sonnet"; }
    { role = "swarm workers"; models = "opus"; }
    { role = "architect runners"; models = "opus, fable, sonnet"; }
    { role = "interrogate reviewers"; models = "opus, fable, sonnet"; }
  ];
  pstackModelsSheetText = ''
    # pstack model configuration

    Nix-owned: modules/home/claude.nix, pstackModelRoles. One line per pstack role; each overrides the default the skill's Models section states. Values are the Agent tool's aliases: fable is Fable 5.1, opus is Opus 5, sonnet is Sonnet 5, haiku is Haiku 4.5. The hardest changes in any role go to the strongest judgment model.

  '' + lib.concatMapStringsSep "\n" (r: "${r.role}: ${r.models}") pstackModelRoles + "\n";
  pstackModelsSheet = pkgs.writeText "pstack-models.md" pstackModelsSheetText;

  pstackSources = {
    pstack = mkSource "pstack-claude" "plugins/pstack/skills"
      "^(${lib.concatStringsSep "|" pstackSkills})$";
  };
  pstackExplicit = lib.listToAttrs
    (map
      (id: { name = id; value = mkSkill "pstack" id [ ] // { transform = pstackTransform id; }; })
      pstackSkills) // {
    pstack-principles = mkSkill "pstack" "principle-laziness-protocol" [ ]
      // { transform = { original, dependencies }: pstackPrinciplesSkill; };
  };
  # The agent description is a context pointer the lead reads on every turn,
  # so it states what the agent is and when to pick it, and leaves the
  # "read SKILL.md first" instruction to the body, which already carries it.
  pstackAgentText = name: lib.replaceStrings
    [
      "description: Routing target for `/poteto-mode` and any request for poteto's style. Resume an existing `poteto-agent` for the conversation rather than spawning a sibling. Reads the `poteto-mode` skill's `SKILL.md` in full before any work, including its inline Principles index. Substituting `general-purpose` skips that read and drifts."
      "Navigate to a leaf `principle-*` skill whenever you apply that principle."
    ]
    [
      "description: Subagent for poteto-mode playbook steps. It reads poteto-mode's SKILL.md and principles before working, which general-purpose does not. Use as `subagent_type` for any delegate a pstack playbook spawns; resume an existing poteto-agent instead of spawning a sibling."
      "Read the matching section of the `pstack-principles` skill whenever you apply a principle."
    ]
    (builtins.readFile (inputs.pstack-claude + "/plugins/pstack/agents/${name}"));
  pstackAgentFile = name: pkgs.writeText name (pstackAgentText name);
in
{
  inherit pstackSkillsRoot pstackPrinciples pstackSkills pstackAliases
    pstackTransform pstackPrinciplesSkill pstackModelRoles pstackModelsSheetText
    pstackModelsSheet pstackSources pstackExplicit pstackAgentText pstackAgentFile;
}
