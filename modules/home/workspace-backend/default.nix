{ config, lib, pkgs, ... }:

let
  backend = config.martin.development.workspaceBackend;
  worktrunk = config.programs.worktrunk;
  dojjo = pkgs.martin.dojjo-bin;
  toml = pkgs.formats.toml { };

  # `wt config shell init zsh` prints a static script. Rendering it at build
  # time skips a wt fork on every shell start and pins the wrapper to this wt.
  worktrunkZshInit = pkgs.runCommand "worktrunk-init.zsh" { } ''
    ${lib.getExe worktrunk.package} config shell init zsh > $out
  '';

  # dojjo prints static wrapper and completion scripts. Rendering them at build
  # time skips two djo forks on every shell start and pins them to this djo.
  # The wrapper defines `djo` only, so it never competes with `wt` or `jj`.
  dojjoZshInit = pkgs.runCommand "dojjo-init.zsh" { } ''
    ${lib.getExe dojjo} shell init zsh > $out
    ${lib.getExe dojjo} shell completion zsh >> $out
  '';

  # Use a stable hook path so a wt bump does not strand a store path in settings.json.
  # Keep worktree creation native so symlinkDirectories and .worktreeinclude still run.
  marker = state: "$HOME/.claude/hooks/worktrunk-marker.sh ${state}";
  markerHooks = [
    { event = "UserPromptSubmit"; matcher = ""; command = marker "working"; }
    { event = "Notification"; matcher = ""; command = marker "waiting"; }
    { event = "PreToolUse"; matcher = "AskUserQuestion"; command = marker "waiting"; }
    { event = "PermissionRequest"; matcher = ""; command = marker "waiting"; }
    { event = "Stop"; matcher = ""; command = marker "waiting"; }
    { event = "SessionEnd"; matcher = ""; command = marker "clear"; }
  ];
  markerScript = pkgs.writeShellApplication {
    name = "worktrunk-marker";
    runtimeInputs = [ worktrunk.package ];
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
in
{
  options.martin.development.workspaceBackend = lib.mkOption {
    type = lib.types.enum [ "worktrunk" "dojjo" ];
    default = "worktrunk";
    example = "dojjo";
    description = ''
      The tool that creates parallel checkouts beside a repository.

      `worktrunk` installs `wt`, which manages Git worktrees.
      `dojjo` is experimental and installs `djo`, which manages JJ workspaces.
      It is packaged for aarch64-darwin only.

      The choice selects the package, its configuration, its Zsh integration,
      the matching agent guidance, and the Claude Worktrunk activity hooks.
      Changing it never converts repositories or touches existing checkouts.
      See docs/workspace-backends.md.
    '';
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = backend != "dojjo"
            || lib.meta.availableOn pkgs.stdenv.hostPlatform dojjo;
          message = ''
            martin.development.workspaceBackend = "dojjo" is experimental and
            packaged for ${lib.concatStringsSep ", " dojjo.meta.platforms} only,
            not ${pkgs.stdenv.hostPlatform.system}. Use "worktrunk" on this host.
          '';
        }
      ];

      martin.agentSurface.guideSections.development = [
        { worktrunk = ./guide-worktrunk.md; dojjo = ./guide-dojjo.md; }.${backend}
      ];

      # Under any other backend the reconciler removes these entries from
      # settings.json because only worktrunk installs the marker script.
      martin.agentSurface.claudeHooks.${if backend == "worktrunk" then "add" else "remove"} = markerHooks;
    }

    (lib.mkIf (backend == "worktrunk") {
      programs.worktrunk = {
        enable = true;
        enableZshIntegration = false;

        # Home Manager links config.toml read-only. Command approvals live in the
        # separate, mutable ~/.config/worktrunk/approvals.toml, so hook trust still
        # works. Every key wt would write back on a first-run prompt is set here.
        settings = {
          # Shell integration comes from this module, not `wt config shell install`.
          skip-shell-integration-prompt = true;

          # Upstream's default, pinned: sibling directories keep worktrees out of
          # the main checkout's search indexes and file watchers.
          worktree-path = "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}";

          # Upstream's Claude recipe. --safe-mode skips hooks, MCP servers, and
          # skills, so a commit message does not start a full agent session.
          commit.generation.command =
            "MAX_THINKING_TOKENS=0 claude -p --no-session-persistence --model=haiku --tools='' --safe-mode --setting-sources='user' --system-prompt=''";

          # Unset prints a deprecation warning on every `wt list --format json`.
          list.json-schema = 2;
        };
      };

      # Default order 1000 runs after compinit (570), so the wrapper's compdef
      # registration takes effect.
      programs.zsh.initContent = ''
        source ${worktrunkZshInit}
      '';

      home.file.".claude/hooks/worktrunk-marker.sh".source = lib.getExe markerScript;
    })

    (lib.mkIf (backend == "dojjo") {
      home.packages = [ dojjo ];

      # Worktrunk's config.toml is absent under this backend, so every key dojjo
      # needs is declared here rather than inherited through its wt.toml fallback.
      xdg.configFile."dojjo/config.toml".source = toml.generate "dojjo-config.toml" {
        # Worktrunk's sibling layout. dojjo renders repo_path from the workspace
        # it runs in, so creating from a secondary workspace nests the name.
        workspace-path = "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}";

        # Merges never push or delete a workspace directory. Cleanup stays a
        # deliberate `jj workspace forget` plus a manual delete.
        merge = {
          push = false;
          remove = false;
        };
      };

      # Default order 1000 runs after compinit (570), so `compdef _djo djo` works.
      programs.zsh.initContent = ''
        source ${dojjoZshInit}
      '';
    })
  ];
}
