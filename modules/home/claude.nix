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
  inherit (lib) getExe optionalAttrs listToAttrs;

  dotClaude = inputs.dotfiles + "/dot_claude";
  homeDir = config.home.homeDirectory;
  claudeCommon = import ./claude-common.nix;
  inherit (claudeCommon) skillTargetDirs disabledMattpocockSkills transformedMattpocockSkills;

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

    This grilling *is* **Think Before Coding** — don't assume, surface confusion,
    present interpretations instead of silently picking one. Two reinforcements
    while you run it:

    - When you give a question's recommended answer, also show the interpretations
      you chose between and why. Don't collapse to one silently.
    - The confusion to surface is yours too. If the code contradicts what the user
      just told you, name the contradiction and stop — don't paper over it.

    ## Close with verifiable goals

    A session that ends in "shared understanding" but no checkable plan isn't
    finished — that's **Goal-Driven Execution**, the principle grilling alone skips.
    Before you stop, turn the agreed plan into success criteria the next agent can
    loop against:

    ```
    1. [step] -> verify: [check]
    2. [step] -> verify: [check]
    ```

    Hand that block to the implementation skill (tdd, executing-plans). Strong
    criteria let it loop without you; "make it work" forces it back to ask.

    ## Observable signals

    You'll know this skill is working when:
    - The user changes their mind mid-grilling — the questions found something they hadn't articulated.
    - CONTEXT.md terms surface unchanged in later sessions; the vocabulary stuck.
    - Implementation plans downstream contain fewer wrong assumptions that need walking back.
  '';

  deepenKarpathyFooter = ''
    ## Karpathy alignment

    The architecture vocabulary already encodes two Karpathy principles — name them
    so this skill composes with the others instead of restating them:

    - **Simplicity First** is the seam rule. "One adapter = hypothetical seam,
      two = real" is just "no abstraction for single-use" — don't add a port until
      a second adapter earns it.
    - **Surgical Changes** governs *execution*, not proposal. Propose freely; once
      the user approves a candidate, every changed line traces to that candidate.
      No drive-by refactors of adjacent code, no reopening what an ADR already settled.

    ## Close with verifiable goals

    "Deepen module X" becomes "tests green before and after" — **Goal-Driven
    Execution**. DEEPENING.md already says the interface is the test surface and
    old shallow-module tests become waste; state that as a loop before any edit:

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
  rtkRewriteHook = pkgs.writeShellScript "rtk-rewrite.sh" ''
    JQ=${getExe pkgs.jq}
    RTK=${getExe pkgs.rtk}

    INPUT=$(cat)
    CMD=$(printf '%s' "$INPUT" | "$JQ" -r '.tool_input.command // empty')

    if [ -z "$CMD" ]; then
      exit 0
    fi

    REWRITTEN=$("$RTK" rewrite "$CMD" 2>/dev/null)
    RTK_EXIT=$?
    case "$RTK_EXIT" in
      0 | 3) ;;
      *) exit 0 ;;
    esac

    if [ "$CMD" = "$REWRITTEN" ]; then
      exit 0
    fi

    # Codex PreToolUse payloads carry turn_id and reject updatedInput;
    # short-circuit to `empty` in that branch. One jq pass folds the
    # turn_id check, tool_input patch, and hookSpecificOutput wrap.
    printf '%s' "$INPUT" | "$JQ" --arg cmd "$REWRITTEN" '
      if has("turn_id") then empty
      else {
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow",
          permissionDecisionReason: "RTK auto-rewrite",
          updatedInput: (.tool_input + { command: $cmd })
        }
      }
      end
    '
  '';
  rtkHookChecksum = pkgs.runCommand "rtk-hook.sha256" { } ''
    ${pkgs.coreutils}/bin/sha256sum ${rtkRewriteHook} \
      | ${pkgs.gnused}/bin/sed 's|  .*|  rtk-rewrite.sh|' > $out
  '';

  # `link` makes every target a tree of `home.file` symlinks pointing at
  # the same /nix/store/...-agent-skills-bundle/<skill>/SKILL.md. Pi's
  # loader de-duplicates discovered skills by realpath, so identical
  # store paths collapse silently across ~/.claude/skills,
  # ~/.pi/agent/skills, ~/.cursor/skills, ~/.codex/skills, ~/.agents/skills.
  linkTarget = dest: { enable = true; inherit dest; structure = "link"; systems = [ ]; };

  # mattpocock/skills promoted buckets. `personal/` and `deprecated/` are
  # excluded per upstream CONTEXT.md. New upstream skills under any bucket
  # auto-load on the next `nix flake update mattpocock-skills`.
  mattpocockBuckets = [ "engineering" "productivity" "misc" ];
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
            && !(builtins.elem name (disabledMattpocockSkills ++ transformedMattpocockSkills))
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
  # (currently just `effect-ts`); any sibling added later auto-loads on
  # `nix flake update effect-ts-skills`. Replaces `bunx skills add Effect-TS/skills`
  # so Nix stays the single source of truth — no runtime mutation of ~/.claude/skills.
  effectSources = { effect-ts = mkSource "effect-ts-skills" "skills" null; };

  # obra/superpowers (the original; flat `skills/<name>/SKILL.md`). Auto-updates
  # on `nix flake update superpowers`. Only `brainstorming` is enabled — every
  # other upstream skill is still discovered into the catalog (so it tracks
  # upstream) but left unbundled (disabled). New skills do NOT auto-enable; add
  # the id here to turn one on. The frad-dotclaude/superpowers *plugin* ships its
  # own brainstorming; claudeDisableSuperpowersPluginBrainstorming below parks
  # just that one so exactly one brainstorming surfaces (the plugin's other
  # skills stay live).
  superpowersSources = { superpowers = mkSource "superpowers" "skills" null; };
  enabledSuperpowersSkills = [ "brainstorming" ];
