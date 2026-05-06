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
  # ~/.pi/agent/skills, ~/.cursor/skills, ~/.codex/skills, ~/.agents/skills.
  linkTarget = dest: { enable = true; inherit dest; structure = "link"; systems = [ ]; };

  # mattpocock/skills promoted buckets. `personal/` and `deprecated/` are
  # excluded per upstream CONTEXT.md. New upstream skills under any bucket
  # auto-load on the next `nix flake update mattpocock-skills`.
  mattpocockBuckets = [ "engineering" "productivity" "misc" ];
  mpSources = listToAttrs (map (b: {
    name = "mp-${b}";
    value = mkSource "mattpocock-skills" "skills/${b}" null;
  }) mattpocockBuckets);
in
{
  imports = [ inputs.agent-skills.homeManagerModules.default ];

  # === Stable user-PATH binary ===
  # Survives store-path churn so macOS TCC and editor integrations don't
  # re-prompt every darwin-rebuild switch.
  home.file.".local/bin/claude".source = pkgs.claude-code + "/bin/claude";

  # === Reproducible files (read-only, dotfiles-sourced) ===
  home.file = {
    ".claude/CLAUDE.md".source = renderChezmoi (dotClaude + "/claude.md.tmpl");
    ".claude/RTK.md".source = dotClaude + "/RTK.md";
    ".claude/statusline-command.sh" = {
      source = dotClaude + "/executable_statusline-command.sh";
      executable = true;
    };
    ".claude/hooks/rtk-rewrite.sh" = {
      source = dotClaude + "/hooks/executable_rtk-rewrite.sh";
      executable = true;
    };
    ".claude/hooks/.rtk-hook.sha256".source = dotClaude + "/hooks/dot_rtk-hook.sha256";
  };

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

  # === Skills (was modules/home/skills.nix) ===
  programs.agent-skills = {
    enable = true;

    sources = {
      dotfiles-pi = mkSource "dotfiles" "dot_pi/agent/skills"
        "^(git-workflow|review|ralph-loop|web-browser)$";
      dotfiles-claude = mkSource "dotfiles" "dot_claude/skills"
        "^(lazygit)$";
    } // mpSources;

    skills = {
      enable = [ ];
      enableAll = builtins.attrNames mpSources;
      explicit = {
        # Skills that need CLI deps symlinked into the bundle dir.
        # mattpocock skills inherit from user PATH (git/gh/jq/bun globally).
        git-workflow = mkSkill "dotfiles-pi" "git-workflow" [ pkgs.git pkgs.gh pkgs.jq ];
        review = mkSkill "dotfiles-pi" "review" [ pkgs.git pkgs.gh pkgs.jq ];
        lazygit = mkSkill "dotfiles-claude" "lazygit" [ pkgs.git pkgs.lazygit ];
        ralph-loop = mkSkill "dotfiles-pi" "ralph-loop" [ ];
        web-browser = mkSkill "dotfiles-pi" "web-browser" [ ];
      };
    };

    targets = {
      agents = linkTarget ".agents/skills";
      claude = linkTarget ".claude/skills";
      cursor = linkTarget ".cursor/skills";
      codex = linkTarget ".codex/skills";
      pi = linkTarget ".pi/agent/skills";
    };

    excludePatterns = [ ];
  };
}
