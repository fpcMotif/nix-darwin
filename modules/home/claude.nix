{ inputs, pkgs, lib, config, ... }:

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

  inherit (config.martin.agentSurface) guideCatalog skillTargetDirs claudeHooks;

  # `link` points every target at the same store SKILL.md files. Pi de-dupes
  # skills by realpath, so the shared store paths collapse across picker dirs.
  linkTarget = dest: { enable = true; inherit dest; structure = "link"; systems = [ ]; };
  # The same dirs as a quoted, absolute, space-separated shell list, for the
  # `for dir in …` loops in the activation sweeps below.
  skillTargetDirsSh = lib.concatMapStringsSep " " (d: ''"${homeDir}/${d}"'')
    (lib.attrValues skillTargetDirs);

  skillLinkDirs = config.martin.agentSurface.skillPlacement.pickerDirs;

  # An agent-skills `path` source uses IFD and breaks cross-platform
  # `nix flake check`, so local skills go through Skill placement instead.
  # Read from disk so no new skill dir is missed.
  localSkillIds = builtins.attrNames (lib.filterAttrs
    (name: type:
      type == "directory" && builtins.pathExists (./skills + "/${name}/SKILL.md"))
    (builtins.readDir ./skills));

  mkSkillTargetRm = ids: ''
    for dir in ${skillTargetDirsSh}; do
      for skill in ${lib.escapeShellArgs ids}; do
        rm -rf -- "$dir/$skill"
      done
    done
  '';

  # grep -lZ first: running jq+mv on every session file spawned O(sessions)
  # processes per switch. `cacheAction` sees `$skill` and `$dir`.
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

  inherit (import ./claude/skill-curation.nix)
    mattpocockBuckets disabledMattpocockSkills leanExcludedMattpocockSkills
    removedSkillIds harnessProvidedSkillIds interfacesSkillNames;
  excludedSkillIds = disabledMattpocockSkills ++ leanExcludedMattpocockSkills;
  # Park here (off but installed) to keep a plugin's cache and config.
  disabledClaudePlugins = [ "typescript-lsp@claude-plugins-official" ];
  # This module edits these plugins' caches, so it also owns their flag and
  # marketplace. Authors' marketplaces track upstream; claude-plugins-official
  # lags. Change one here, not via /plugin, or every skill lists twice.
  mattpocockPluginId = "mattpocock-skills@mattpocock";
  convexPluginId = "convex@convex";
  pstackPluginId = "pstack@cursor-plugins";
  claudeManagedPlugins = {
    ${mattpocockPluginId} = true;
    ${convexPluginId} = true;
    ${pstackPluginId} = true;
  };
  claudeManagedMarketplaces = {
    mattpocock = { source = { source = "github"; repo = "mattpocock/skills"; }; autoUpdate = true; };
    convex = { source = { source = "github"; repo = "get-convex/convex-backend-skill"; }; autoUpdate = true; };
    cursor-plugins = { source = { source = "github"; repo = "cursor/plugins"; }; autoUpdate = true; };
  };
  # ~/.claude/plugins/cache keys each install as <marketplace>/<plugin>/<version>.
  pluginCacheDir = id:
    let parts = lib.splitString "@" id;
    in "${lib.last parts}/${lib.head parts}";

  # Memory is hand-curated, so auto-memory and its background consolidation
  # are pinned off every switch. Existing memory dirs stay on disk, unread.
  claudeMemorySettings = {
    autoMemoryEnabled = false;
    autoDreamEnabled = false;
  };

  # `sparsePaths` is a per-repo monorepo setting, so it stays out of here.
  claudeWorktreeSettings = {
    symlinkDirectories = [ "node_modules" ".cache" ];
  };

  # === auto-compact windows ===
  # 400K caps the cost of late turns; Haiku stays within its cheaper 100K tier.
  # Leave CLAUDE_CODE_AUTO_COMPACT_WINDOW unset: it would override both.
  claudeAutoCompactSettings = [
    { path = [ "autoCompactWindow" ]; value = 400000; }
    { path = [ "modelSettings" "claude-haiku-5-5" "autoCompactWindow" ]; value = 100000; }
  ];

  # Owned in settings.json because it beats the /config value in ~/.claude.json.
  claudeWorkflowSettings = {
    workflowSizeGuideline = "medium";
  };

  # === permissions: nix-owned, authoritative ===
  # Rewritten every switch; a runtime-added rule not listed here is dropped.
  # Order is deny → ask → allow, first match wins, regardless of specificity.
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
    "Read(~/.agents/**)"
    "mcp__fff__find_files"
    "mcp__fff__grep"
    "mcp__fff__multi_grep"

    # Allowed by choice; a stricter config would deny these.
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
    "Edit(~/.zshenv)"
    "Edit(~/.zprofile)"
    "Edit(~/.bashrc)"
    "Edit(~/.bash_profile)"
    "Bash(zed:*)"
    "Bash(zed-nightly:*)"
    "Read(~/.config/zed/**)"
    "Edit(~/.config/zed/**)"
  ] ++ lib.optionals isDarwin [
    # macOS-only commands and home paths stay out of Linux settings and
    # activation scripts.
    "Bash(darwin-rebuild:*)"
    "Bash(xcrun:*)"
    "Read(~/Library/Application Support/Claude/config.json)"
    "Read(~/Library/**)"
  ];

  # Minimal by choice: only credential dirs are denied. Plugin-skill denies
  # come from deniedPluginSkills.
  claudeDenyRules = [
    "Read(~/.ssh/**)"
    "Read(~/.aws/**)"
    "Read(~/.gnupg/**)"
  ] ++ lib.optionals isDarwin [
    "Read(~/Library/Keychains/**)"
    "Edit(~/Library/**)"
  ];

  # Prompt before touching personal home dirs, even under bypassPermissions.
  # No home-wide catch-all: `~/.*` would also match ~/.claude and shadow every
  # dotfile allow, and rule globs have no exceptions.
  claudeAskRules = [
    "Read(~/Documents/**)"
    "Edit(~/Documents/**)"
    "Read(~/Downloads/**)"
    "Edit(~/Downloads/**)"
    "Read(~/Movies/**)"
    "Edit(~/Movies/**)"
    "Read(~/Music/**)"
    "Edit(~/Music/**)"
    "Read(~/Pictures/**)"
    "Edit(~/Pictures/**)"
    "Read(~/Public/**)"
    "Edit(~/Public/**)"
  ] ++ lib.optionals isDarwin [
    "Read(~/Applications/**)"
    "Edit(~/Applications/**)"
  ];

  # The declaration below owns this exact object, including the plugin-skill
  # deny rules. Keeping one value avoids competing writers and rewrite loops.
  claudePermissions = {
    defaultMode = "bypassPermissions";
    allow = claudeAllowRules;
    deny = lib.unique (claudeDenyRules ++ deniedPluginSkills ++ deniedPluginMcpServers);
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

  # Claude sees these ids in both the bundle and the mattpocock plugin. The
  # plugin copy wins, so skillOverrides hides the bundle copy in Claude only;
  # other agents keep the bundle. verify-agent-skills.sh checks the plugin has each.
  pluginProvidedSkillIds = enabledMattpocockSkills;
  pstackPluginSkillIds = builtins.attrNames pstackDrvs;
  claudeHiddenSkillIds = pluginProvidedSkillIds ++ pstackPluginSkillIds ++ harnessProvidedSkillIds ++ interfacesSkillNames;

  # Plugin skills to block outright. skillOverrides ignores plugin skills, so
  # claudePrunePluginSkills unlists them every switch and a deny rule refuses
  # them after a plugin update, before the next switch.
  idleClaudePluginSkills = {
    ${pluginCacheDir convexPluginId} = [
      "add"
      "agent"
      "billing"
      "convex-authz"
      "crons"
      "domains"
      "env"
      "improve-convex-plugin"
      "labs-quickstart"
      "migrate"
      "quickstart"
      "seed"
      "suggest"
      "test"
      "workflow"
    ];
    "claude-community/html-plan" = [ "html-plan" ];
  };
  deniedPluginSkills = map (id: "Skill(mattpocock-skills:${id})") disabledMattpocockSkills
    ++ lib.concatLists (lib.mapAttrsToList
    (dir: ids: map (id: "Skill(${baseNameOf dir}:${id})") ids)
    idleClaudePluginSkills);
  deniedPluginMcpServers = [ "mcp__plugin_marketing_figma" ];

  # Effect-TS skills: defined but not enabled globally. Effect repos get them
  # per project via templates/effect-skills/devshell.flake.nix.
  effectSources = { effect-ts = mkSource "effect-ts-skills" "skills" null; };

  pstack = import ./claude/pstack.nix {
    inherit lib pkgs inputs mkSource mkSkill;
    inherit (config.martin.development) docLock;
  };
  inherit (pstack) pstackSources pstackExplicit pstackModelsSheet pstackDrvs;

  # Defaults only: a value already in settings.json wins.
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
    CLAUDE_CODE_SUBAGENT_MODEL = "opus";
    # Below ~300 lines, a denied read costs more than reading the file.
    RIPGREP_CONFIG_PATH = "${homeDir}/.config/ripgrep/agent-config";
    READ_GUARD_MAX_LINES = "300";
    # Bash tool: 10 s default before a command is backgrounded (lookups answer
    # in under a second); the tiers above it are in CLAUDE.md, up to the ceiling.
    BASH_DEFAULT_TIMEOUT_MS = "10000";
    BASH_MAX_TIMEOUT_MS = "600000";
  };

  claudeGuardHooks = [
    { event = "PreToolUse"; matcher = "Bash"; command = "$HOME/.claude/hooks/search-guard.sh"; }
    { event = "PreToolUse"; matcher = "Bash"; command = "$HOME/.claude/hooks/shell-guard.sh"; }
  ] ++ claudeHooks.add;
  retiredClaudeHooks = [
    { event = "PostToolUse"; matcher = "Edit"; command = "$HOME/.claude/hooks/edit-batch-nudge.sh"; }
    { event = "PreToolUse"; matcher = "Read"; command = "$HOME/.claude/hooks/read-guard.sh"; }
    { event = "PreToolUse"; matcher = "Bash"; command = "$HOME/.claude/hooks/codedb-block-legacy.sh"; }
    { event = "PostToolUse"; matcher = "Bash"; command = "$HOME/.claude/hooks/auto-verify-edit.sh"; }
    { event = "PostToolUseFailure"; matcher = "Bash"; command = "$HOME/.claude/hooks/auto-log-error.sh"; }
    { event = "PreCompact"; matcher = ""; command = "$HOME/.claude/hooks/pre-compact-save.sh"; }
    { event = "SessionStart"; matcher = ""; command = "$HOME/.claude/hooks/search-warmup.sh"; }
    { event = "SessionStart"; matcher = ""; command = "$HOME/.claude/hooks/codedb-warmup.sh"; }
    { event = "SessionStart"; matcher = "compact"; command = "$HOME/.claude/hooks/post-compact-reload.sh"; }
  ];
  claudeSettingsSeed = pkgs.writeText "claude-settings-seed.json" (builtins.toJSON {
    env = claudeSeedEnv;
    permissions = claudePermissions;
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
      "typescript-lsp@claude-plugins-official" = false;
      "context7@claude-plugins-official" = true;
      "skill-creator@claude-plugins-official" = true;
      "claude-md-management@claude-plugins-official" = true;
      "interfaces@interfaces" = true;
    } // claudeManagedPlugins;
    extraKnownMarketplaces = {
      "frad-dotclaude" = {
        source = {
          source = "github";
          repo = "FradSer/dotclaude";
        };
        autoUpdate = true;
      };
      "interfaces" = {
        source = {
          source = "github";
          repo = "jakubkrehel/skills";
        };
        autoUpdate = true;
      };
    } // claudeManagedMarketplaces;
    autoMemoryEnabled = false;
    autoDreamEnabled = false;
    worktree = claudeWorktreeSettings;
    skipDangerousModePermissionPrompt = true;
    effortLevel = "medium";
    inputNeededNotifEnabled = true;
    agentPushNotifEnabled = true;
  });
  claudeOwnedSettings = {
    own = [
      { path = [ "permissions" "allow" ]; value = claudePermissions.allow; }
      { path = [ "permissions" "deny" ]; value = claudePermissions.deny; }
      { path = [ "permissions" "ask" ]; value = claudePermissions.ask; }
      { path = [ "permissions" "defaultMode" ]; value = claudePermissions.defaultMode; }
      { path = [ "effortLevel" ]; value = "medium"; }
      { path = [ "env" "CLAUDE_CODE_PLUGIN_DIRS" ]; value = "${homeDir}/.claude/mods/jev-traits"; }
    ]
    ++ map (id: { path = [ "skillOverrides" id ]; value = "off"; }) claudeHiddenSkillIds
    ++ map (id: { path = [ "enabledPlugins" id ]; value = false; }) disabledClaudePlugins
    ++ lib.mapAttrsToList (id: value: { path = [ "enabledPlugins" id ]; inherit value; }) claudeManagedPlugins
    ++ lib.mapAttrsToList (name: value: { path = [ "extraKnownMarketplaces" name ]; inherit value; }) claudeManagedMarketplaces
    ++ lib.mapAttrsToList (key: value: { path = [ key ]; inherit value; }) claudeMemorySettings
    ++ lib.mapAttrsToList (key: value: { path = [ key ]; inherit value; }) claudeWorkflowSettings
    ++ lib.mapAttrsToList (key: value: { path = [ "worktree" key ]; inherit value; }) claudeWorktreeSettings
    ++ claudeAutoCompactSettings;
    default = lib.mapAttrsToList (key: value: { path = [ "env" key ]; inherit value; }) claudeSeedEnv;
    add = claudeGuardHooks;
    remove = claudeHooks.remove ++ retiredClaudeHooks;
  };
  claudeSettingsOwnership = import ./claude/settings-ownership.nix {
    inherit pkgs;
    policy = claudeOwnedSettings;
    seed = claudeSettingsSeed;
  };
