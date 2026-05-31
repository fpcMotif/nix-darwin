{ lib, ... }:

{
  home.sessionVariables = {
    CLIPROXY_BASE_URL = "http://127.0.0.1:8317";
    CLIPROXY_CONFIG = "$HOME/CLIProxyAPI/config.yaml";

    # Codex `chrome@openai-bundled` plugin is hardcoded to stable Google Chrome
    # paths on macOS. Point its check scripts at Chrome Canary instead so it can
    # detect the installed Codex extension + native messaging host there.
    # See ~/.codex/plugins/cache/openai-bundled/chrome/0.1.7/scripts/*.js
    CODEX_CHROME_USER_DATA_DIR = "$HOME/Library/Application Support/Google/Chrome Canary";
    CODEX_CHROME_PREFERENCES_PATH = "$HOME/Library/Application Support/Google/Chrome Canary/Default/Secure Preferences";
    CODEX_CHROME_NATIVE_HOST_MANIFEST_PATH = "$HOME/Library/Application Support/Google/Chrome Canary/NativeMessagingHosts/com.openai.codexextension.json";
  };

  programs.zsh.initContent = lib.mkAfter ''
    _unset_ai_env() {
      unset ANTHROPIC_API_KEY ANTHROPIC_API_URL ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN \
            OPENAI_API_KEY OPENAI_API_KEY_ID OPENAI_BASE_URL OPENAI_API_BASE OPENAI_ENDPOINT \
            CODEX_API_KEY CODEX_BASE_URL \
            AMP_API_KEY AMP_URL AMP_API_BASE_URL
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
        "$HOME/.local/bin/claude" --settings '{"ultracode":true}' "$@"
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
}
