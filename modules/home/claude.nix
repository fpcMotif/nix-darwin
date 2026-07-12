{ inputs, pkgs, lib, config, ... }:

# Single source of truth for everything Claude Code under ~/.claude.
# Reproducible state lives here (Nix-managed); runtime/mutable state
# (settings.local.json, plugins/installed_plugins.json, sessions/,
# history.jsonl, file-history/, paste-cache/, projects/, ...) is left
# untouched on purpose.
#
# Files declared here are byte-identical to their counterparts in the
# `dotfiles` flake input, so the dotfiles repo remains the cross-tool
# upstream — chezmoi can still render them on hosts that don't run
# this flake. Nix just installs them as read-only store symlinks.

let
  inherit (lib) optionalAttrs listToAttrs;

  dotClaude = inputs.dotfiles + "/dot_claude";
  homeDir = config.home.homeDirectory;

  # The dotfiles repo uses chezmoi `{{ .chezmoi.homeDir }}` interpolation
  # in two files (CLAUDE.md, settings.json.tmpl). Render them at eval
  # time with a one-token substitution.
  renderChezmoi = src: pkgs.writeText (baseNameOf (toString src)) (
    builtins.replaceStrings
      [ "{{ .chezmoi.homeDir }}" ]
      [ homeDir ]
      (builtins.readFile src)
  );

  mkSource = input: subdir: nameRegex: {
    inherit input subdir;
    filter = { maxDepth = 1; }
      // optionalAttrs (nameRegex != null) { inherit nameRegex; };
  };

  mkSkill = from: path: packages: { inherit from path packages; };

  # Append-only `transform`s for two planning skills (wired in
  # skills.explicit below). Each names the Karpathy principle the skill
  # already embodies — so the skills compose instead of restating one
  # another — and adds the one principle both under-emphasise:
  # Goal-Driven Execution (close with a verifiable loop). `transform`
  # receives the whole SKILL.md including frontmatter; we append after
  # `original` so the YAML stays at the top (never prepend). Footer bodies
  # sit at column 0 inside the '' blocks so Nix de-indentation can't
  # silently reflow the embedded markdown.
  appendKarpathy = body: { original, ... }: original + "\n\n" + body;

  grillKarpathyFooter = ''
    ## Karpathy alignment

    This grilling *is* **Think Before Coding** — don't assume, surface confusion, present interpretations instead of silently picking one. Two reinforcements while you run it:

    - When you give a question's recommended answer, also show the interpretations you chose between and why. Don't collapse to one silently.
    - The confusion to surface is yours too. If the code contradicts what the user just told you, name the contradiction and stop — don't paper over it.

    ## Close with verifiable goals

    A session that ends in "shared understanding" but no checkable plan isn't finished — that's **Goal-Driven Execution**, the principle grilling alone skips. Before you stop, turn the agreed plan into success criteria the next agent can loop against:

    ```
    1. [step] -> verify: [check]
    2. [step] -> verify: [check]
    ```

    Hand that block to the implementation skill (tdd, executing-plans). Strong criteria let it loop without you; "make it work" forces it back to ask.

    ## Observable signals

    You'll know this skill is working when:
    - The user changes their mind mid-grilling — the questions found something they hadn't articulated.
    - CONTEXT.md terms surface unchanged in later sessions; the vocabulary stuck.
    - Implementation plans downstream contain fewer wrong assumptions that need walking back.
  '';

  deepenKarpathyFooter = ''
    ## Karpathy alignment

    The architecture vocabulary already encodes two Karpathy principles — name them so this skill composes with the others instead of restating them:

    - **Simplicity First** is the seam rule. "One adapter = hypothetical seam, two = real" is just "no abstraction for single-use" — don't add a port until a second adapter earns it.
    - **Surgical Changes** governs *execution*, not proposal. Propose freely; once the user approves a candidate, every changed line traces to that candidate. No drive-by refactors of adjacent code, no reopening what an ADR already settled.

    ## Close with verifiable goals

    "Deepen module X" becomes "tests green before and after" — **Goal-Driven Execution**. DEEPENING.md already says the interface is the test surface and old shallow-module tests become waste; state that as a loop before any edit:

    ```
    1. Characterise current behaviour with tests at the target interface -> verify: green on today's code
    2. Deepen the module behind that interface                           -> verify: same tests stay green
    3. Delete the superseded shallow-module tests                        -> verify: suite green, behaviour still covered
    ```

    ## Observable signals

    You'll know this skill is working when:
    - Every proposed candidate passes the deletion test — removing it makes the codebase clearly worse.
    - No proposed seam ships with only one adapter; the second adapter earned it.
    - Tests at the deepened interface survive subsequent internal refactors (they describe behaviour, not implementation).
  '';
  # `link` makes every target a tree of `home.file` symlinks pointing at
  # the same /nix/store/...-agent-skills-bundle/<skill>/SKILL.md. Pi's
  # loader de-duplicates discovered skills by realpath, so identical
  # store paths collapse silently across ~/.claude/skills,
  # ~/.pi/agent/skills, ~/.cursor/skills, ~/.codex/skills, ~/.agents/skills,
  # and the native targets for Factory/Droid, OpenCode, and Crush.
  linkTarget = dest: { enable = true; inherit dest; structure = "link"; systems = [ ]; };

  # Skill picker target dirs. Used both by `programs.agent-skills.targets`
  # below and by the skill-sweep activation scripts — keeping one list
  # means a new target is auto-covered by every sweep.
  skillTargetDirs = {
    agents = ".agents/skills";
    claude = ".claude/skills";
    cursor = ".cursor/skills";
    codex = ".codex/skills";
    xdg-agents = ".config/agents/skills";
    crush = ".config/crush/skills";
    factory = ".factory/skills";
    opencode = ".config/opencode/skills";
    pi = ".pi/agent/skills";
  };
  # The same dirs as a quoted, absolute, space-separated shell list, for the
  # `for dir in …` loops in the activation sweeps below.
  skillTargetDirsSh = lib.concatMapStringsSep " " (d: ''"${homeDir}/${d}"'')
    (lib.attrValues skillTargetDirs);

  # Remove a skill's copy from every picker target dir.
  mkSkillTargetRm = ids: ''
    for dir in ${skillTargetDirsSh}; do
      for skill in ${lib.escapeShellArgs ids}; do
        rm -rf -- "$dir/$skill"
      done
    done
  '';

  # Scrub each id from Claude Desktop sessions: drop its slashCommand entry
  # from every session file (the `grep -lZ` pre-filter skips the jq+mv on the
  # 99% of session files that never mention it, cutting a per-switch
  # O(sessions) spawn storm to O(matches)), then handle its skills-plugin
  # cache dir via `cacheAction` (which sees `$skill` and `$dir`). Shared by the
  # remove-sweep (claudePruneRemovedSkills) and disable-sweep
  # (claudeDisableGrillSkills); they differ only in that cache action.
  # Claude Desktop's session store lives under macOS's ~/Library, so the sweep
  # is empty on Linux — callers still run their portable mkSkillTargetRm part.
  mkSessionSweep = { ids, cacheAction }: lib.optionalString pkgs.stdenv.isDarwin ''
    sessions="${homeDir}/Library/Application Support/Claude/local-agent-mode-sessions"
    if [ -d "$sessions" ]; then
      for skill in ${lib.escapeShellArgs ids}; do
        while IFS= read -r -d "" file; do
          tmp=$(mktemp)
          ${pkgs.jq}/bin/jq --arg command "anthropic-skills:$skill" '
            if (.slashCommands? | type) == "array" then
              .slashCommands = (.slashCommands - [$command])
            else
              .
            end
          ' "$file" > "$tmp" && mv "$tmp" "$file"
        done < <(${pkgs.findutils}/bin/find "$sessions" -type f -name "local_*.json" \
                   -exec ${pkgs.gnugrep}/bin/grep -lZ "anthropic-skills:$skill" {} +)

        while IFS= read -r -d "" dir; do
          ${cacheAction}
        done < <(${pkgs.findutils}/bin/find "$sessions/skills-plugin" -type d -path "*/skills/$skill" -print0 2>/dev/null || true)
      done
    fi
  '';

  # mattpocock/skills promoted buckets. `personal/` and `deprecated/` are
  # excluded per upstream CONTEXT.md. New upstream skills under any bucket
  # auto-load on the next `nix flake update mattpocock-skills`.
  mattpocockBuckets = [ "engineering" "productivity" "misc" ];
  # Skills genuinely turned off — kept out of every picker.
  disabledMattpocockSkills = [ "grill-me" ];
  # Lean curation: niche / one-off skills trimmed from proactive discovery to
  # keep the model's auto-loaded skill catalog compact. Proactive (model)
  # discovery stays ON for the curated set — this only prunes the long tail so
  # discovery context stays cheap. Treated exactly like disabledMattpocockSkills
  # (filtered out of bucket discovery, so they leave the bundle and home-manager
  # drops their picker symlinks), grouped separately so the rationale
  # (signal/noise, not "broken") stays legible. Re-add an id to a bucket by
  # removing it here, or surface it on demand with `/<name>` once re-enabled.
  leanExcludedMattpocockSkills = [
    "caveman" # token-compression chat mode; niche
    "git-guardrails-claude-code" # one-time git-hook setup, not a recurring workflow
    "migrate-to-shoehorn" # @total-typescript/shoehorn-specific test migration
    "scaffold-exercises" # course / exercise authoring
    "setup-matt-pocock-skills" # runtime installer that fights this Nix-managed setup
    "setup-pre-commit" # Husky / lint-staged JS setup, one-off
    "zoom-out" # situational reflection; marginal proactive value
  ];
  # Skills removed from the curated sources entirely. These should not be
  # merely disabled/catalogued; prune stale target copies after rebuilds.
  removedSkillIds = [ "git-workflow" "lazygit" ];
  # Claude Code plugins disabled on the GLOBAL surface (CLI + Desktop) by
  # flipping their enabledPlugins flag off each rebuild — see
  # claudeDisableGlobalMcpPlugins below. context7 is dropped outright; the
  # code-context plugin's deepwiki + exa MCP servers are moved to per-project
  # opt-in (templates/mcp/code-context.mcp.json, docs/adr/0003). claude.ai
  # connectors are account-side and unaffected.
  #
  # gitflow + git extend the bundle's removedSkillIds intent to the plugin
  # surface: removedSkillIds drops git-workflow/lazygit from the curated
  # bundle, but those removals never reached the equivalent plugin skills.
  # gitflow ships 6 git-flow automation skills (start/finish-{feature,hotfix,
  # release}); git ships commit/commit-and-push/config-git/update-gitignore,
  # which overlap the /lazygit workflow. Disabling both flips their ~10 skills
  # out of Claude Code's always-on startup catalog via the same lever.
  disabledClaudePlugins = [
    "context7@claude-plugins-official"
    "code-context@frad-dotclaude"
    "gitflow@frad-dotclaude"
    "git@frad-dotclaude"
  ];
  # NOT disabled — still enabled, just sourced via skills.explicit below so a
  # Karpathy `transform` can be attached. They only leave bucket auto-discovery
  # because a skill present in both the allowlist and `explicit` makes
  # selectSkills throw on a duplicate id.
  transformedMattpocockSkills = [ "grill-with-docs" "improve-codebase-architecture" ];
  mpSources = listToAttrs (map
    (b: {
      name = "mp-${b}";
      value = mkSource "mattpocock-skills" "skills/${b}" null;
    })
    mattpocockBuckets);
  enabledMattpocockSkills =
    let
      bucketSkillNames = b:
        let
          root = inputs.mattpocock-skills + "/skills/${b}";
          entries = builtins.readDir root;
        in
        builtins.attrNames (lib.filterAttrs
          (name: type:
            type == "directory"
            && builtins.pathExists (root + "/${name}/SKILL.md")
            && !(builtins.elem name (disabledMattpocockSkills ++ transformedMattpocockSkills ++ leanExcludedMattpocockSkills))
          )
          entries);
    in
    lib.unique (lib.concatMap bucketSkillNames mattpocockBuckets);

  # Diagnostic wrapper for Claude Code Stop hooks. Intercepts a plugin's
  # Stop hook invocation, captures stdin/stdout/stderr/exit-code/duration
  # to ~/.claude/debug-logs/stop-hooks.log, then forwards everything
  # transparently so plugin behaviour is unchanged.
  #
  # Used to diagnose "Stop hook error: Failed with non-blocking status
  # code: No stderr output" — pinpoints which plugin hook silently exits
  # non-zero. Activated by claudeStopHookDebug below, which rewrites the
  # 3 installed plugin Stop hook configs to dispatch through this script.
  stopHookDebug = pkgs.writeShellScript "stop-hook-debug" ''
    set -uo pipefail

    LOG_DIR="''${CLAUDE_STOP_HOOK_LOG_DIR:-$HOME/.claude/debug-logs}"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/stop-hooks.log"

    HOOK_ID="''${1:-unknown}"
    shift || true

    STDIN_FILE=$(mktemp -t claude-stop-stdin.XXXXXX)
    STDOUT_FILE=$(mktemp -t claude-stop-stdout.XXXXXX)
    STDERR_FILE=$(mktemp -t claude-stop-stderr.XXXXXX)
    trap 'rm -f "$STDIN_FILE" "$STDOUT_FILE" "$STDERR_FILE"' EXIT

    cat > "$STDIN_FILE"

    START_NS=$(${pkgs.coreutils}/bin/date +%s%N)
    "$@" < "$STDIN_FILE" > "$STDOUT_FILE" 2> "$STDERR_FILE"
    EXIT_CODE=$?
    END_NS=$(${pkgs.coreutils}/bin/date +%s%N)
    DURATION_MS=$(( (END_NS - START_NS) / 1000000 ))

    {
      printf '===== %s hook=%s exit=%d duration=%dms\n' \
        "$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$HOOK_ID" "$EXIT_CODE" "$DURATION_MS"
      printf -- '--- CWD: %s\n' "$PWD"
      printf -- '--- COMMAND: %s\n' "$*"
      printf -- '--- STDIN (%d bytes):\n' "$(${pkgs.coreutils}/bin/wc -c < "$STDIN_FILE")"
      ${pkgs.coreutils}/bin/head -c 8192 "$STDIN_FILE"; printf '\n'
      printf -- '--- STDOUT (%d bytes):\n' "$(${pkgs.coreutils}/bin/wc -c < "$STDOUT_FILE")"
      ${pkgs.coreutils}/bin/head -c 8192 "$STDOUT_FILE"; printf '\n'
      printf -- '--- STDERR (%d bytes):\n' "$(${pkgs.coreutils}/bin/wc -c < "$STDERR_FILE")"
      ${pkgs.coreutils}/bin/head -c 8192 "$STDERR_FILE"; printf '\n'
      printf '===== end\n\n'
    } >> "$LOG_FILE"

    ${pkgs.coreutils}/bin/cat "$STDOUT_FILE"
    ${pkgs.coreutils}/bin/cat "$STDERR_FILE" >&2

    exit "$EXIT_CODE"
  '';

  # Effect-TS/skills. Upstream publishes flat under `skills/<name>/SKILL.md`
  # (currently just `effect-ts`). This source stays DEFINED but is no longer
  # globally enabled (see `enableAll = [ ]` below) — effect-ts is dependency-
  # conditional, so it is per-project devShell-scoped via
  # templates/effect-skills/devshell.flake.nix instead of fanned into every
  # repo's picker dirs. Keeping the source here documents the pin and makes a
  # global re-enable a one-line change.
  effectSources = { effect-ts = mkSource "effect-ts-skills" "skills" null; };

  # obra/superpowers (the original; flat `skills/<name>/SKILL.md`). Only
  # `brainstorming` is sourced from the Nix input. We intentionally do not
  # discover the rest of the upstream catalog because disabled git/worktree
  # workflow skills still show up in audits and picker metadata. New
  # superpowers skills require an explicit regex/allowlist change.
  superpowersSources = { superpowers = mkSource "superpowers" "skills" "^(brainstorming)$"; };
  enabledSuperpowersSkills = [ "brainstorming" ];

  # mattpocock/skills `in-progress/` bucket holds unpromoted skills. We pull in
  # ONLY `teach` — a stateful /teach learning-workspace skill that is
  # `disable-model-invocation: true` (slash-command only), bundling its
  # *-FORMAT.md templates alongside SKILL.md. Same regex-restricted-source
  # pattern as superpowers' brainstorming: the bucket also ships a `review`
  # skill whose id collides with the dotfiles-pi `review` below, so an
  # unrestricted source here would make discoverCatalog throw on the duplicate;
  # `^(teach)$` keeps review and the half-baked writing-* skills out.
  inProgressSources = { mp-in-progress = mkSource "mattpocock-skills" "skills/in-progress" "^(teach)$"; };
  enabledInProgressSkills = [ "teach" ];
