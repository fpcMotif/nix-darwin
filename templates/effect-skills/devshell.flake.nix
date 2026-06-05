{
  description = "Per-project devShell that loads the Effect-TS agent skill into this repo's picker dirs";

  # Copy this file to an Effect repo as `flake.nix` and add `use flake` to
  # `.envrc` (direnv). On `nix develop` / direnv entry the Effect-TS SKILL.md is
  # copy-tree'd into THIS repo's ./.claude/skills + ./.agents/skills, so Claude
  # Code / Codex / Cursor launched from the project see effect-ts — and only
  # there. It is intentionally NOT in the global Nix bundle (see
  # modules/home/claude.nix `enableAll = [ ]`): effect-ts is dependency-scoped.
  #
  # Mirrors agent-skills-nix's own examples/devshell. The copy-tree install
  # refuses to clobber a non-store dir unless AGENT_SKILLS_FORCE=1, so it won't
  # stomp hand-authored repo skills.

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
