{ ... }:

let
  reasoningModel = id: name: {
    inherit id name;
    cost_per_1m_in = 0;
    cost_per_1m_out = 0;
    cost_per_1m_in_cached = 0;
    cost_per_1m_out_cached = 0;
    context_window = 272000;
    default_max_tokens = 32000;
    can_reason = true;
    reasoning_levels = [ "low" "medium" "high" ];
    default_reasoning_effort = "medium";
    supports_attachments = false;
    options = { };
  };

  modelDefaults = provider: model: effort: {
    inherit provider model;
    reasoning_effort = effort;
    max_tokens = 32000;
  };

  config = {
    "$schema" = "https://charm.land/crush.json";

    providers.chatgpt-sub = {
      id = "chatgpt-sub";
      name = "ChatGPT subscription via local Codex proxy";
      type = "openai-compat";
      base_url = "http://127.0.0.1:10531/v1";
      api_key = "not-required";
      models = [
        (reasoningModel "gpt-5.5" "GPT-5.5 (ChatGPT subscription)")
        (reasoningModel "gpt-5.3-codex-spark" "GPT-5.3 Codex Spark (ChatGPT subscription)")
      ];
    };

    # Kimi Code subscription. api_key runs through Crush's embedded shell at
    # load time ($(...) expansion), so the key is pulled straight from macOS
    # Keychain and never touches this git-tracked file. Stored via:
    #   security add-generic-password -a "$USER" -s kimi-code-access-token -w "<key>"
    # No `-a` on lookup: Crush's embedded shell doesn't reliably inherit
    # $USER, and the service name alone is already a unique match.
    providers.kimi-code = {
      id = "kimi-code";
      name = "Kimi Code subscription";
      type = "openai-compat";
      base_url = "https://api.kimi.com/coding/v1";
      api_key = "$(security find-generic-password -s kimi-code-access-token -w)";
      extra_headers = {
        User-Agent = "KimiCLI/1.5";
        X-Msh-Platform = "kimi_cli";
      };
      models = [
        {
          id = "k3";
          name = "Kimi K3 (Kimi Code subscription)";
          cost_per_1m_in = 0;
          cost_per_1m_out = 0;
          cost_per_1m_in_cached = 0;
          cost_per_1m_out_cached = 0;
          context_window = 1048576;
          default_max_tokens = 131072;
          can_reason = true;
          reasoning_levels = [ "max" ];
          default_reasoning_effort = "max";
          supports_attachments = true;
          options = { };
        }
      ];
    };

    models = {
      large = modelDefaults "chatgpt-sub" "gpt-5.5" "medium";
      small = modelDefaults "chatgpt-sub" "gpt-5.3-codex-spark" "low";
      execute = modelDefaults "chatgpt-sub" "gpt-5.5" "medium";
      commit = modelDefaults "chatgpt-sub" "gpt-5.3-codex-spark" "low";
    };

    options = {
      disable_default_providers = true;
      disable_provider_auto_update = true;
    };
  };
in
{
  xdg.configFile."crush/crush.json".text = builtins.toJSON config;
}
