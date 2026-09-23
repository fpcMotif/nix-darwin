{ inputs, pkgs, lib, config, ... }:

# Single source of truth for everything Claude Code under ~/.claude.
# Reproducible state lives here (Nix-managed); runtime/mutable state
# (settings.local.json, plugins/installed_plugins.json, sessions/,
# history.jsonl, file-history/, paste-cache/, projects/, ...) is left
# untouched on purpose.
#
let
  inherit (lib) optionalAttrs listToAttrs;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  homeDir = config.home.homeDirectory;
  mkSource = input: subdir: nameRegex: {
    inherit input subdir;
    filter = { maxDepth = 1; }
      // optionalAttrs (nameRegex != null) { inherit nameRegex; };
  };

  mkSkill = from: path: packages: { inherit from path packages; };

  guideCatalog = import ./agent-instructions/guides.nix { inherit lib pkgs; };

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
    # Custom target — Antigravity CLI (`agy`). Its own `/skills` panel
    # documents this as the "Shared" discovery path; it does not read
    # `.agents/skills`, unlike every other target above.
    gemini = ".gemini/skills";
  };
  # The same dirs as a quoted, absolute, space-separated shell list, for the
  # `for dir in …` loops in the activation sweeps below.
  skillTargetDirsSh = lib.concatMapStringsSep " " (d: ''"${homeDir}/${d}"'')
    (lib.attrValues skillTargetDirs);

  # Dirs that actually receive skill links. Droid scans BOTH its native
  # ~/.factory/skills AND the shared ~/.agents/skills (a hardcoded
  # `.factory/.factory-dev/.agents/.agent` compat list — no setting turns it
  # off) and enforces unique skill names, so linking the bundle into both
  # dirs surfaced every skill as a "Duplicate skill" diagnostic in its TUI.
  # Droid gets everything via ~/.agents/skills; the factory dir stays in
  # skillTargetDirs only so the sweeps keep pruning stale copies there.
  skillLinkDirs = removeAttrs skillTargetDirs [ "factory" ];

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
  mkSessionSweep = { ids, cacheAction }: lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
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
  # misc retired 2026-09-09: every skill it held was lean-excluded.
  mattpocockBuckets = [ "engineering" "productivity" ];
  # Skills genuinely turned off. Kept out of every picker dir AND out of the
  # Claude Code plugin surface — since mattpocock-skills@claude-plugins-official
  # was installed, the plugin is the one route that can still reach us with an
  # id this list refuses (see claudePrunePluginSkills / deniedPluginSkills).
  disabledMattpocockSkills = [
    "grill-me" # the `grilling` + `grill-with-docs` pairing is the tradeoff we want
    # setup-matt-pocock-skills was excluded here as a "runtime installer that
    # fights this Nix-managed setup". Re-enabled 2026-08-20: it writes only
    # per-repo files — docs/agents/{issue-tracker,domain,triage-labels}.md and
    # an `## Agent skills` block in the repo's CLAUDE.md/AGENTS.md — and never
    # touches ~/.claude or the bundle, so it does not contend with this module.
    # to-spec / to-tickets / triage are unusable without the config it writes.
  ];
  # Lean curation: niche / one-off skills trimmed from proactive discovery to
  # keep the model's auto-loaded skill catalog compact. Proactive (model)
  # discovery stays ON for the curated set — this only prunes the long tail so
  # discovery context stays cheap. Treated exactly like disabledMattpocockSkills
  # (filtered out of bucket discovery, so they leave the bundle and home-manager
  # drops their picker symlinks), grouped separately so the rationale
  # (signal/noise, not "broken") stays legible. Re-add an id to a bucket by
  # removing it here, or surface it on demand with `/<name>` once re-enabled.
  # `caveman` and `zoom-out` used to sit here; upstream deleted both, so the
  # entries excluded nothing — unit-skill-hygiene now fails on a dead term.
  # Empty since 2026-09-09: its four entries were the whole misc bucket, which
  # is no longer discovered. Keep the list; a future bucket may need it.
  leanExcludedMattpocockSkills = [ ];
  # Every id we refuse to carry, for the all-targets picker sweep. None is in
  # the bundle, but the external `skills` CLI (~/.agents/.skill-lock.json)
  # re-installs some as real dirs under ~/.agents/skills — exactly the leak
  # these lists forbid — so the sweep covers the union, not just the disabled.
  excludedSkillIds = disabledMattpocockSkills ++ leanExcludedMattpocockSkills;
  # Skills removed from the curated sources entirely. These should not be
  # merely disabled/catalogued; prune stale target copies after rebuilds.
  removedSkillIds = [ "git-workflow" "lazygit" "ralph-loop" ];
  # Claude Code plugins disabled on the GLOBAL surface (CLI + Desktop) by
  # flipping their enabledPlugins flag off each rebuild — see
  # claudeSettingsOwnership below. claude.ai connectors are
  # account-side and unaffected. Currently empty — every plugin previously
  # listed here has since been uninstalled outright instead of parked; add an
  # id back to park (disable-but-keep-installed) rather than uninstall it.
  disabledClaudePlugins = [ ];

  # === auto-memory: nix-owned off switch ===
  # Claude Code writes and consolidates its own memory files under
  # ~/.claude/projects/<sanitized-cwd>/memory/. Memory here is hand-curated,
  # so both halves of the feature are pinned off:
  #
  #   autoMemoryEnabled — the feature as a whole. When false Claude neither
  #                       READS nor writes that directory, so MEMORY.md stops
  #                       being injected into context as well; anything that
  #                       must stay loaded belongs in ~/.claude/CLAUDE.md,
  #                       which is read independently of this key.
  #   autoDreamEnabled  — background consolidation ("dreaming"). Moot while
  #                       auto-memory is off, but it resolves independently
  #                       (unset falls back to a server-side gate), so it is
  #                       set explicitly rather than left to inherit whatever
  #                       that gate defaults to.
  #
  # Nothing is deleted: the existing memory dirs stay on disk, they just stop
  # being read or appended to. Re-asserted every switch by
  # claudeSettingsOwnership, for the same reason as enabledPlugins —
  # both are one keystroke away in the in-app toggle (`tengu_auto_memory_toggled`
  # writes the key straight back), and a flip back on silently resumes writing.
  claudeMemorySettings = {
    autoMemoryEnabled = false;
    autoDreamEnabled = false;
  };

  # === worktree: nix-owned symlink dirs ===
  # Claude Code worktrees symlink these directories back to the main
  # checkout instead of duplicating them per worktree (docs/en/worktrees).
  # User-scope on purpose — applies to every repo's worktrees; repos without
  # the dirs (this one included) are unaffected. `sparsePaths`, the other
  # half of the same feature, is deliberately NOT set here: it is a per-repo
  # monorepo optimization and belongs in that repo's own .claude/settings.json.
  claudeWorktreeSettings = {
    symlinkDirectories = [ "node_modules" ".cache" ];
  };

  # === permissions: nix-owned, authoritative ===
  # Transcribed verbatim from the live ~/.claude/settings.json on 2026-08-21
  # (110/5/27 allow/deny/ask rules, defaultMode bypassPermissions), INCLUDING
  # its current allow/deny split: rm -rf /, rm -rf ~, git push --force, .env/
  # .pem reads, shell rc read+write, and ~/Library/** all live in `allow`
  # below — only ~/.ssh, ~/.aws, ~/.gnupg and Keychains are denied. That is
  # the live file's actual categorization as of this date, kept as-is by
  # explicit choice rather than "corrected" into claudeDenyRules; see the
  # comment above that list. The seed (settings.json.tmpl) only ever runs on
  # a machine with NO settings.json, so none of this was reproducible before:
  # a fresh host got 13 allow rules and nothing guarding ~/.ssh.
  #
  # claudeSettingsOwnership re-writes these four keys on every switch, so they
  # survive a `/permissions` edit, a UI toggle, or a wiped settings.json.
  # AUTHORITATIVE: a rule added at runtime and not listed here is dropped on the
  # next switch. Add it here instead — that is the point of the block.
  #
  # Rule semantics (docs/en/permissions): evaluated deny → ask → allow, first
  # match wins, and specificity does NOT reorder them. So a deny beats an allow
  # for the same path, and an ask beats a more specific allow.
  claudeAllowRules = [
    "Bash(cliproxyapi -codex-login)"
    "Bash(cliproxyapi:*)"
    "Bash(lsof:*)"
    "Bash(xargs kill -9)"
    "Bash(nix:*)"
    "Bash(nix-build:*)"
    "Bash(nix-shell:*)"
    "Bash(home-manager:*)"
    "Bash(just:*)"
    "Bash(make:*)"
    "Bash(cargo:*)"
    "Bash(rustc:*)"
    "Bash(rustup:*)"
    "Bash(rustfmt:*)"
    "Bash(bun:*)"
    "Bash(bunx:*)"
    "Bash(pnpm:*)"
    "Bash(node:*)"
    "Bash(tsx:*)"
    "Bash(tsc:*)"
    "Bash(deno:*)"
    "Bash(biome:*)"
    "Bash(prettier:*)"
    "Bash(eslint:*)"
    "Bash(vitest:*)"
    "Bash(uv:*)"
    "Bash(uvx:*)"
    "Bash(python3:*)"
    "Bash(ruff:*)"
    "Bash(pytest:*)"
    "Bash(mypy:*)"
    "Bash(pyright:*)"
    "Bash(go:*)"
    "Bash(gofmt:*)"
    "Bash(swift:*)"
    "Bash(swiftc:*)"
    "Bash(fd:*)"
    "Bash(eza:*)"
    "Bash(bat:*)"
    "Bash(rg:*)"
    "Bash(dust:*)"
    "Bash(procs:*)"
    "Bash(btm:*)"
    "Bash(delta:*)"
    "Bash(zoxide:*)"
    "Bash(jq:*)"
    "Bash(yq:*)"
    "Bash(ast-grep:*)"
    "Bash(sg:*)"
    "Bash(codedb:*)"
    "Bash(gh:*)"
    "Bash(git status:*)"
    "Bash(git diff:*)"
    "Bash(git log:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(git stash list)"
    "Bash(mkdir:*)"
    "Bash(ln:*)"
    "Read(~/.claude/**)"
    "Edit(~/.claude/**)"
    "Write(~/.claude/**)"
    "Read(~/.agents/**)"
    "mcp__fff__find_files"
    "mcp__fff__grep"
    "mcp__fff__multi_grep"

    # Mirrors the live settings.json's `allow` list verbatim from here down —
    # these are the entries a stricter config would put in claudeDenyRules
    # (see the comment there), but live keeps them here, so this does too.
    "Bash(rm -rf /)"
    "Bash(rm -rf /*)"
    "Bash(rm -rf ~)"
    "Bash(rm -rf ~/*)"
    "Bash(git push --force:*)"
    "Bash(git push -f:*)"
    "Read(**/.env)"
    "Read(**/.env.*)"
    "Read(**/*.pem)"
    "Read(~/.netrc)"
    "Read(~/.npmrc)"
    "Read(~/.pypirc)"
    "Read(~/.docker/config.json)"
    "Read(~/.config/gh/**)"
    "Read(~/.claude.json)"
    "Read(~/.claude/projects/**/*.jsonl)"
    "Read(~/.claude/sessions/**)"
    "Read(~/.claude/session-env/**)"
    "Read(~/.claude/history.jsonl)"
    "Read(~/.zshrc)"
    "Read(~/.zshenv)"
    "Read(~/.zprofile)"
    "Read(~/.bashrc)"
    "Read(~/.bash_profile)"
    "Read(~/.zsh_history)"
    "Read(~/.bash_history)"
    "Read(~/.viminfo)"
    "Read(~/.zsh_sessions/**)"
    "Edit(~/.zshrc)"
    "Write(~/.zshrc)"
    "Edit(~/.zshenv)"
    "Write(~/.zshenv)"
    "Edit(~/.zprofile)"
    "Write(~/.zprofile)"
    "Edit(~/.bashrc)"
    "Write(~/.bashrc)"
    "Edit(~/.bash_profile)"
    "Write(~/.bash_profile)"
    "Bash(zed:*)"
    "Bash(zed-nightly:*)"
    "Read(~/.config/zed/**)"
    "Edit(~/.config/zed/**)"
    "Write(~/.config/zed/**)"
  ] ++ lib.optionals isDarwin [
    # macOS-only commands and home paths stay out of Linux settings and
    # activation scripts.
    "Bash(darwin-rebuild:*)"
    "Bash(xcrun:*)"
    "Read(~/Library/Application Support/Claude/config.json)"
    "Read(~/Library/**)"
  ];

  # Minimal deny list, kept intentionally short to mirror the live
  # ~/.claude/settings.json verbatim (2026-08-21): only credential-bearing
  # directories are denied here. Everything a stricter config would also deny
  # — rm -rf /, rm -rf ~, git push --force, .env/.pem reads, shell rc
  # read+write, ~/Library/** — sits in claudeAllowRules above instead, by
  # explicit choice, even though defaultMode is bypassPermissions and none of
  # it is gated by a prompt as a result. grill-me is folded in via
  # deniedPluginSkills below, not restated here.
  #
  # ~/.claude/managed-settings-privacy.json, which used to be this list's
  # source, is a file Claude Code does NOT read (the real managed path is
  # /Library/Application Support/ClaudeCode/managed-settings.json — the
  # shipped binary has 30 references to that name and none to the privacy
  # one); it is inert and can be deleted.
  claudeDenyRules = [
    "Read(~/.ssh/**)"
    "Read(~/.aws/**)"
    "Read(~/.gnupg/**)"
  ] ++ lib.optionals isDarwin [
    "Read(~/Library/Keychains/**)"
    "Edit(~/Library/**)"
    "Write(~/Library/**)"
  ];

  # Prompt-before-touching, for the home dirs outside a normal working tree.
  # Written by Claude Code itself when a directory-access prompt is answered
  # (hence the Read/Edit/Write triple per dir); pinned here so a fresh machine
  # inherits the same boundary instead of re-learning it one prompt at a time.
  # Ask rules still prompt under defaultMode bypassPermissions, and a PreToolUse
  # hook's "allow" does not override them (checked headless on 2.1.267,
  # 2026-09-14). So no home-wide catch-all lives here: Read/Edit/Write(~/.*) and
  # (~/*.*) also matched ~/.claude and shadowed every dotfile allow above, and
  # rule globs have no exception syntax. Credential dirs stay in claudeDenyRules.
  claudeAskRules = [
    "Read(~/Documents/**)"
    "Edit(~/Documents/**)"
    "Write(~/Documents/**)"
    "Read(~/Downloads/**)"
    "Edit(~/Downloads/**)"
    "Write(~/Downloads/**)"
    "Read(~/Movies/**)"
    "Edit(~/Movies/**)"
    "Write(~/Movies/**)"
    "Read(~/Music/**)"
    "Edit(~/Music/**)"
    "Write(~/Music/**)"
    "Read(~/Pictures/**)"
    "Edit(~/Pictures/**)"
    "Write(~/Pictures/**)"
    "Read(~/Public/**)"
    "Edit(~/Public/**)"
    "Write(~/Public/**)"
  ] ++ lib.optionals isDarwin [
    "Read(~/Applications/**)"
    "Edit(~/Applications/**)"
    "Write(~/Applications/**)"
  ];

  # The declaration below owns this exact object, including the plugin-skill
  # deny rules. Keeping one value avoids competing writers and rewrite loops.
  claudePermissions = {
    defaultMode = "bypassPermissions";
    allow = claudeAllowRules;
    deny = lib.unique (claudeDenyRules ++ deniedPluginSkills);
    ask = claudeAskRules;
  };

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
            && !(builtins.elem name excludedSkillIds)
          )
          entries);
    in
    lib.unique (lib.concatMap bucketSkillNames mattpocockBuckets);

  # Claude Code sees each of these ids TWICE: once from ~/.claude/skills (this
  # flake's bundle) and once from mattpocock-skills@claude-plugins-official.
  # The PLUGIN copy wins on the Claude surface — it tracks upstream faster than
  # the flake pin — so the bundle copy is switched off there with
  # `skillOverrides: "off"`, the one first-class per-skill listing lever Claude
  # Code has (it hides a skill from the model's catalog AND the `/` menu).
  #
  # Crucially that lever is a key in ~/.claude/settings.json, a file only Claude
  # Code reads. Codex, Droid, OpenCode, Crush and Pi have no plugin system, so
  # the de-duplication MUST NOT touch the bundle: they keep reading the full set
  # out of their own picker dirs. Nothing is deleted; nothing else loses a skill.
  #
  # Derived from enabledMattpocockSkills rather than restated, so a new upstream
  # bucket skill is auto-covered. The failure mode of deriving it is the flake
  # pin running AHEAD of the plugin — an id would then be hidden with no
  # replacement — which is why scripts/verify-agent-skills.sh asserts every
  # hidden id is actually declared by the enabled plugin.
  pluginProvidedSkillIds = enabledMattpocockSkills;
  # Non-mattpocock ids Claude Code already gets from the account/harness side.
  # `anthropic-skills:notebooklm` ships with the harness, has no local file and
  # cannot be removed, so the hand-installed ~/.claude/skills/notebooklm copy is
  # the one that yields. It stays on disk and stays visible to the other agents.
  harnessProvidedSkillIds = [ "notebooklm" ];
  claudeHiddenSkillIds = pluginProvidedSkillIds ++ harnessProvidedSkillIds;

  # Plugin skills with NO bundle counterpart that must not be reachable at all.
  # skillOverrides cannot touch these: Claude Code hard-codes its resolver to
  # return "on" for any skill whose `source` is "plugin" (the short-circuit
  # precedes both the qualified- and unqualified-name lookups, so no key
  # spelling reaches it), and no settings key filters which of an installed
  # plugin's skills load. Upstream documents this: "Plugin skills are not
  # affected by skillOverrides. Manage those through /plugin instead."
  #
  # So they get two independent levers — claudePrunePluginSkills drops them from
  # the cached plugin manifest (un-lists them outright), and a permissions.deny
  # rule refuses execution. The manifest prune is re-applied every switch
  # because a version bump writes a fresh cache dir; the deny rule is
  # version-independent and covers the window in between.
  deniedPluginSkills = map (id: "Skill(mattpocock-skills:${id})") disabledMattpocockSkills;

  # Effect-TS/skills. Upstream publishes flat under `skills/<name>/SKILL.md`
  # (currently just `effect-ts`). This source stays DEFINED but is no longer
  # globally enabled (see `enableAll = [ ]` below) — effect-ts is dependency-
  # conditional, so it is per-project devShell-scoped via
  # templates/effect-skills/devshell.flake.nix instead of fanned into every
  # repo's picker dirs. Keeping the source here documents the pin and makes a
  # global re-enable a one-line change.
  effectSources = { effect-ts = mkSource "effect-ts-skills" "skills" null; };

  # pstack: see modules/home/claude/pstack.nix (shared with its hygiene test).
  pstack = import ./claude/pstack.nix { inherit lib pkgs inputs mkSource mkSkill; };
  inherit (pstack) pstackSources pstackExplicit pstackAgentFile pstackModelsSheet pstackDrvs;

  # There is deliberately no `in-progress/` source any more. It existed to pull
  # `teach` out of that bucket; upstream has since promoted `teach` into
  # `productivity/`, so the old `^teach$` regex matched nothing and `teach` now
  # arrives through plain bucket auto-discovery from the same store root.
  # Re-adding an in-progress source is a duplicate-id hazard — any id upstream
  # later promotes would then be discovered twice, making discoverCatalog
  # throw — so unit-skill-hygiene asserts it stays gone. (The bucket's own
  # `review` no longer collides with anything: the dotfiles-pi `review` was
  # retired for the code-review host, ADR-0015.)

  # Settings env is seeded on a fresh machine and defaulted into the live
  # settings.json at every switch; existing values win.
  claudeSeedEnv = {
    API_TIMEOUT_MS = "3000000";
    ENABLE_LSP_TOOL = "1";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    CLAUDE_CODE_NEW_INIT = "1";
    CLAUDE_CODE_NO_FLICKER = "1";
    CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT = "1";
    CLAUDE_CODE_FORK_SUBAGENT = "1";
    CLAUDE_AUTO_BACKGROUND_TASKS = "1";
    CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING = "1";
    ENABLE_PROMPT_CACHING_1H = "1";
    CLAUDE_CODE_MAX_OUTPUT_TOKENS = "64000";
    # Default model for subagents that don't set their own `model:`
    # frontmatter (Task-spawned agents). The main session model above stays
    # opus/fable; most subagents don't need that reasoning tier.
    CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
    # Code search routing: rg defaults for agent shells only (6 threads,
    # 240-column cap, node_modules excluded) and the read-guard threshold.
    # A 200-line file costs about what one denied round trip costs, so the
    # guard only pays for itself above ~300 lines.
    RIPGREP_CONFIG_PATH = "${homeDir}/.config/ripgrep/agent-config";
    READ_GUARD_MAX_LINES = "300";
    # Bash tool: 10 s default before a command is backgrounded (lookups answer
    # in under a second); the tiers above it are in CLAUDE.md, up to the ceiling.
    BASH_DEFAULT_TIMEOUT_MS = "10000";
    BASH_MAX_TIMEOUT_MS = "600000";
  };

  # Tool guards: seeded on a fresh machine and re-asserted into the live
  # settings.json every switch (`claudeSettingsOwnership`), so a guard added
  # here is live after the next switch without a hand edit.
  claudeGuardHooks = [
    { event = "PreToolUse"; matcher = "Bash"; command = "$HOME/.claude/hooks/search-guard.sh"; }
    { event = "PreToolUse"; matcher = "Bash"; command = "$HOME/.claude/hooks/shell-guard.sh"; }
    { event = "PostToolUse"; matcher = "Edit"; command = "$HOME/.claude/hooks/edit-batch-nudge.sh"; }
  ] ++ lib.optionals config.programs.worktrunk.enable worktrunkMarkerHooks;

  # Worktrunk activity markers, shown per branch in `wt list`: 🤖 while Claude
  # works, 💬 while it waits, cleared at session end. Same events as upstream's
  # plugin (worktrunk.dev/claude-code/#activity-tracking). The hook path is
  # stable so a wt bump never strands a store path in the additive hook policy.
  # Claude's own worktree creation stays native on purpose: a WorktreeCreate
  # hook would drop symlinkDirectories, .worktreeinclude, and the stale sweep.
  worktrunkMarker = pkgs.writeShellApplication {
    name = "worktrunk-marker";
    runtimeInputs = [ config.programs.worktrunk.package ];
    # UserPromptSubmit feeds plain stdout into Claude's context, so all output
    # is dropped. Outside a git branch wt fails, and the marker is skipped.
    text = ''
      case "''${1:-}" in
        working) args=(set 🤖) ;;
        waiting) args=(set 💬) ;;
        clear) args=(clear) ;;
        *) exit 0 ;;
      esac
      wt config state marker "''${args[@]}" </dev/null >/dev/null 2>&1 || true
    '';
  };
  worktrunkMarkerHooks =
    let
      marker = state: "$HOME/.claude/hooks/worktrunk-marker.sh ${state}";
    in
    [
      { event = "UserPromptSubmit"; matcher = ""; command = marker "working"; }
      { event = "Notification"; matcher = ""; command = marker "waiting"; }
      { event = "PreToolUse"; matcher = "AskUserQuestion"; command = marker "waiting"; }
      { event = "PermissionRequest"; matcher = ""; command = marker "waiting"; }
      { event = "Stop"; matcher = ""; command = marker "waiting"; }
      { event = "SessionEnd"; matcher = ""; command = marker "clear"; }
    ];
  guardEntries = event:
    map (g: { inherit (g) matcher; hooks = [{ type = "command"; inherit (g) command; }]; })
      (builtins.filter (g: g.event == event) claudeGuardHooks);

  claudeSettingsSeed = pkgs.writeText "claude-settings-seed.json" (builtins.toJSON {
    env = claudeSeedEnv;
    # Seed-only wiring for the read guard and the rest (home.file above ships
    # the scripts). The live settings.json already carries these; a fresh
    # machine gets them from here.
    hooks = {
      PreToolUse = [
        { matcher = "Read"; hooks = [{ type = "command"; command = "$HOME/.claude/hooks/read-guard.sh"; }]; }
      ] ++ guardEntries "PreToolUse";
      PostToolUse = [
        { matcher = "Bash"; hooks = [{ type = "command"; command = "$HOME/.claude/hooks/auto-verify-edit.sh"; }]; }
      ] ++ guardEntries "PostToolUse";
      PostToolUseFailure = [
        { matcher = "Bash"; hooks = [{ type = "command"; command = "$HOME/.claude/hooks/auto-log-error.sh"; }]; }
      ];
      PreCompact = [
        { matcher = ""; hooks = [{ type = "command"; command = "$HOME/.claude/hooks/pre-compact-save.sh"; }]; }
      ];
      SessionStart = [
        { matcher = ""; hooks = [{ type = "command"; command = "$HOME/.claude/hooks/search-warmup.sh"; }]; }
        { matcher = ""; hooks = [{ type = "command"; command = "$HOME/.claude/hooks/codedb-warmup.sh"; }]; }
        { matcher = "compact"; hooks = [{ type = "command"; command = "$HOME/.claude/hooks/post-compact-reload.sh"; }]; }
      ];
    };
    permissions = claudePermissions;
    model = "opus";
    enabledMcpjsonServers = [ "qmd" ];
    statusLine = {
      type = "command";
      command = "bash ${homeDir}/.claude/statusline-command.sh";
    };
    enabledPlugins = {
      "swift-lsp@claude-plugins-official" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "gopls-lsp@claude-plugins-official" = true;
      "code-simplifier@claude-plugins-official" = true;
      "code-review@claude-plugins-official" = true;
      "expert-lsp@elixir-expert" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "context7@claude-plugins-official" = true;
      "skill-creator@claude-plugins-official" = true;
      "claude-md-management@claude-plugins-official" = true;
    };
    extraKnownMarketplaces = {
      "frad-dotclaude" = {
        source = {
          source = "github";
          repo = "FradSer/dotclaude";
        };
        autoUpdate = true;
      };
    };
    autoMemoryEnabled = false;
    autoDreamEnabled = false;
    worktree = claudeWorktreeSettings;
    skipDangerousModePermissionPrompt = true;
    effortLevel = "xhigh";
    inputNeededNotifEnabled = true;
    agentPushNotifEnabled = true;
  });
  claudeOwnedSettings = {
    own = [
      { path = [ "permissions" "allow" ]; value = claudePermissions.allow; }
      { path = [ "permissions" "deny" ]; value = claudePermissions.deny; }
      { path = [ "permissions" "ask" ]; value = claudePermissions.ask; }
      { path = [ "permissions" "defaultMode" ]; value = claudePermissions.defaultMode; }
    ]
    ++ map (id: { path = [ "skillOverrides" id ]; value = "off"; }) claudeHiddenSkillIds
    ++ map (id: { path = [ "enabledPlugins" id ]; value = false; }) disabledClaudePlugins
    ++ lib.mapAttrsToList (key: value: { path = [ key ]; inherit value; }) claudeMemorySettings
    ++ lib.mapAttrsToList (key: value: { path = [ "worktree" key ]; inherit value; }) claudeWorktreeSettings;
    default = lib.mapAttrsToList (key: value: { path = [ "env" key ]; inherit value; }) claudeSeedEnv;
    add = claudeGuardHooks;
  };
  claudeSettingsOwnership = import ./claude/settings-ownership.nix {
    inherit pkgs;
    policy = claudeOwnedSettings;
    seed = claudeSettingsSeed;
  };
