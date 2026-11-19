{ pkgs, lib, ... }:

let
  routing = import ../../modules/shared/agent-model-routing.nix { inherit lib; };
  policy = pkgs.writeText "agent-model-routing-test.json" (builtins.toJSON routing.policy);
  omp = routing.adapters.omp;
  roleModel = role: omp.normal.modelRoles.${role};
  agentModel = agent:
    let role = lib.removePrefix "@" omp.normal.task.agentModelOverrides.${agent};
    in roleModel role;
  fallbackChains = omp.normal.retry.fallbackChains;
  inherit (omp) economy;
  serializedAdapters = builtins.toJSON routing.adapters;
  routingPython = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
in
assert agentModel "scout" == routing.selector "search";
assert agentModel "explore" == routing.selector "search";
assert agentModel "librarian" == routing.selector "search";
assert agentModel "reviewer" == routing.selector "check";
assert agentModel "security-reviewer" == routing.selector "check";
assert agentModel "task" == routing.selector "general";
assert agentModel "plan" == routing.selector "plan";
assert fallbackChains.${routing.bareSelector "general"} == [ (routing.bareSelector "economy") ];
assert fallbackChains.${routing.bareSelector "search"} == [ ];
assert fallbackChains.${routing.bareSelector "economy"} == [ ];
assert omp.normal.modelRoles.default == "google-antigravity/gemini-3.8-flash:high";
assert lib.all (lib.hasPrefix "openai-codex/") (lib.attrValues (builtins.removeAttrs omp.normal.modelRoles [ "default" ]));
assert lib.all
  (model:
  lib.hasPrefix "openai-codex/gpt-6-" model
    || model == "google-antigravity/*"
  )
  omp.normal.enabledModels;
assert lib.elem "google-antigravity/*" omp.normal.enabledModels;
assert lib.all (model: lib.hasInfix model serializedAdapters) [
  "gpt-6-astra"
  "gpt-6-sol"
  "gpt-6-luna"
];
assert economy.modelRoles.default == routing.selector "economy";
assert economy.modelRoles.reviewer == routing.selector "check";
assert economy.modelRoles.plan == routing.selector "plan";
assert economy.task.agentModelOverrides == omp.normal.task.agentModelOverrides;
assert economy.retry == omp.normal.retry;
assert routing.adapters.codex.profiles.fast.model == routing.modelId "search";
assert routing.adapters.codex.profiles.plan.model == routing.modelId "plan";
assert !(lib.hasInfix "gpt-5." serializedAdapters);
pkgs.runCommand "unit-ai-model-routing" { } ''
  ${routingPython}/bin/python3 ${./ai-model-routing-test.py} \
    ${../../modules/home/ai-model-routing.py} ${policy}
  touch $out
''
