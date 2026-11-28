{ lib, pkgs, inputs, docLock ? true }:

let
  # Non-Claude agents get these as plain skills, not a plugin, so pstackTransform
  # rewrites plugin-only names. Skills with an installed equivalent are left out.
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
    { name = "`thermo-nuclear-code-quality-review`"; use = "the mattpocock **code-review** skill; the `thermos` plugin that ships the original is not installed"; }
    { name = "`~/.claude/pstack-models.md`"; use = "installed by nix; the role sheet every Models section defers to, and the one place to change a model"; }
    { name = "a leaf `principle-*` skill"; use = "the matching section of the **pstack-principles** skill"; }
  ];
  pstackPotetoAppendix = ''

    ## Names used in the playbooks

    The playbooks and references name skills from the original plugin. Each resolves here as follows.

  '' + lib.concatMapStringsSep "\n" (a: "- ${a.name} → ${a.use}") pstackAliases + ''


    ## Nix install

    Nix builds `scripts/node_modules` into the store with the install key that `bootstrap.ts` checks, so `watch-pr/watch-pr` and `watch-pr/ship-pr` run in place. Do not copy `scripts/` or run `bun install`.
  '';
  pstackTddTrigger = "- Test-first work, or a bug with a cheap local test target → the **tdd** skill (`/tdd`). It is the mattpocock skill installed here: one red-green slice at a time, tests at seams, and the failing run quoted before the fix. A bug that resists a first look builds its red loop with the **diagnosing-bugs** skill first.\n";
  pstackCommentRule =
    if docLock
    then "Comments change only in docs work, per the Docs lock in CLAUDE.md. There, keep a comment only for a non-obvious *why* the code can't show."
    else "Keep a comment only for a non-obvious *why* the code can't show.";
  pstackModelsIntro = "Role defaults. The Agent tool's `model` parameter takes an alias: `fable` is Fable 5.1, `opus` is Opus 5, `sonnet` is Sonnet 5, `haiku` is Haiku 4.5. `~/.claude/pstack-models.md` is installed by nix with every role and overrides each line below; change a model there, not here.";
  pstackTransform = id: { original, ... }:
    let
      body = lib.replaceStrings
        [
          "pstack:poteto-agent"
          "pstack:effort-"
          "Plugin agents register under the plugin namespace. The bare name `poteto-agent` errors."
          "Plugin agents register under the plugin namespace; the bare name `poteto-agent` errors."
          "- Prose, your reply included → **unslop**. Docs, PR descriptions, commit messages → **technical-writing**, on top of **unslop**."
          "plugin-dev:skill-development"
          "- Before commit → `/deslop`. Before review → **no-comments**.\n"
          "(the **unslop** skill applies to log text too)"
          "- Shipping UI / IDE / CLI → the driver skill. `run` ships with Claude Code and the model can invoke it for CLIs, TUIs, servers, and browser or Electron apps. The bundled `verify` runs only when the user types `/verify`, so for UIs use the project `verify` skill at `.claude/skills/verify/` (generate it with `/create-verification-skill`) and fall back to `run` when the repo has none."
          "- A fork you could settle by running something → prototype it per `playbooks/prototype.md` instead of asking."
          "Read the leaf skill in full for any principle you apply. Each entry names when it applies. Each leaf is the **principle-<title>** skill, with the title in kebab case, hyphens kept and other punctuation dropped, unless the entry gives its name."
          "Cite only principles whose leaf SKILL.md you read this session."
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
          "- Prose, your reply included → the Writing section of CLAUDE.md, and **Writing the reply** below. Docs, PR descriptions, commit messages → `~/.claude/guidance/human-documents.md` on top of that. Agent-facing prose → the **writing-for-agents** skill."
          "writing-for-agents"
          (pstackTddTrigger + "- Before commit → the **simplify** skill (`/simplify`). Before review → check comments. " + pstackCommentRule + "\n")
          "(the Writing section of CLAUDE.md applies to log text too)"
          "- Shipping UI / IDE / CLI → the driver skill: `run` (a Claude Code built-in) for CLIs and TUIs. For UIs, the **web-browser** skill or the harness's browser and simulator tools, which the playbooks call `verify`."
          "- A fork you could settle by running something → sketch it with the **prototype** skill (`/prototype`) instead of asking. It keeps the sketch as a primary source on a `prototype/<name>` branch."
          "Every **principle-…** id below is a section of the **pstack-principles** skill. Read that section in full for any principle you apply. Each entry names when it applies."
          "Cite only principles whose section you read this session."
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

    Nix-owned: modules/home/claude/pstack.nix, pstackModelRoles. One line per pstack role; each overrides the default the skill's Models section states. Values are the Agent tool's aliases: fable is Fable 5.1, opus is Opus 5, sonnet is Sonnet 5, haiku is Haiku 4.5. The hardest changes in any role go to the strongest judgment model.

  '' + lib.concatMapStringsSep "\n" (r: "${r.role}: ${r.models}") pstackModelRoles + "\n";
  pstackModelsSheet = pkgs.writeText "pstack-models.md" pstackModelsSheetText;

  # bootstrap.ts runs `bun install` in scripts/ unless node_modules matches bun.lock.
  # The store is read-only, so node_modules ships prebuilt. A bun.lock change
  # upstream breaks outputHash; take the new hash from the build error.
  pstackPotetoScriptsSrc = pstackSkillsRoot + "/poteto-mode/scripts";
  pstackPotetoNodeModules = pkgs.stdenvNoCC.mkDerivation {
    name = "pstack-poteto-mode-node-modules";
    src = pstackPotetoScriptsSrc;
    nativeBuildInputs = [ pkgs.bun ];
    dontConfigure = true;
    dontFixup = true;
    buildPhase = ''
      export HOME=$TMPDIR
      bun install --frozen-lockfile --production --ignore-scripts --no-progress
    '';
    installPhase = ''
      mv node_modules "$out"
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-2aTzrxVZvURXL+MimBZzH36C6IUmKvxlztu+2NLiLZg=";
  };
  pstackPotetoScripts = pkgs.runCommand "pstack-poteto-mode-scripts" { preferLocalBuild = true; } ''
    cp -r ${pstackPotetoScriptsSrc} "$out"
    chmod -R u+w "$out"
    cp -r ${pstackPotetoNodeModules} "$out/node_modules"
    chmod -R u+w "$out/node_modules"
    { cat "$out/package.json"; printf '\0'; cat "$out/bun.lock"; } | sha256sum | cut -d' ' -f1 \
      > "$out/node_modules/.poteto-mode-tools-install-key"
  '';

  pstackSkillDrv = id: pkgs.runCommand "pstack-skill-${id}" { preferLocalBuild = true; } ''
    mkdir -p "$out"
    shopt -s nullglob
    for f in ${pstackSkillsRoot}/${id}/*; do
      fname="$(basename "$f")"
      if [ "${id}/$fname" = "poteto-mode/scripts" ]; then
        ln -s ${pstackPotetoScripts} "$out/scripts"
      elif [ "$fname" != "SKILL.md" ]; then
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
in
{
  inherit pstackSkillsRoot pstackPrinciples pstackSkills pstackAliases
    pstackTransform pstackPrinciplesSkill pstackModelRoles pstackModelsSheetText
    pstackModelsSheet pstackDrvs pstackAgentText pstackPotetoAppendix pstackPotetoScripts;
}