in
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  # === Reproducible files (read-only, dotfiles-sourced) ===
  # `.local/bin/claude` is a stable user-PATH binary that survives store-path
  # churn so macOS TCC and editor integrations don't re-prompt every switch.
  home.file =
    let
      # Local skills (no dotfiles upstream). Installed via plain home.file
      # symlinks rather than a programs.agent-skills `path` source: the
      # module CAN source local paths, but it wraps a `path` source in a
      # platform-stamped copy derivation and reads it back (IFD), which makes
      # `nix flake check` fail to evaluate the x86_64-linux hosts from darwin
      # ("platform mismatch"). A plain path symlink is platform-agnostic. The same
      # store dir is linked into every picker target; Pi's realpath de-dup
      # collapses them, exactly like agent-skills' `link` targets.
      #   - jj — locally authored.
      #   - setup-ts-deep-modules — vendored fork of the mattpocock-skills
      #     in-progress skill, carrying the tsPreCompilationDeps fix its
      #     dependency-cruiser.config.cjs template lacks. Upstream never
      #     promoted it out of `in-progress/`, so unlike every other
      #     mattpocock id it has no plugin copy to defer to — it is the one
      #     skill here that is genuinely ours.
      #
      # Read from disk rather than a literal list so a new
      # modules/home/skills/<id> dir cannot be silently left uninstalled;
      # unit-skill-hygiene pins the resulting set.
      localSkillIds = builtins.attrNames (lib.filterAttrs
        (name: type:
          type == "directory" && builtins.pathExists (./skills + "/${name}/SKILL.md"))
        (builtins.readDir ./skills));
      localSkillFiles = listToAttrs (lib.concatMap
        (dir: map
          (skill: { name = "${dir}/${skill}"; value = { source = ./skills + "/${skill}"; }; })
          localSkillIds)
        (lib.attrValues skillLinkDirs));
      pstackSkillFiles = listToAttrs (lib.concatMap
        (dir: lib.mapAttrsToList
          (skill: drv: { name = "${dir}/${skill}"; value = { source = drv; }; })
          pstackDrvs)
        (lib.attrValues skillLinkDirs));
    in
    {
      # Contract between this module and scripts/verify-agent-skills.sh (Tier 2),
      # so that script never restates the curation lists and can never drift
      # from them. Agent-neutral location: it describes all nine picker dirs,
      # not just Claude's. Regenerated every switch; never hand-edited.
      ".config/agent-skills/manifest.json".source =
        pkgs.writeText "agent-skills-manifest.json" (builtins.toJSON {
          targetDirs = lib.attrValues skillTargetDirs;
          bundled = enabledMattpocockSkills;
          localSkills = localSkillIds;
          claudeHidden = claudeHiddenSkillIds;
          pluginProvided = pluginProvidedSkillIds;
          excluded = lib.unique (excludedSkillIds ++ removedSkillIds);
          deniedPluginSkills = disabledMattpocockSkills;
          pluginId = "mattpocock-skills@claude-plugins-official";
        });

      ".local/bin/claude".source = pkgs.claude-code + "/bin/claude";
      "${guideCatalog.hosts.claude.startup.target}".source =
        guideCatalog.hosts.claude.startup.source;
      "${guideCatalog.hosts.claude.development.target}".source =
        guideCatalog.hosts.claude.development.source;
      "${guideCatalog.hosts.claude.humanDocuments.target}".source =
        guideCatalog.hosts.claude.humanDocuments.source;
      ".claude/statusline-command.sh" = {
        source = ./claude/statusline-command.sh;
        executable = true;
      };

      # Code search routing (routes in guidance/development.md). The
      # three hooks are wired in settings.json (seed below; live file is
      # mutable). Evidence file is what the routes cite.
      ".claude/search-eval.md".source = ./claude/search-eval.md;
      ".claude/search-routing.md".source = ./claude/search-routing.md;
      ".claude/references/search-routing-examples.md".source = ./claude/references/search-routing-examples.md;

      # pstack subagent (see pstackSkills). A skills tree carries no agents;
      # Claude Code reads user agents from ~/.claude/agents by bare name.
      ".claude/agents/poteto-agent.md".source = pstackAgentFile "poteto-agent.md";
      ".claude/pstack-models.md".source = pstackModelsSheet;
      ".claude/hooks/search-guard.sh" = { source = ./claude/hooks/search-guard.sh; executable = true; };
      ".claude/hooks/read-guard.sh" = { source = ./claude/hooks/read-guard.sh; executable = true; };
      ".claude/hooks/shell-guard.sh" = { source = ./claude/hooks/shell-guard.sh; executable = true; };
      ".claude/hooks/edit-batch-nudge.sh" = { source = ./claude/hooks/edit-batch-nudge.sh; executable = true; };
      ".claude/hooks/search-warmup.sh" = { source = ./claude/hooks/search-warmup.sh; executable = true; };
      # Personal hooks, vendored 2026-09-09 (they were plain files only the live
      # settings knew about): zigmemo/zigdiff helpers and the codedb warm-up.
      ".claude/hooks/auto-verify-edit.sh" = { source = ./claude/hooks/auto-verify-edit.sh; executable = true; };
      ".claude/hooks/auto-log-error.sh" = { source = ./claude/hooks/auto-log-error.sh; executable = true; };
      ".claude/hooks/pre-compact-save.sh" = { source = ./claude/hooks/pre-compact-save.sh; executable = true; };
      ".claude/hooks/post-compact-reload.sh" = { source = ./claude/hooks/post-compact-reload.sh; executable = true; };
      ".claude/hooks/codedb-warmup.sh" = { source = ./claude/hooks/codedb-warmup.sh; executable = true; };
      ".local/bin/rw" = { source = ./claude/bin/rw; executable = true; };
      ".config/ripgrep/agent-config".source = ./claude/ripgrep/agent-config;
    } // localSkillFiles // pstackSkillFiles
    // lib.optionalAttrs config.programs.worktrunk.enable {
      ".claude/hooks/worktrunk-marker.sh".source = lib.getExe worktrunkMarker;
    };

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

  # Surge now shares the pinned personal skill source in agent-instructions.nix.
  # Restaging the app bundle here would replace its Home Manager symlinks.

  # Claude can cache Anthropic-provided skills outside the Nix-managed skill
  # targets, and the external `skills` CLI (~/.agents/.skill-lock.json) writes
  # real dirs into ~/.agents/skills. Keep every excluded id — disabled AND
  # lean-excluded, since both lists mean "we refuse to carry this" — out of all
  # nine picker dirs, and park the genuinely-disabled ones out of active Claude
  # Desktop sessions and the skills-plugin cache. (Name kept for continuity with
  # docs/adr/0009; the sweep covers the whole excluded set, not just grill-me.)
  #
  # Anchored on linkGeneration, not writeBoundary: home-manager links the bundle
  # in linkGeneration, so a sweep ordered only after writeBoundary can race and
  # delete before the link that re-creates the id.
  home.activation.claudeDisableGrillSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -n "''${DRY_RUN:-}" ]; then
      echo "claude-disable-skills: would remove ${lib.escapeShellArgs excludedSkillIds} from every picker dir" >&2
    else
      ${mkSkillTargetRm excludedSkillIds}
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
    fi
  '';

  # === Plugin-manifest prune (the only way to UN-LIST a plugin's skill) ===
  # Claude Code has no setting that filters which of an installed plugin's
  # skills load: `pluginConfigs` carries only MCP/userConfig, and the manifest's
  # own `skills` array is an author-side path allowlist resolved at LOAD time.
  # That last fact is the lever — prune the id out of the cached manifest and
  # the skill is never registered, so it leaves the `/` menu and the model's
  # catalog entirely. Pruning the manifest rather than deleting the skill dir
  # avoids a "declared in manifest but not found" warning at load.
  #
  # The plugin cache is VERSION-KEYED (<marketplace>/<plugin>/<version>/) and
  # `claude plugin update` rm -rf's the version dir and re-materialises it, so
  # this prune does NOT survive a plugin update on its own. It is re-applied on
  # every switch, and deniedPluginSkills covers the window in between by
  # refusing execution. The glob covers every cached version, so an
  # already-downloaded new version is pruned too.
  home.activation.claudePrunePluginSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cache="${homeDir}/.claude/plugins/cache/claude-plugins-official/mattpocock-skills"
    for manifest in "$cache"/*/.claude-plugin/plugin.json; do
      [ -f "$manifest" ] || continue
      tmp=$(mktemp)
      if ${pkgs.jq}/bin/jq \
          --argjson ids ${lib.escapeShellArg (builtins.toJSON disabledMattpocockSkills)} '
            .skills = ((.skills // [])
              | map(select((split("/") | last) as $id | ($ids | index($id)) == null)))
          ' "$manifest" > "$tmp" && ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$manifest"; then
        if [ -n "''${DRY_RUN:-}" ]; then
          echo "claude-prune-plugin-skills: would drop ${lib.escapeShellArgs disabledMattpocockSkills} from $manifest" >&2
          rm -f -- "$tmp"
        else
          mv -- "$tmp" "$manifest"
          echo "claude-prune-plugin-skills: dropped ${lib.escapeShellArgs disabledMattpocockSkills} from $manifest" >&2
        fi
      else
        rm -f -- "$tmp"
      fi
    done
  '';

  # One reconciler seeds missing files, applies the declared key policies in a
  # single jq pass, reports dry-run changes, and records owned values for safe
  # cleanup when a key leaves the Nix policy.
  home.activation.claudeSettingsOwnership =
    assert lib.elem "Read(~/.ssh/**)" claudePermissions.deny;
    assert claudePermissions.defaultMode == "bypassPermissions";
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${claudeSettingsOwnership.command}/bin/claude-settings-ownership ${lib.escapeShellArg homeDir}
    '';

  # === MCP: register fff and codedb with alwaysLoad ===
  # `claude mcp add-json -s user` is the only supported way to write
  # ~/.claude.json's mcpServers — that file carries other CLI-managed state
  # (auth, project registry) we don't want to hand-roll with jq the way
  # claudeDesktopMcpScaffold does for claude_desktop_config.json in
  # lsp.nix (that file's shape is simple enough to own; this one isn't).
  #
  # alwaysLoad exempts a server from tool-search deferral. A deferred server
  # shows the model tool names only, so Claude reached for Bash ls/rg rather
  # than pay a ToolSearch round trip; Codex loads MCP schemas eagerly and
  # never had the gap. Checked on 2.1.267 (2026-09-14): fff with alwaysLoad
  # arrived with full schemas, codedb without it stayed deferred.
  #
  # Idempotency compares command, args, and alwaysLoad with the wanted spec.
  # fff's command is a store path, so every fff-mcp bump re-registers and the
  # entry never points at a path `nix-collect-garbage` has reaped.
  home.activation.claudeMcpAlwaysLoaded = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeBin="${pkgs.claude-code}/bin/claude"
    jqBin="${pkgs.jq}/bin/jq"
    target="${homeDir}/.claude.json"

    registerAlwaysLoaded() {
      name="$1"
      spec="$2"
      current=""
      if [ -f "$target" ]; then
        current=$("$jqBin" -c --arg n "$name" '.mcpServers[$n] // {} | {command, args, alwaysLoad}' "$target" 2>/dev/null || true)
      fi
      wanted=$(printf '%s' "$spec" | "$jqBin" -c '{command, args, alwaysLoad}')

      if [ "$current" = "$wanted" ]; then
        :
      elif [ -n "''${DRY_RUN:-}" ]; then
        echo "claude-mcp: would (re)register $name -> $wanted (was: ''${current:-none})" >&2
      else
        "$claudeBin" mcp remove -s user "$name" >/dev/null 2>&1 || true
        if "$claudeBin" mcp add-json -s user "$name" "$spec" >&2; then
          echo "claude-mcp: registered $name with alwaysLoad" >&2
        else
          echo "claude-mcp: failed to register $name (see above)" >&2
        fi
      fi
    }

    if [ ! -x "$claudeBin" ]; then
      echo "claude-mcp: claude CLI not found, skipping" >&2
    else
      registerAlwaysLoaded fff '{"type":"stdio","command":"${pkgs.martin.fff-mcp}/bin/fff-mcp","args":[],"alwaysLoad":true}'
      # codedb is a hand-installed binary outside Nix; register it only when present.
      if [ -x "${homeDir}/bin/codedb" ]; then
        registerAlwaysLoaded codedb '{"type":"stdio","command":"${homeDir}/bin/codedb","args":["mcp"],"alwaysLoad":true}'
      fi
    fi
  '';

  # === MCP: register drafts (Drafts.app AppleScript bridge) ===
  # Same mechanism and same store-path idempotency reasoning as
  # claudeMcpAlwaysLoaded above. The patched defaults (bulk tools gated behind
  # DRAFTS_MCP_ALLOW_BULK=1, 20s osascript watchdog, 200-result cap) are
  # baked into pkgs/drafts-mcp-server.nix, so no env is passed here.
  home.activation.claudeMcpDrafts = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeBin="${pkgs.claude-code}/bin/claude"
    draftsBin="${pkgs.martin.drafts-mcp-server}/bin/drafts-mcp-server"
    target="${homeDir}/.claude.json"

    currentCmd=""
    if [ -f "$target" ]; then
      currentCmd=$(${pkgs.jq}/bin/jq -r '.mcpServers.drafts.command // empty' "$target" 2>/dev/null || true)
    fi

    if [ ! -x "$claudeBin" ]; then
      echo "claude-mcp-drafts: claude CLI not found, skipping" >&2
    elif [ "$currentCmd" = "$draftsBin" ]; then
      :
    elif [ -n "''${DRY_RUN:-}" ]; then
      echo "claude-mcp-drafts: would (re)register drafts -> $draftsBin (was: ''${currentCmd:-none})" >&2
    else
      "$claudeBin" mcp remove -s user drafts >/dev/null 2>&1 || true
      if "$claudeBin" mcp add -s user drafts -- "$draftsBin" >&2; then
        echo "claude-mcp-drafts: registered drafts -> $draftsBin" >&2
      else
        echo "claude-mcp-drafts: failed to register drafts (see above)" >&2
      fi
    fi
  '');

  # === Skills (was modules/home/skills.nix) ===
  programs.agent-skills = {
    enable = true;

    sources = {
      dotfiles-pi = mkSource "dotfiles" "dot_pi/agent/skills"
        "^web-browser$";
      archify = mkSource "archify" "." null;
      better-github-skill = mkSource "better-github-skill" "." null;
    } // mpSources // effectSources;

    skills = {
      enable = enabledMattpocockSkills ++ [ "archify" "better-github-skill" ];
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
        # Skills wired one by one; the list is CLI deps symlinked into the
        # bundle dir (none now: the dotfiles-pi `review` that carried git/gh/jq
        # was retired for the code-review host, ADR-0015). mattpocock skills
        # inherit from user PATH (git/gh/jq/bun globally).
        web-browser = mkSkill "dotfiles-pi" "web-browser" [ ];
      };
    };

    targets = lib.mapAttrs (_: linkTarget) skillLinkDirs;

    # Module default (`[ "/.system" ]`); an empty list would let a future
    # `structure = "symlink-tree"` target rsync --delete over Codex's own
    # `.system` dir. Every target is `link` today, so this is a latent guard.
    excludePatterns = [ "/.system" ];
  };
}
