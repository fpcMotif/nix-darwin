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
  leanExcludedMattpocockSkills = [
    "git-guardrails-claude-code" # one-time git-hook setup, not a recurring workflow
    "migrate-to-shoehorn" # @total-typescript/shoehorn-specific test migration
    "scaffold-exercises" # course / exercise authoring
    "setup-pre-commit" # Husky / lint-staged JS setup, one-off
  ];
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
  # claudeDisableGlobalMcpPlugins below. claude.ai connectors are
  # account-side and unaffected. Currently empty — every plugin previously
  # listed here has since been uninstalled outright instead of parked; add an
  # id back to park (disable-but-keep-installed) rather than uninstall it.
  disabledClaudePlugins = [ ];

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
  # claudePermissionsAssert below now re-writes these four keys on every switch,
  # so they survive a `/permissions` edit, a UI toggle, or a wiped settings.json.
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
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    "Bash(darwin-rebuild:*)"
  ] ++ [
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
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    "Bash(xcrun:*)"
  ] ++ [
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
    "Read(~/Library/Application Support/Claude/config.json)"
    "Read(~/Library/**)"
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
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    "Read(~/Library/Keychains/**)"
    "Edit(~/Library/**)"
    "Write(~/Library/**)"
  ];

  # Prompt-before-touching, for the home dirs outside a normal working tree.
  # Written by Claude Code itself when a directory-access prompt is answered
  # (hence the Read/Edit/Write triple per dir); pinned here so a fresh machine
  # inherits the same boundary instead of re-learning it one prompt at a time.
  # Note these mostly go quiet under defaultMode bypassPermissions, which skips
  # prompts — they are the fallback for any session started in another mode.
  claudeAskRules = lib.optionals pkgs.stdenv.isDarwin [
    "Read(~/Applications/**)"
    "Edit(~/Applications/**)"
    "Write(~/Applications/**)"
  ] ++ [
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
    "Read(~/.*)"
    "Edit(~/.*)"
    "Write(~/.*)"
    "Read(~/*.*)"
    "Edit(~/*.*)"
    "Write(~/*.*)"
  ];

  # The exact object merged over `.permissions` each switch. deny appends
  # deniedPluginSkills rather than restating it, so this block and
  # claudeSkillSurfaceDedup can never disagree about grill-me and fight each
  # other into a rewrite-every-switch loop.
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

  # There is deliberately no `in-progress/` source any more. It existed to pull
  # `teach` out of that bucket; upstream has since promoted `teach` into
  # `productivity/`, so the old `^teach$` regex matched nothing and `teach` now
  # arrives through plain bucket auto-discovery from the same store root.
  # Re-adding an in-progress source is a duplicate-id hazard — the bucket also
  # ships a `review` that collides with the dotfiles-pi `review` below, and any
  # id upstream later promotes would then be discovered twice, making
  # discoverCatalog throw — so unit-skill-hygiene asserts it stays gone.
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
      ".claude/CLAUDE.md".source = renderChezmoi (dotClaude + "/claude.md.tmpl");
      ".claude/statusline-command.sh" = {
        source = dotClaude + "/executable_statusline-command.sh";
        executable = true;
      };
    } // localSkillFiles;

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
  # Anchored on linkGeneration: "agent-skills" names an activation node that
  # only exists when some target uses `structure = "symlink-tree"`. Every target
  # here is `link`, so that node is never created and hm's topoSort silently
  # drops the edge, leaving this block unordered against the linking it depends on.
  home.activation.surgeAgentSkillSymlinks = lib.mkIf pkgs.stdenv.isDarwin (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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

  # === Claude-only skill de-duplication ===
  # Same shape and same reasoning as claudeDisableGlobalMcpPlugins below:
  # settings.json is seed-once-then-mutable, but these two keys are exactly the
  # kind of "reproducible off switch" that must survive a UI toggle or a plugin
  # refresh, so they are re-asserted every switch. Idempotent (only rewrites
  # when a value actually changes) and runs after the seed so the file exists.
  #
  #   skillOverrides   — "off" hides a FILESYSTEM skill from both the model's
  #                      catalog and the `/` menu. Keyed by the skill's
  #                      frontmatter `name` (== the directory name for every id
  #                      here). Claude Code ignores it for plugin skills by
  #                      design, which is precisely why it de-duplicates here
  #                      instead of hiding both copies.
  #   permissions.deny — the only version-independent lever that reaches a
  #                      plugin's own skill. It blocks EXECUTION, not listing.
  #
  # Scope note: ~/.claude/settings.json is user-scope, and Claude Code's
  # precedence is user < project < local < flag < policy, so a project-level
  # `"on"` would win. Nothing in this repo sets one; verify-agent-skills.sh
  # reports it if one appears.
  # Ordered after claudePermissionsAssert, not just the seed: that block owns
  # `permissions.deny` outright, so this one must run on the already-asserted
  # list. Its deny half is a no-op in steady state (claudePermissions folds
  # deniedPluginSkills in) and survives only as the guard for the window where
  # a hand-edit strips the Skill rule mid-cycle.
  home.activation.claudeSkillSurfaceDedup = lib.hm.dag.entryAfter [ "claudePermissionsAssert" ] ''
    target="${homeDir}/.claude/settings.json"
    if [ ! -f "$target" ]; then
      echo "claude-skill-dedup: missing $target, skipping" >&2
    elif [ -n "''${DRY_RUN:-}" ]; then
      echo "claude-skill-dedup: would hide ${toString (builtins.length claudeHiddenSkillIds)} duplicate skills and deny ${lib.concatStringsSep ", " deniedPluginSkills}" >&2
    else
      tmp=$(mktemp)
      if ${pkgs.jq}/bin/jq \
          --argjson hidden ${lib.escapeShellArg (builtins.toJSON claudeHiddenSkillIds)} \
          --argjson denied ${lib.escapeShellArg (builtins.toJSON deniedPluginSkills)} '
            .skillOverrides = ((.skillOverrides // {})
              + ($hidden | map({ key: ., value: "off" }) | from_entries))
            | .permissions = (.permissions // {})
            | .permissions.deny = ((.permissions.deny // [])
              + ($denied - (.permissions.deny // [])))
          ' "$target" > "$tmp" && ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$target"; then
        mv -- "$tmp" "$target"
        echo "claude-skill-dedup: hid ${toString (builtins.length claudeHiddenSkillIds)} duplicate skills in $target" >&2
      else
        rm -f -- "$tmp"
      fi
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

  # === permissions: re-asserted every switch ===
  # Same seed-once-then-own-a-few-keys shape as claudeSkillSurfaceDedup and
  # claudeDisableGlobalMcpPlugins, but AUTHORITATIVE rather than additive: the
  # four keys in claudePermissions are set to the nix value, so a rule added by
  # hand or by a `/permissions` click is reverted on the next switch. That is
  # deliberate — an additive merge lets the live file accumulate rules nix can
  # never reproduce, which is exactly the drift this block exists to end.
  #
  # `.permissions + $perms` rather than `.permissions = $perms`: it overwrites
  # only the four keys we declare and preserves any sibling key Claude Code
  # adds later (additionalDirectories, disableBypassPermissionsMode, …) instead
  # of silently deleting it.
  home.activation.claudePermissionsAssert = lib.hm.dag.entryAfter [ "claudeSettingsSeed" ] ''
    target="${homeDir}/.claude/settings.json"
    if [ ! -f "$target" ]; then
      echo "claude-permissions: missing $target, skipping" >&2
    elif [ -n "''${DRY_RUN:-}" ]; then
      echo "claude-permissions: would assert ${toString (builtins.length claudePermissions.allow)} allow / ${toString (builtins.length claudePermissions.deny)} deny / ${toString (builtins.length claudePermissions.ask)} ask rules, defaultMode ${claudePermissions.defaultMode}" >&2
    else
      tmp=$(mktemp)
      if ${pkgs.jq}/bin/jq \
          --argjson perms ${lib.escapeShellArg (builtins.toJSON claudePermissions)} \
          '.permissions = ((.permissions // {}) + $perms)' \
          "$target" > "$tmp" && ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$target"; then
        mv -- "$tmp" "$target"
        echo "claude-permissions: re-asserted permissions in $target" >&2
      else
        rm -f -- "$tmp"
      fi
    fi
  '';

  # === Reproducible global-plugin-disable lever ===
  # settings.json is otherwise seed-once-then-mutable (above), but
  # enabledPlugins is exactly the kind of "reproducible disable" lever the
  # grill-me block already uses: flip any id listed in disabledClaudePlugins
  # off on every rebuild so a UI re-enable or a plugin-cache refresh can't
  # quietly bring a parked plugin's MCP server back globally. Idempotent
  # (only rewrites when a flag actually changes) and runs after the seed so
  # the file exists. claude.ai connectors are account-side and untouched.
  # See docs/adr/0003-scope-code-context-mcp-per-project.md for the
  # plugin-scoping precedent this lever was built for.
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

  # === MCP: register drafts (Drafts.app AppleScript bridge) ===
  # Same mechanism and same store-path idempotency reasoning as
  # claudeMcpFff above. The patched defaults (bulk tools gated behind
  # DRAFTS_MCP_ALLOW_BULK=1, 20s osascript watchdog, 200-result cap) are
  # baked into pkgs/drafts-mcp-server.nix, so no env is passed here.
  home.activation.claudeMcpDrafts = lib.mkIf pkgs.stdenv.isDarwin (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
        "^(review|web-browser)$";
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
        # Skills that need CLI deps symlinked into the bundle dir.
        # mattpocock skills inherit from user PATH (git/gh/jq/bun globally).
        review = mkSkill "dotfiles-pi" "review" [ pkgs.git pkgs.gh pkgs.jq ];
        web-browser = mkSkill "dotfiles-pi" "web-browser" [ ];

        # `grill-with-docs` and `improve-codebase-architecture` used to live
        # here so a Nix `transform` could append a Karpathy-alignment footer to
        # each. Both forks are retired: the plugin now supplies both ids, and a
        # local fork would shadow the plugin copy and re-create the very
        # duplicate this module removes (the fork of
        # improve-codebase-architecture had also drifted onto a stale upstream
        # body). They are back on plain bucket auto-discovery, so every non-
        # Claude picker dir gets the untransformed upstream copy.
      };
    };

    targets = lib.mapAttrs (_: linkTarget) skillLinkDirs;

    # Module default (`[ "/.system" ]`); an empty list would let a future
    # `structure = "symlink-tree"` target rsync --delete over Codex's own
    # `.system` dir. Every target is `link` today, so this is a latent guard.
    excludePatterns = [ "/.system" ];
  };
}
