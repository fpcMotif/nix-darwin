{ lib, ... }:

let
  # Provider credentials and endpoints a wrapper hides from the tool it runs.
  aiEnvVars = [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_API_URL"
    "ANTHROPIC_BASE_URL"
    "ANTHROPIC_AUTH_TOKEN"
    "OPENAI_API_KEY"
    "OPENAI_API_KEY_ID"
    "OPENAI_BASE_URL"
    "OPENAI_API_BASE"
    "OPENAI_ENDPOINT"
    "CODEX_API_KEY"
    "CODEX_BASE_URL"
    "AMP_API_KEY"
    "AMP_URL"
    "AMP_API_BASE_URL"
  ];

  # Fish has no subshell, so `env -u` scopes the removal to the child.
  envWithoutAi = extra:
    "env " + lib.concatMapStringsSep " " (v: "-u ${v}") (aiEnvVars ++ extra);
  claudeEnv = envWithoutAi [ "CLAUDE_CODE_EFFORT_LEVEL" "CLAUDE_EFFORT" ];
in
{
  home.sessionVariables = {
    CLIPROXY_BASE_URL = "http://127.0.0.1:8317";
    CLIPROXY_CONFIG = "$HOME/CLIProxyAPI/config.yaml";
  };

  programs = {
    zsh.initContent = lib.mkAfter ''
      _unset_ai_env() {
        unset ${lib.concatStringsSep " " aiEnvVars}
      }

      # `claude`/`cc` default to ultracode (xhigh effort + standing dynamic-workflow
      # orchestration). ultracode is NOT a valid `--effort` value — that flag only
      # accepts low|medium|high|xhigh|max — so it's enabled via its `--settings`
      # boolean key. The `unset` is load-bearing: the session-wide
      # CLAUDE_CODE_EFFORT_LEVEL=xhigh default (modules/home/zsh.nix) would
      # otherwise shadow ultracode for the whole session — so wrappers drop it to
      # get full ultracode, while bypass launches stay floored at xhigh (never
      # max). Switch effort per-session from inside Claude Code with `/effort <level>`.
      cofficial() {
        (
          _unset_ai_env
          unset CLAUDE_CODE_EFFORT_LEVEL CLAUDE_EFFORT
          "$HOME/.local/bin/claude" --dangerously-skip-permissions --settings '{"ultracode":true}' "$@"
        )
      }

      claude() {
        (
          _unset_ai_env
          unset CLAUDE_CODE_EFFORT_LEVEL CLAUDE_EFFORT
          command "$HOME/.local/bin/claude" --settings '{"ultracode":true}' "$@"
        )
      }

      cc() { cofficial "$@" }

      _codex_cli() {
        if (( $+commands[codex-safe] )); then
          command codex-safe "$@"
        else
          command codex "$@"
        fi
      }
      codex() { _codex_cli "$@" }

      _climode_get() {
        if [[ -f "$HOME/.config/climode.json" ]]; then
          if (( $+commands[jq] )); then
            jq -r --arg key "$1" '.[$key] // "proxy"' "$HOME/.config/climode.json" 2>/dev/null
          else
            python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], 'proxy'))" "$HOME/.config/climode.json" "$1" 2>/dev/null
          fi
        else
          printf -- "proxy\n"
        fi
      }

      _ai_proxy_available() {
        (( $+commands[with-cliproxy] || $+functions[with-cliproxy] ))
      }

      _ai_run_with_optional_proxy() {
        local tool="$1"
        local direct_env="''${2:-keep-env}"
        shift 2

        if [[ "$(_climode_get "$tool")" == "direct" ]] || ! _ai_proxy_available; then
          if [[ "$direct_env" == "clear-env" ]]; then
            (_unset_ai_env; command "$tool" "$@")
          else
            command "$tool" "$@"
          fi
        else
          with-cliproxy "$tool" "$@"
        fi
      }

      opencode() {
        case "''${1:-}" in
          auth) (_unset_ai_env; command opencode "$@") ;;
          *) _ai_run_with_optional_proxy opencode keep-env "$@" ;;
        esac
      }

      amp() {
        case "''${1:-}" in
          login|logout|whoami|auth) (_unset_ai_env; command amp "$@") ;;
          *) _ai_run_with_optional_proxy amp keep-env "$@" ;;
        esac
      }

      crush() { _ai_run_with_optional_proxy crush keep-env "$@" }

      droid() {
        case "''${1:-}" in
          login|logout|whoami|auth) (_unset_ai_env; command droid "$@") ;;
          *) _ai_run_with_optional_proxy droid keep-env "$@" ;;
        esac
      }

      pi() {
        case "''${1:-}" in
          login|logout|whoami|auth) (_unset_ai_env; command pi "$@") ;;
          *) _ai_run_with_optional_proxy pi clear-env "$@" ;;
        esac
      }
    '';

    # Same wrappers for fish. The CLAUDE_CODE_EFFORT_LEVEL note above applies.
    # Wrappers named after a real command exist only in interactive fish, as in
    # zsh, so fish scripts and `fish -c` still run the real command.
    fish.interactiveShellInit = ''
      function claude
          ${claudeEnv} "$HOME/.local/bin/claude" --settings '{"ultracode":true}' $argv
      end

      function cc
          cofficial $argv
      end

      function codex
          _codex_cli $argv
      end

      function opencode
          switch "$argv[1]"
              case auth
                  ${envWithoutAi [ ]} opencode $argv
              case '*'
                  _ai_run_with_optional_proxy opencode keep-env $argv
          end
      end

      function amp
          switch "$argv[1]"
              case login logout whoami auth
                  ${envWithoutAi [ ]} amp $argv
              case '*'
                  _ai_run_with_optional_proxy amp keep-env $argv
          end
      end

      function crush
          _ai_run_with_optional_proxy crush keep-env $argv
      end

      function droid
          switch "$argv[1]"
              case login logout whoami auth
                  ${envWithoutAi [ ]} droid $argv
              case '*'
                  _ai_run_with_optional_proxy droid keep-env $argv
          end
      end

      function pi
          switch "$argv[1]"
              case login logout whoami auth
                  ${envWithoutAi [ ]} pi $argv
              case '*'
                  _ai_run_with_optional_proxy pi clear-env $argv
          end
      end
    '';

    fish.functions = {
      cofficial = ''
        ${claudeEnv} "$HOME/.local/bin/claude" --dangerously-skip-permissions --settings '{"ultracode":true}' $argv
      '';

      _codex_cli = ''
        if command -q codex-safe
            command codex-safe $argv
        else
            command codex $argv
        end
      '';

      _climode_get = ''
        set -l mode_file "$HOME/.config/climode.json"
        if test -f $mode_file
            if command -q jq
                jq -r --arg key $argv[1] '.[$key] // "proxy"' $mode_file 2>/dev/null
            else
                python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], 'proxy'))" $mode_file $argv[1] 2>/dev/null
            end
        else
            printf -- 'proxy\n'
        end
      '';

      _ai_proxy_available = "command -q with-cliproxy; or functions -q with-cliproxy";

      _ai_run_with_optional_proxy = ''
        set -l tool $argv[1]
        set -l direct_env $argv[2]
        set -e argv[1..2]

        if test "$(_climode_get $tool)" = direct; or not _ai_proxy_available
            if test "$direct_env" = clear-env
                ${envWithoutAi [ ]} $tool $argv
            else
                command $tool $argv
            end
        else
            with-cliproxy $tool $argv
        end
      '';
    };
  };
}
