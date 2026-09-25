{ lib, ... }:

{
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

    opencode() {
      case "''${1:-}" in
        auth) (_unset_ai_env; command opencode "$@") ;;
        *) command opencode "$@" ;;
      esac
    }

    amp() {
      case "''${1:-}" in
        login|logout|whoami|auth) (_unset_ai_env; command amp "$@") ;;
        *) command amp "$@" ;;
      esac
    }

    droid() {
      case "''${1:-}" in
        login|logout|whoami|auth) (_unset_ai_env; command droid "$@") ;;
        *) command droid "$@" ;;
      esac
    }

    pi() { (_unset_ai_env; command pi "$@") }
  '';
}
