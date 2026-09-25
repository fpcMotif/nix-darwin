{ lib, pkgs }:

let
  renderAgentGuide = import ./render-agent-guide.nix { inherit lib; };
  shared = {
    workingContract = ./shared/working-contract.md;
    development = ./shared/development.md;
    qualityAndStyle = ./shared/quality-and-style.md;
    testing = ./shared/testing.md;
    humanDocuments = ./shared/human-documents.md;
  };
  copy = target: source: {
    inherit target source;
    content = builtins.readFile source;
  };
  mkGuide = name: target: adapter: sections:
    let
      content = renderAgentGuide ((lib.optional (adapter != null) adapter) ++ sections);
    in
    {
      inherit target content;
      source = pkgs.writeText name content;
    };
  # A linked host gets a short startup guide that points to separate guides.
  mkHost =
    { name
    , startupTarget
    , startupAdapter
    , developmentTarget
    , developmentAdapter ? null
    , testingTarget
    , humanDocumentsTarget ? null
    }:
    let
      host =
        {
          startup = mkGuide "${name}-agents.md" startupTarget startupAdapter [
            shared.workingContract
            shared.qualityAndStyle
          ];
          development = mkGuide "${name}-development.md" developmentTarget developmentAdapter [
            shared.development
          ];
          testing = copy testingTarget shared.testing;
        }
        // lib.optionalAttrs (humanDocumentsTarget != null) {
          humanDocuments = copy humanDocumentsTarget shared.humanDocuments;
        };
    in
    host // {
      guides = [ host.startup host.development host.testing ]
      ++ lib.optionals (host ? humanDocuments) [ host.humanDocuments ];
    };
  # OMP auto-loads only `@path` imports, never a "read FILE" pointer, so its
  # one startup guide inlines every guide a linked host points to.
  mkInlineHost = { name, startupTarget, startupAdapter }:
    let
      startup = mkGuide "${name}-agents.md" startupTarget startupAdapter [
        shared.workingContract
        shared.qualityAndStyle
        shared.development
        shared.testing
        shared.humanDocuments
      ];
    in
    {
      inherit startup;
      guides = [ startup ];
    };
  hosts = {
    general = mkHost {
      name = "general";
      startupTarget = "AGENTS.md";
      startupAdapter = ./AGENTS.md;
      developmentTarget = ".config/agent-guidance/development.md";
      testingTarget = ".config/agent-guidance/testing.md";
    };
    codex = mkHost {
      name = "codex";
      startupTarget = ".codex/AGENTS.md";
      startupAdapter = ./codex/AGENTS.md;
      developmentTarget = ".codex/guidance/development.md";
      developmentAdapter = ./codex/guidance/development.md;
      testingTarget = ".codex/guidance/testing.md";
    };
    omp = mkInlineHost {
      name = "omp";
      startupTarget = ".omp/agent/AGENTS.md";
      startupAdapter = ./omp/agent/AGENTS.md;
    };
    claude = mkHost {
      name = "claude";
      startupTarget = ".claude/CLAUDE.md";
      startupAdapter = ../claude/CLAUDE.md;
      developmentTarget = ".claude/guidance/development.md";
      developmentAdapter = ../claude/development.md;
      testingTarget = ".claude/guidance/testing.md";
      humanDocumentsTarget = ".claude/guidance/human-documents.md";
    };
  };
  targets = lib.concatLists (lib.mapAttrsToList
    (_: host: map (guide: guide.target) host.guides)
    hosts);
in
{
  inherit hosts targets;
  filesFor = names: builtins.listToAttrs (lib.concatMap
    (name: map (guide: lib.nameValuePair guide.target guide.source) hosts.${name}.guides)
    names);
}