in
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  # `.local/bin/claude` is a stable user-PATH binary that survives store-path
  # churn so macOS TCC and editor integrations don't re-prompt every switch.
  martin.agentSurface.skills =
    lib.genAttrs localSkillIds (id: { source = ./skills + "/${id}"; audience = "pickers"; })
    // lib.mapAttrs (_: drv: { source = drv; audience = "pickers"; }) pstackDrvs;

  home.file =
    lib.mapAttrs (_: source: { inherit source; }) (guideCatalog.filesFor [ "claude" ]) //
    {
      # Curation lists for scripts/verify-agent-skills.sh, so it never restates
      # them. Covers every picker dir; regenerated every switch.
      ".config/agent-skills/manifest.json".source =
        pkgs.writeText "agent-skills-manifest.json" (builtins.toJSON {
          targetDirs = lib.attrValues skillTargetDirs;
          bundled = enabledMattpocockSkills;
          localSkills = localSkillIds;
          claudeHidden = claudeHiddenSkillIds;
          pluginProvided = pluginProvidedSkillIds;
          excluded = lib.unique (excludedSkillIds ++ removedSkillIds);
          deniedPluginSkills = disabledMattpocockSkills;
          pluginId = mattpocockPluginId;
        });

      ".local/bin/claude".source = pkgs.claude-code + "/bin/claude";
      ".claude/statusline-command.sh" = {
        source = ./claude/statusline-command.sh;
        executable = true;
      };

      ".claude/search-eval.md".source = ./claude/search-eval.md;
      ".claude/search-routing.md".source = ./claude/search-routing.md;
      ".claude/references/search-routing-examples.md".source = ./claude/references/search-routing-examples.md;

      ".claude/pstack-models.md".source = pstackModelsSheet;
      ".claude/hooks/search-guard.sh" = { source = ./claude/hooks/search-guard.sh; executable = true; };
      ".claude/hooks/shell-guard.sh" = { source = ./claude/hooks/shell-guard.sh; executable = true; };
      ".claude/mods/jev-traits".source = ./claude/mods/jev-traits;
      ".config/ripgrep/agent-config".source = ./claude/ripgrep/agent-config;
    };

  home.activation.claudePruneRemovedSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${DRY_RUN:-}" ]; then
      echo "claude-prune-removed-skills: would prune removed skills: ${lib.escapeShellArgs removedSkillIds}" >&2
    else
      ${mkSkillTargetRm removedSkillIds}
      ${mkSessionSweep { ids = removedSkillIds; cacheAction = ''rm -rf -- "$dir"''; }}
    fi
  '';

  # The external `skills` CLI reinstalls excluded ids as real dirs. After
  # linkGeneration, so no link re-creates them after the sweep.
  home.activation.claudePruneExcludedSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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

  # === Plugin-manifest prune: the only way to unlist a plugin skill ===
  # Dropping an id from the cached manifest's `skills` array stops it loading.
  # A plugin update rewrites the cache, so this reruns every switch.
  home.activation.claudePrunePluginSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cache="${homeDir}/.claude/plugins/cache/${pluginCacheDir mattpocockPluginId}"
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
    ${lib.concatStrings (lib.mapAttrsToList (dir: ids: ''
      for version in "${homeDir}/.claude/plugins/cache/${dir}"/*; do
        for id in ${lib.escapeShellArgs ids}; do
          src="$version/skills/$id"
          [ -f "$src/SKILL.md" ] || continue
          if [ -n "''${DRY_RUN:-}" ]; then
            echo "claude-prune-plugin-skills: would move $src to skills-disabled" >&2
          else
            mkdir -p "$version/skills-disabled"
            rm -rf -- "$version/skills-disabled/$id"
            mv -- "$src" "$version/skills-disabled/$id"
            echo "claude-prune-plugin-skills: moved $src to skills-disabled" >&2
          fi
        done
      done
    '') idleClaudePluginSkills)}
  '';

  home.activation.claudeSettingsOwnership =
    assert lib.elem "Read(~/.ssh/**)" claudePermissions.deny;
    assert claudePermissions.defaultMode == "bypassPermissions";
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${claudeSettingsOwnership.command}/bin/claude-settings-ownership ${lib.escapeShellArg homeDir}
    '';

  # alwaysLoad skips tool-search deferral, so Claude uses them over Bash rg.
  # Registered via `claude mcp` (~/.claude.json holds other CLI state).
  # No env here: the patched defaults live in pkgs/drafts-mcp-server.nix.
  home.activation.claudeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeBin="${pkgs.claude-code}/bin/claude"
    jqBin="${pkgs.jq}/bin/jq"
    target="${homeDir}/.claude.json"

    registerMcp() {
      name="$1"
      spec="$2"
      current=""
      if [ -f "$target" ]; then
        current=$("$jqBin" -c --arg n "$name" '
          if (.mcpServers[$n] != null) then
            .mcpServers[$n] | {
              command: (.command // ""),
              args: (.args // []),
              env: (.env // {}),
              alwaysLoad: (.alwaysLoad // false)
            }
          else
            empty
          end
        ' "$target" 2>/dev/null || true)
      fi
      wanted=$(printf '%s' "$spec" | "$jqBin" -c '{
        command: (.command // ""),
        args: (.args // []),
        env: (.env // {}),
        alwaysLoad: (.alwaysLoad // false)
      }')

      if [ "$current" = "$wanted" ]; then
        :
      elif [ -n "''${DRY_RUN:-}" ]; then
        echo "claude-mcp: would (re)register $name -> $wanted (was: ''${current:-none})" >&2
      else
        "$claudeBin" mcp remove -s user "$name" >/dev/null 2>&1 || true
        if "$claudeBin" mcp add-json -s user "$name" "$spec" >&2; then
          echo "claude-mcp: registered $name" >&2
        else
          echo "claude-mcp: failed to register $name (see above)" >&2
        fi
      fi
    }

    if [ ! -x "$claudeBin" ]; then
      echo "claude-mcp: claude CLI not found, skipping" >&2
    else
      registerMcp fff '{"type":"stdio","command":"${pkgs.martin.fff-mcp}/bin/fff-mcp","args":[],"alwaysLoad":true}'
      # codedb is a hand-installed binary outside Nix; register it only when present.
      if [ -x "${homeDir}/bin/codedb" ]; then
        registerMcp codedb '{"type":"stdio","command":"${homeDir}/bin/codedb","args":["mcp"],"alwaysLoad":true}'
      fi
      ${lib.optionalString isDarwin ''
        registerMcp drafts '{"type":"stdio","command":"${pkgs.martin.drafts-mcp-server}/bin/drafts-mcp-server","args":[]}'
      ''}
    fi
  '';

  # Antigravity Desktop's `/` menu lists workflows, not skills.
  home.activation.antigravityWorkflows = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wfDir="${homeDir}/.gemini/config/workflows"
    skillDir="${homeDir}/.gemini/config/skills"
    if [ -n "''${DRY_RUN:-}" ]; then
      echo "antigravity-workflows: would mirror skills from $skillDir to $wfDir" >&2
    elif [ -d "$skillDir" ]; then
      mkdir -p "$wfDir"
      find "$wfDir" -type l ! -exec test -e {} \; -delete 2>/dev/null || true
      for s in "$skillDir"/*; do
        if [ -f "$s/SKILL.md" ]; then
          name=$(basename "$s")
          ln -sf "$s/SKILL.md" "$wfDir/$name.md"
        fi
      done
    fi
  '';

  programs.agent-skills = {
    enable = true;

    sources = {
      dotfiles-pi = mkSource "dotfiles" "dot_pi/agent/skills"
        "^web-browser$";
      archify = mkSource "archify" "." null;
      better-github-skill = mkSource "better-github-skill" "." null;
      interfaces = mkSource "interfaces-skills" "skills" null;
    } // mpSources // effectSources;

    skills = {
      enable = enabledMattpocockSkills ++ [ "archify" "better-github-skill" ] ++ interfacesSkillNames;
      enableAll = [ ];
      explicit = {
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
