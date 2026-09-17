{ lib, ... }:

let
  routing = import ../shared/agent-model-routing.nix { inherit lib; };
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
  routeDefaults = job:
    modelDefaults "chatgpt-sub" (routing.modelId job) (routing.effort job);

  config = {
    "$schema" = "https://charm.land/crush.json";

    providers.chatgpt-sub = {
      id = "chatgpt-sub";
      name = "ChatGPT subscription via local Codex proxy";
      type = "openai-compat";
      base_url = "http://127.0.0.1:10531/v1";
      api_key = "not-required";
      models = [
        (reasoningModel (routing.modelId "general") "GPT-5.6 Terra (ChatGPT subscription)")
        (reasoningModel (routing.modelId "economy") "GPT-5.6 Luna (ChatGPT subscription)")
        (reasoningModel (routing.modelId "search") "GPT-5.3 Codex Spark (ChatGPT subscription)")
      ];
    };

    models = lib.mapAttrs (_: job: routeDefaults job) routing.adapters.crush;

    options = {
      disable_default_providers = true;
      disable_provider_auto_update = true;
    };
  };
in
{
  xdg.configFile."crush/crush.json".text = builtins.toJSON config;
}
