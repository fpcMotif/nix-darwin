{
  description = "Per-project devShell that loads the Effect-TS agent skill into this repo's picker dirs";

  # Scope Effect-TS skills to Effect repos via direnv (`use flake`) instead of
  # bundling them globally, and skip non-store dirs unless AGENT_SKILLS_FORCE=1.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    agent-skills.inputs.nixpkgs.follows = "nixpkgs";
    effect-ts-skills.url = "github:Effect-TS/skills";
    effect-ts-skills.flake = false;
  };

  outputs = { nixpkgs, flake-utils, agent-skills, effect-ts-skills, ... }:
    let
      agentLib = agent-skills.lib.agent-skills;

      # Source/selection are platform-independent — compute once.
      sources = { effect-ts = { path = effect-ts-skills; subdir = "skills"; }; };
      catalog = agentLib.discoverCatalog sources;
      allowlist = agentLib.allowlistFor {
        inherit catalog sources;
        enable = [ "effect-ts" ];
      };
      selection = agentLib.selectSkills {
        inherit catalog allowlist sources;
        skills = { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        bundle = agentLib.mkBundle {
          inherit pkgs selection;
          name = "effect-ts-skill-bundle";
        };
        # Materialise into the project's Claude + shared-agents picker dirs.
        # Add cursor/codex/etc. here if this project drives those agents too.
        localTargets = {
          claude = agentLib.defaultLocalTargets.claude // { enable = true; };
          agents = agentLib.defaultLocalTargets.agents // { enable = true; };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          shellHook = agentLib.mkShellHook {
            inherit pkgs bundle;
            targets = localTargets;
          };
        };
      });
}
