{ lib, pkgs, inputs, mkSource, mkSkill, docLock ? true }:

let
  # Installed as plain skills, not a plugin, so pstackTransform rewrites
  # plugin-only names. Skills with an installed equivalent are left out.
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
    "benchmark-checklist"
    "show-me-your-work"
    "create-verification-skill"
    "maintain-verification-skill"
  ];

  # Keep the trigger-line rewrites in pstackTransform in step with this.
  pstackAliases = [
    { name = "`verify`"; use = "the **web-browser** skill, or the harness's browser and simulator tools"; }
    { name = "`/deslop`"; use = "the **simplify** skill (`/simplify`)"; }
    { name = "`/no-comments`"; use = "the Code Quality comment rule in CLAUDE.md: a comment only for what the code cannot say"; }
    { name = "`unslop`, `/unslop`"; use = "the Writing section of CLAUDE.md"; }
    { name = "`/technical-writing`"; use = "`~/.claude/guidance/human-documents.md` and the Writing section of CLAUDE.md; agent-facing docs follow the **writing-for-agents** skill"; }
    { name = "the bundled `babysit` skill"; use = "the Babysit playbook; no babysit skill is installed"; }
    { name = "`/tdd`"; use = "the mattpocock **tdd** skill: red-green slices, tests at seams"; }
    { name = "`plugin-dev:skill-development`, `skill-creator`"; use = "the **writing-for-agents** skill"; }
    { name = "`thermo-nuclear-code-quality-review`"; use = "the **nuclear-cqr** skill (`/nuclear-cqr`)"; }
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
  pstackCommentRule =
    if docLock
    then "Comments change only in docs work, per the Docs lock in CLAUDE.md. There, keep a comment only for a non-obvious *why* the code can't show."
    else "Keep a comment only for a non-obvious *why* the code can't show.";
  pstackModelsIntro = "Role defaults. The Agent tool's `model` parameter takes an alias: `fable` is Fable 5.1, `opus` is Opus 5, `sonnet` is Sonnet 5, `haiku` is Haiku 4.5. `~/.claude/pstack-models.md` is installed by nix with every role and overrides each line below; change a model there, not here.";
  pstackTransform = id: { original, dependencies }:
    let
      body = lib.replaceStrings
        [
          "pstack:poteto-agent"
          "pstack:effort-"
          "Plugin agents register under the plugin namespace. The bare name `poteto-agent` errors."
          "Plugin agents register under the plugin namespace; the bare name `poteto-agent` errors."
          "- Any prose surface, your reply to the user included → the **unslop** skill. Write the reply per **Writing the reply**. Agent-facing prose also follows the **plugin-dev:skill-development** skill (Claude Code's authoring guidance for SKILL.md files).\n"
          "plugin-dev:skill-development"
          "- Before commit → the **deslop** skill (`/deslop`).\n"
          "- Before review → the **no-comments** skill (`/no-comments`).\n"
          "- Docs, RFCs, readmes, PR descriptions, or commit messages → the **technical-writing** skill (`/technical-writing`), on top of **unslop**.\n"
          "- **A colon as a mid-sentence connector is also out** (unslop rule 14). A colon before a list is fine."
          "(the **unslop** skill applies to log text too)"
          "- Shipping UI / IDE / CLI → the driver skill. `run` ships with Claude Code and the model can invoke it for CLIs, TUIs, servers, and browser or Electron apps. The bundled `verify` runs only when the user types `/verify`, so for UIs use the project `verify` skill at `.claude/skills/verify/` (generate it with `/create-verification-skill`) and fall back to `run` when the repo has none. For bug fixes, reproduce first on the same surface yourself. Hand to the user only under the narrow Bug fix step 1 exception."
          "Sketch it via the Prototype playbook (`playbooks/prototype.md`) and let the result decide."
          "(\"prototype\", \"mock it up\", \"try this layout\", \"sketch it to decide\")."
          "- **Bug fix.** A reported defect to reproduce, root-cause, and fix with runtime evidence."
          "Read the leaf skill in full for any principle you apply. Each entry names when it applies."
          "Cite only principles whose leaf SKILL.md you read this session."
          "Keep a comment only for a non-obvious *why* the code can't show."
          "Role defaults, stamped from `plugins/pstack/models.json` (edit there, rerun `tools/generate.mjs`). A matching role line in the `pstack-models.md` override sheet overrides each at runtime; `/setup-pstack` writes it and lists its path per runtime."
          "`/setup-pstack` writes it and lists its path per runtime"
          "(`/setup-pstack` lists its path per runtime)"
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
          "poteto-agent"
          "effort-"
          "The agent lives in `~/.claude/agents`, so the bare name resolves."
          "The agent lives in `~/.claude/agents`, so the bare name resolves."
          "- Any prose surface, your reply to the user included → the Writing section of CLAUDE.md, and **Writing the reply** below. Agent-facing prose also follows the **writing-for-agents** skill.\n"
          "writing-for-agents"
          (pstackTddTrigger + "- Before commit → the **simplify** skill (`/simplify`).\n")
          "- Before review → sweep comments to the Code Quality rule in CLAUDE.md: a comment only for what the code cannot say.\n"
          "- Docs, RFCs, readmes, PR descriptions, commit messages → `~/.claude/guidance/human-documents.md` and the Writing section of CLAUDE.md. Agent-facing docs → the **writing-for-agents** skill.\n"
          "- **A colon as a mid-sentence connector is also out.** A colon before a list is fine."
          "(the Writing section of CLAUDE.md applies to log text too)"
          "- Shipping UI / IDE / CLI → the driver skill: `run` (a Claude Code built-in) for CLIs and TUIs; for UIs the **web-browser** skill or the harness's browser and simulator tools, which the playbooks call `verify`. For bug fixes, reproduce first on the same surface yourself. Hand to the user only under the narrow Bug fix step 1 exception."
          "Sketch it via the **prototype** skill (`/prototype`) and let the result decide."
          "(\"prototype\", \"mock it up\", \"try this layout\", \"sketch it to decide\"). Route: the **prototype** skill (`/prototype`), which keeps the sketch as a primary source on a `prototype/<name>` branch."
          "- **Bug fix.** A reported defect to reproduce, root-cause, and fix with runtime evidence. `playbooks/bug-fix.md`. A bug that resists a first look builds its red loop with the **diagnosing-bugs** skill first, then the regression test with **tdd**."
          "Every **principle-…** id below is a section of the **pstack-principles** skill. Read that section in full for any principle you apply. Each entry names when it applies."
          "Cite only principles whose section you read this session."
          pstackCommentRule
          pstackModelsIntro
          "nix installs it at `~/.claude/pstack-models.md`"
          "(nix installs it at `~/.claude/pstack-models.md`)"
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

  # The 23 principle leaves as one module, one section per upstream id, so
  # poteto-mode's index still names each id. Upstream edits flow through.
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

  # ~/.claude/pstack-models.md: a role line here overrides each skill's
  # default model, so this sheet is the one place model routing lives.
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
  pstackSkillDrv = id: pkgs.runCommand "pstack-skill-${id}" { preferLocalBuild = true; } ''
    mkdir -p "$out"
    shopt -s nullglob
    for f in ${pstackSkillsRoot}/${id}/*; do
      fname="$(basename "$f")"
      if [ "$fname" != "SKILL.md" ]; then
        ln -s "$f" "$out/$fname"
      fi
    done
    cp ${pkgs.writeText "SKILL.md" (pstackTransform id { original = builtins.readFile (pstackSkillsRoot + "/${id}/SKILL.md"); dependencies = ""; })} "$out/SKILL.md"
    chmod 0444 "$out/SKILL.md"
  '';

  pstackPrinciplesDrv = pkgs.runCommand "pstack-skill-pstack-principles" { preferLocalBuild = true; } ''
    mkdir -p "$out"
    cp ${pkgs.writeText "SKILL.md" pstackPrinciplesSkill} "$out/SKILL.md"
    chmod 0444 "$out/SKILL.md"
  '';

  pstackDrvs = lib.listToAttrs (map (id: { name = id; value = pstackSkillDrv id; }) pstackSkills) // {
    pstack-principles = pstackPrinciplesDrv;
  };

  # The agent description is a context pointer the lead reads on every turn,
  # so it states what the agent is and when to pick it, and leaves the
  # "read SKILL.md first" instruction to the body, which already carries it.
  pstackAgentText = name: lib.replaceStrings
    [
      "description: Delegate subagent for code-writing and helper tasks spawned during a `/poteto-mode` run. Use for delegates, not as the runner for `/poteto-mode` itself. Spawn a fresh `poteto-agent` for each new task, and resume one only in the strict cases that poteto-mode's Subagents section names. Reads the `poteto-mode` skill's `SKILL.md` in full before any work, including its inline Principles index. Substituting `general-purpose` skips that read and drifts."
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
    pstackModelsSheet pstackSources pstackExplicit pstackDrvs pstackAgentText pstackAgentFile;
}
