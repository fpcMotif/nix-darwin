{ lib }:

let
  models = {
    astra = {
      provider = "openai-codex";
      id = "gpt-6-astra";
    };
    sol = {
      provider = "openai-codex";
      id = "gpt-6-sol";
    };
    luna = {
      provider = "openai-codex";
      id = "gpt-6-luna";
    };
  };

  jobs = {
    search = {
      model = "sol";
      effort = "medium";
      fallback = [ ];
    };
    check = {
      model = "sol";
      effort = "high";
      fallback = [ ];
    };
    general = {
      model = "astra";
      effort = "high";
      fallback = [ "economy" ];
    };
    plan = {
      model = "astra";
      effort = "xhigh";
      fallback = [ "economy" ];
    };
    economy = {
      model = "luna";
      effort = "medium";
      fallback = [ ];
    };
  };

  resolve = job:
    let
      assignment = jobs.${job};
      model = models.${assignment.model};
    in
    model // assignment // {
      bareSelector = "${model.provider}/${model.id}";
      selector = "${model.provider}/${model.id}:${assignment.effort}";
    };

  routes = lib.mapAttrs (job: _: resolve job) jobs;
  selector = job: routes.${job}.selector;
  bareSelector = job: routes.${job}.bareSelector;
  modelId = job: routes.${job}.id;
  effort = job: routes.${job}.effort;

  pi = {
    defaultJob = "general";
    profiles = [ "search" "check" "general" "plan" "economy" ];
    agents = {
      "planner.md" = "plan";
      "builder.md" = "general";
      "reviewer.md" = "check";
      "researcher.md" = "search";
      "context-builder.md" = "search";
      "scout.md" = "search";
    };
  };

  ompRoleJobs = {
    default = "general";
    vision = "general";
    commit = "search";
    smol = "search";
    tiny = "search";
    worker = "check";
    task = "general";
    advisor = "general";
    reviewer = "check";
    designer = "general";
    plan = "plan";
    slow = "plan";
  };
  ompAgentRoles = {
    scout = "smol";
    sonic = "worker";
    codex-spark-worker = "worker";
    task = "task";
    reviewer = "reviewer";
    security-reviewer = "reviewer";
    codex-plan-deployer = "plan";
    designer = "designer";
    oracle = "slow";
    quick_task = "smol";
    explore = "smol";
    librarian = "smol";
    plan = "plan";
  };
  # Selectable by hand in omp's /model picker and --model; no role or fallback
  # routes to them. Keep this empty so the picker exposes only the GPT-6
  # semantic routes rendered below.
  ompManualModels = [ ];
  ompModelRoles = lib.mapAttrs (_: job: selector job) ompRoleJobs;
  ompAgentOverrides = lib.mapAttrs (_: role: "@${role}") ompAgentRoles;
  ompNormal = {
    modelRoles = ompModelRoles;
    task.agentModelOverrides = ompAgentOverrides;
    enabledModels = lib.unique (map selector [ "search" "check" "general" "plan" "economy" ]) ++ ompManualModels;
    retry = {
      enabled = true;
      modelFallback = true;
      usageAwareFallback = true;
      usageReservePct = 10;
      usageReservePolicy = "confirm";
      waitForUsageReset = false;
      maxRetries = 3;
      maxDelayMs = 30000;
      fallbackRevertPolicy = "cooldown-expiry";
      fallbackChains = {
        "${bareSelector "general"}" = [ (bareSelector "economy") ];
        "${bareSelector "economy"}" = [ ];
        "${bareSelector "search"}" = [ ];
      };
    };
  };
  ompEconomy = lib.recursiveUpdate ompNormal {
    modelRoles = {
      default = selector "economy";
      vision = selector "economy";
      task = selector "economy";
      advisor = selector "economy";
      designer = selector "economy";
    };
    advisor.enabled = false;
    task = {
      maxConcurrency = 4;
      agentAdvisor.task = "off";
    };
  };

  codexProfiles = {
    fast = {
      model = modelId "search";
      model_reasoning_effort = effort "search";
    };
    fast-low = {
      model = modelId "search";
      model_reasoning_effort = "low";
    };
    plan = {
      model = modelId "plan";
      model_reasoning_effort = effort "plan";
    };
    deep = {
      model = modelId "plan";
      model_reasoning_effort = effort "plan";
    };
  };

  adapters = {
    inherit pi;
    omp = {
      roleJobs = ompRoleJobs;
      agentRoles = ompAgentRoles;
      normal = ompNormal;
      economy = ompEconomy;
    };
    codex = {
      profiles = codexProfiles;
      environment = {
        PI_PLAN_MODEL = selector "plan";
        PI_SLOW_MODEL = selector "plan";
        PI_SMOL_MODEL = selector "search";
      };
    };
    crush = {
      large = "general";
      small = "search";
      execute = "general";
      commit = "search";
    };
    zedFavorites = [ "general" "economy" "search" ];
  };

  policy = {
    schemaVersion = 1;
    inherit models jobs;
    adapters = {
      inherit pi;
      omp.normal = ompNormal;
    };
  };
  serialized = builtins.toJSON {
    inherit models jobs adapters;
  };
in
assert routes.search.id == "gpt-6-sol";
assert routes.check.id == "gpt-6-sol";
assert routes.general.id == "gpt-6-astra";
assert routes.economy.id == "gpt-6-luna";
assert lib.all (model: lib.hasPrefix "gpt-6-" model.id) (lib.attrValues models);
{
  inherit models jobs routes resolve selector bareSelector modelId effort adapters policy;
}