in
{
  imports = [
    inputs.agent-skills.homeManagerModules.default
    ./claude-activations.nix
  ];

  # === Reproducible files (read-only, dotfiles-sourced) ===
  # `.local/bin/claude` is a stable user-PATH binary that survives store-path
  # churn so macOS TCC and editor integrations don't re-prompt every switch.
  home.file =
    let
      mkRtkFiles = root: {
        "${root}/RTK.md".source = dotClaude + "/RTK.md";
        "${root}/hooks/rtk-rewrite.sh" = {
          source = rtkRewriteHook;
          executable = true;
        };
        "${root}/hooks/.rtk-hook.sha256".source = rtkHookChecksum;
      };
    in
    {
      ".local/bin/claude".source = pkgs.claude-code + "/bin/claude";
      ".claude/CLAUDE.md".source = renderChezmoi (dotClaude + "/claude.md.tmpl");
      "RTK.md".source = dotClaude + "/RTK.md";
      ".claude/statusline-command.sh" = {
        source = dotClaude + "/executable_statusline-command.sh";
        executable = true;
      };
      ".claude/hooks/stop-hook-debug.sh" = {
        source = stopHookDebug;
        executable = true;
      };
    } // mkRtkFiles ".claude" // mkRtkFiles ".codex";

  # === Skills (was modules/home/skills.nix) ===
  programs.agent-skills = {
    enable = true;

    sources = {
      dotfiles-pi = mkSource "dotfiles" "dot_pi/agent/skills"
        "^(git-workflow|review|ralph-loop|web-browser)$";
      dotfiles-claude = mkSource "dotfiles" "dot_claude/skills"
        "^(lazygit)$";
    } // mpSources // effectSources // superpowersSources;

    skills = {
      enable = enabledMattpocockSkills ++ enabledSuperpowersSkills;
      enableAll = builtins.attrNames effectSources;
      explicit = {
        # Skills that need CLI deps symlinked into the bundle dir.
        # mattpocock skills inherit from user PATH (git/gh/jq/bun globally).
        git-workflow = mkSkill "dotfiles-pi" "git-workflow" [ pkgs.git pkgs.gh pkgs.jq ];
        review = mkSkill "dotfiles-pi" "review" [ pkgs.git pkgs.gh pkgs.jq ];
        lazygit = mkSkill "dotfiles-claude" "lazygit" [ pkgs.git pkgs.lazygit ];
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