in
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  # === Reproducible files (read-only, dotfiles-sourced) ===
  # `.local/bin/claude` is a stable user-PATH binary that survives store-path
  # churn so macOS TCC and editor integrations don't re-prompt every switch.
  home.file =
    let
      # Locally-authored jj skill (no dotfiles upstream yet). Installed via plain
      # home.file symlinks rather than a programs.agent-skills `path` source: the
      # module CAN source local paths, but it wraps a `path` source in a
      # platform-stamped copy derivation and reads it back (IFD), which makes
      # `nix flake check` fail to evaluate the x86_64-linux hosts from darwin
      # ("platform mismatch"). A plain path symlink is platform-agnostic. The same
      # store dir is linked into every picker target; Pi's realpath de-dup
      # collapses them, exactly like agent-skills' `link` targets.
      jjSkillFiles = listToAttrs (map
        (dir: { name = "${dir}/jj"; value = { source = ./skills/jj; }; })
        (lib.attrValues skillTargetDirs));
    in
    {
      ".local/bin/claude".source = pkgs.claude-code + "/bin/claude";
      ".claude/CLAUDE.md".source = renderChezmoi (dotClaude + "/claude.md.tmpl");
      ".claude/statusline-command.sh" = {
        source = dotClaude + "/executable_statusline-command.sh";
        executable = true;
      };
      ".claude/hooks/stop-hook-debug.sh" = {
        source = stopHookDebug;
        executable = true;
      };
    } // jjSkillFiles;

  # === Stop hook diagnostic instrumentation ===
  # Idempotently rewrites the 3 installed plugin Stop hook configs to
  # dispatch through stop-hook-debug.sh, which logs stdin/stdout/stderr/
  # exit-code to ~/.claude/debug-logs/stop-hooks.log. Original commands
  # are preserved in a sibling `.orig` file the first time we touch them
  # so they can be restored (`mv hooks.json.orig hooks.json`) when
  # diagnosis is done and this block is removed.
  #
  # Re-runs on every `darwin-rebuild switch`. Plugin updates that
  # refresh the cached hooks.json will revert the wrapping; next switch
  # re-applies it.
  home.activation.claudeStopHookDebug = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wrap_stop_hook() {
      local hook_id="$1" file="$2"
      [ -f "$file" ] || { echo "stop-hook-debug: missing $file, skipping" >&2; return 0; }

      # Already wrapped? `any` over all entries (not just [0]) avoids
      # re-wrap stacking if a plugin update reorders Stop hook entries.
      if ${pkgs.jq}/bin/jq -e --arg w "stop-hook-debug.sh" \
          '[.hooks.Stop[]?.hooks[]?.command | contains($w)] | any' "$file" >/dev/null 2>&1; then
        return 0
      fi

      [ -f "$file.orig" ] || cp "$file" "$file.orig"

      local tmp
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq \
        --arg wrapper "${homeDir}/.claude/hooks/stop-hook-debug.sh" \
        --arg hookid "$hook_id" \
        '.hooks.Stop |= map(.hooks |= map(.command = ($wrapper + " " + $hookid + " " + .command)))' \
        "$file" > "$tmp" && mv "$tmp" "$file"
      echo "stop-hook-debug: wrapped $hook_id ($file)" >&2
    }

    base="${homeDir}/.claude/plugins/cache"
    wrap_stop_hook ralph-loop  "$base/claude-plugins-official/ralph-loop/1.0.0/hooks/hooks.json"
    wrap_stop_hook codex       "$base/openai-codex/codex/1.0.4/hooks/hooks.json"
  '';

  # Git-flow style automation was removed from the curated sources instead of
  # parked. Delete any stale mirrors or cached session copies left by earlier
  # generations so it cannot linger as a selectable skill.
  home.activation.claudePruneRemovedSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${DRY_RUN:-}" ]; then
      echo "claude-prune-removed-skills: would prune removed skills: ${lib.escapeShellArgs removedSkillIds}" >&2
    else
      ${mkSkillTargetRm removedSkillIds}
      ${mkSessionSweep { ids = removedSkillIds; cacheAction = ''rm -rf -- "$dir"''; }}
    fi
  '';

  # Surge ships its agent skill inside the app bundle. Keep live symlinks to the
  # bundle instead of copying it into the Nix store so Surge updates refresh it.
  # Surge.app is a macOS bundle; Linux hosts must not reference /Applications.
  home.activation.surgeAgentSkillSymlinks = lib.mkIf pkgs.stdenv.isDarwin (lib.hm.dag.entryAfter [ "agent-skills" ] ''
    source="/Applications/Surge.app/Contents/Resources/Skills/surge"
    if [ -d "$source" ] && [ -f "$source/SKILL.md" ]; then
      for dir in ${skillTargetDirsSh}; do
        ${pkgs.coreutils}/bin/mkdir -p "$dir"
        target="$dir/surge"
        ${pkgs.coreutils}/bin/rm -rf -- "$target"
        ${pkgs.coreutils}/bin/ln -s -- "$source" "$target"
      done
    else
      echo "surge-agent-skill: missing $source, skipping" >&2
    fi
  '');

  # Claude can cache Anthropic-provided skills outside the Nix-managed skill
  # targets. Keep the disabled skills (currently grill-me — grill-with-docs is
  # preserved as the preferred planning skill) out of every picker source plus
  # active Claude Desktop sessions and the skills-plugin cache.
  home.activation.claudeDisableGrillSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${mkSkillTargetRm disabledMattpocockSkills}
    ${mkSessionSweep {
      ids = disabledMattpocockSkills;
      cacheAction = ''
        parent="$(${pkgs.coreutils}/bin/dirname "$dir")"
        disabled="$parent/../skills-disabled"
        mkdir -p "$disabled"
        rm -rf -- "$disabled/$skill"
        mv -- "$dir" "$disabled/$skill"
      '';
    }}
  '';

  # The official Anthropic `code-simplifier` plugin (claude-plugins-official)
  # and frad-dotclaude's `refactor` plugin BOTH ship an agent named
  # `code-simplifier`, so both surface (code-simplifier:code-simplifier vs
  # refactor:code-simplifier). Keep the official one canonical and park ONLY
  # the refactor plugin's duplicate agent — its `/refactor`, `/refactor-project`
  # commands and `best-practices` skill have no official equivalent and stay
  # live (separate `commands`/`skills` entries we never touch).
  #
  # Two levers are needed because Claude discovers plugin agents BOTH ways:
  # refactor's plugin.json lists the agent explicitly under `agents`, while the
  # official plugin omits `agents` entirely yet its agent still loads — proving
  # convention discovery of `agents/*.md`. So we (1) strip the explicit entry
  # from plugin.json (backing up plugin.json.orig once, like claudeStopHookDebug)
  # and (2) park agents/code-simplifier.md into a sibling agents-disabled/ dir
  # (like the brainstorming block). Non-destructive, version-globbed, re-runs
  # each switch so a plugin update that restores either lever is re-applied.
  home.activation.claudeDisableRefactorPluginCodeSimplifier = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for plugin_dir in "${homeDir}"/.claude/plugins/cache/frad-dotclaude/refactor/*; do
      [ -d "$plugin_dir" ] || continue
      manifest="$plugin_dir/.claude-plugin/plugin.json"

      if [ -f "$manifest" ] && ${pkgs.jq}/bin/jq -e \
          '[.agents[]? | select(endswith("code-simplifier.md"))] | any' "$manifest" >/dev/null 2>&1; then
        [ -f "$manifest.orig" ] || cp "$manifest" "$manifest.orig"
        tmp=$(mktemp)
        ${pkgs.jq}/bin/jq \
          '.agents |= map(select(endswith("code-simplifier.md") | not))' \
          "$manifest" > "$tmp" && mv "$tmp" "$manifest"
        echo "refactor-dedup: stripped code-simplifier agent from $manifest" >&2
      fi

      agent="$plugin_dir/agents/code-simplifier.md"
      if [ -f "$agent" ]; then
        disabled="$plugin_dir/agents-disabled"
        mkdir -p "$disabled"
        rm -rf -- "$disabled/code-simplifier.md"
        mv -- "$agent" "$disabled/code-simplifier.md"
        echo "refactor-dedup: parked $agent" >&2
      fi
    done
  '';

  # === settings.json: declarative seed, mutable thereafter ===
  # Claude rewrites theme, env vars, and plugin state into this file at
  # runtime, so a hard symlink would fight the app. Seed once on first
  # rebuild, then leave alone — same pattern as opencode.nix.
  home.activation.claudeSettingsSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="${homeDir}/.claude/settings.json"
    if [ ! -e "$target" ]; then
      run install -m 0644 ${renderChezmoi (dotClaude + "/settings.json.tmpl")} "$target"
    fi
  '';

  # === Disable context7 / code-context on the global surface ===
  # settings.json is otherwise seed-once-then-mutable (above), but
  # enabledPlugins is exactly the kind of "reproducible disable" lever the
  # grill-me / refactor-dedup blocks already use: flip the named plugins off on
  # every rebuild so a UI re-enable or a plugin-cache refresh can't quietly
  # bring back context7's MCP server or code-context's deepwiki/exa servers
  # globally. Idempotent (only rewrites when a flag actually changes) and runs
  # after the seed so the file exists. The plugins stay *installed* — projects
  # opt back into deepwiki/exa via a local .mcp.json
  # (templates/mcp/code-context.mcp.json). claude.ai connectors are account-side
  # and untouched. See docs/adr/0003-scope-code-context-mcp-per-project.md.
  home.activation.claudeDisableGlobalMcpPlugins = lib.hm.dag.entryAfter [ "claudeSettingsSeed" ] ''
    target="${homeDir}/.claude/settings.json"
    if [ ! -f "$target" ]; then
      echo "claude-disable-mcp-plugins: missing $target, skipping" >&2
    else
      tmp=$(mktemp)
      if ${pkgs.jq}/bin/jq \
          --argjson ids ${lib.escapeShellArg (builtins.toJSON disabledClaudePlugins)} \
          'reduce $ids[] as $id (.; .enabledPlugins[$id] = false)' \
          "$target" > "$tmp" && ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$target"; then
        mv -- "$tmp" "$target"
        echo "claude-disable-mcp-plugins: disabled ${lib.concatStringsSep ", " disabledClaudePlugins}" >&2
      else
        rm -f -- "$tmp"
      fi
    fi
  '';

  # === MCP: register fff (frecency-ranked, git-aware file search) ===
  # `claude mcp add -s user` is the only supported way to write
  # ~/.claude.json's mcpServers — that file carries other CLI-managed state
  # (auth, project registry) we don't want to hand-roll with jq the way
  # claudeDesktopMcpScaffold does for claude_desktop_config.json in
  # lsp.nix (that file's shape is simple enough to own; this one isn't).
  #
  # Idempotency compares the *registered command path* to the current
  # ${pkgs.martin.fff-mcp} store path rather than just "does fff exist" —
  # every fff-mcp version bump gets a new store path, and a stale
  # registration would silently break the moment `nix-collect-garbage`
  # reaps the old one. Re-registering on every switch keeps it pinned to
  # a path this generation actually holds a GC root on.
  home.activation.claudeMcpFff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeBin="${pkgs.claude-code}/bin/claude"
    fffBin="${pkgs.martin.fff-mcp}/bin/fff-mcp"
    target="${homeDir}/.claude.json"

    currentCmd=""
    if [ -f "$target" ]; then
      currentCmd=$(${pkgs.jq}/bin/jq -r '.mcpServers.fff.command // empty' "$target" 2>/dev/null || true)
    fi

    if [ ! -x "$claudeBin" ]; then
      echo "claude-mcp-fff: claude CLI not found, skipping" >&2
    elif [ "$currentCmd" = "$fffBin" ]; then
      :
    elif [ -n "''${DRY_RUN:-}" ]; then
      echo "claude-mcp-fff: would (re)register fff -> $fffBin (was: ''${currentCmd:-none})" >&2
    else
      "$claudeBin" mcp remove -s user fff >/dev/null 2>&1 || true
      if "$claudeBin" mcp add -s user fff -- "$fffBin" >&2; then
        echo "claude-mcp-fff: registered fff -> $fffBin" >&2
      else
        echo "claude-mcp-fff: failed to register fff (see above)" >&2
      fi
    fi
  '';

  # === Skills (was modules/home/skills.nix) ===
  programs.agent-skills = {
    enable = true;

    sources = {
      dotfiles-pi = mkSource "dotfiles" "dot_pi/agent/skills"
        "^(review|ralph-loop|web-browser)$";
    } // mpSources // effectSources // superpowersSources // inProgressSources;

    skills = {
      enable = enabledMattpocockSkills ++ enabledSuperpowersSkills ++ enabledInProgressSkills;
      # effect-ts is no longer globally bundled. It was the one bundled skill
      # that is genuinely dependency-conditional: pure router noise in every
      # non-Effect repo, and version-blind vs the repo's installed `effect` in
      # Effect repos. It is now PER-PROJECT devShell-scoped — `nix develop` an
      # Effect repo that ships templates/effect-skills/devshell.flake.nix and a
      # copy-tree shellHook materialises effect-ts into that repo's
      # .claude/.agents picker dirs only. effectSources stays defined (above)
      # for reuse / trivial re-enable: `enableAll = builtins.attrNames effectSources;`.
      enableAll = [ ];
      explicit = {
        # Skills that need CLI deps symlinked into the bundle dir.
        # mattpocock skills inherit from user PATH (git/gh/jq/bun globally).
        review = mkSkill "dotfiles-pi" "review" [ pkgs.git pkgs.gh pkgs.jq ];
        ralph-loop = mkSkill "dotfiles-pi" "ralph-loop" [ ];
        web-browser = mkSkill "dotfiles-pi" "web-browser" [ ];

        # Re-added from the engineering bucket (see disabledMattpocockSkills)
        # so `transform` can append the Karpathy-alignment footer to each.
        grill-with-docs = mkSkill "mp-engineering" "grill-with-docs" [ ] // {
          transform = appendKarpathy grillKarpathyFooter;
        };
        improve-codebase-architecture = mkSkill "mp-engineering" "improve-codebase-architecture" [ ] // {
          transform = appendKarpathy deepenKarpathyFooter;
        };
      };
    };

    targets = lib.mapAttrs (_: linkTarget) skillTargetDirs;

    excludePatterns = [ ];
  };
}
