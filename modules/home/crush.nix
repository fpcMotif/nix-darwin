_:

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
