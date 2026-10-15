{ lib, pkgs, startupSections ? [ ], developmentSections ? [ ] }:

let
  renderAgentGuide = import ./render-agent-guide.nix { inherit lib; };
  shared = {
    workingContract = ./shared/working-contract.md;
    development = ./shared/development.md;
    qualityAndStyle = ./shared/quality-and-style.md;
    humanDocuments = ./shared/human-documents.md;
    plainEnglish = ./shared/plain-english.md;
  };
  languageNames = [ "typescript" "python" "go" "rust" ];
  languageGuide = guidanceDir: language:
    let
      source = ./shared/languages + "/${language}.md";
    in
    {
      inherit source;
      target = "${guidanceDir}/languages/${language}.md";
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
  mkHost =
    { name
    , startupTarget
    , startupAdapter
    , developmentTarget
    , developmentAdapter ? null
    , humanDocumentsTarget ? null
    , plainEnglish ? true
    }:
    let
      host =
        {
          startup = mkGuide "${name}-agents.md" startupTarget startupAdapter ([
            shared.workingContract
            shared.qualityAndStyle
          ] ++ lib.optional plainEnglish shared.plainEnglish ++ startupSections);
          development = mkGuide "${name}-development.md" developmentTarget developmentAdapter
            ([ shared.development ] ++ developmentSections);
          languages = lib.genAttrs languageNames (languageGuide (builtins.dirOf developmentTarget));
        }
        // lib.optionalAttrs (humanDocumentsTarget != null) {
          humanDocuments = {
            target = humanDocumentsTarget;
            source = shared.humanDocuments;
            content = builtins.readFile shared.humanDocuments;
          };
        };
    in
    host // {
      guides = [ host.startup host.development ]
      ++ lib.attrValues host.languages
      ++ lib.optionals (host ? humanDocuments) [ host.humanDocuments ];
    };
  hosts = {
    general = mkHost {
      name = "general";
      startupTarget = "AGENTS.md";
      startupAdapter = ./AGENTS.md;
      developmentTarget = ".config/agent-guidance/development.md";
      humanDocumentsTarget = ".config/agent-guidance/human-documents.md";
    };
    codex = mkHost {
      name = "codex";
      startupTarget = ".codex/AGENTS.md";
      startupAdapter = ./codex/AGENTS.md;
      developmentTarget = ".codex/guidance/development.md";
      developmentAdapter = ./codex/guidance/development.md;
      humanDocumentsTarget = ".codex/guidance/human-documents.md";
    };
    omp = mkHost {
      name = "omp";
      startupTarget = ".omp/agent/AGENTS.md";
      startupAdapter = ./omp/agent/AGENTS.md;
      developmentTarget = ".omp/agent/guidance/development.md";
      developmentAdapter = ./omp/agent/guidance/development.md;
      humanDocumentsTarget = ".omp/agent/guidance/human-documents.md";
    };
    claude = mkHost {
      name = "claude";
      startupTarget = ".claude/CLAUDE.md";
      startupAdapter = ../claude/claude-adapter.md;
      developmentTarget = ".claude/guidance/development.md";
      developmentAdapter = ../claude/development.md;
      humanDocumentsTarget = ".claude/guidance/human-documents.md";
      plainEnglish = false;
    };
    # Antigravity Desktop and agy share this global rules file. It points at
    # the general host's guidance, so only the startup file is new.
    antigravity =
      let
        startup = hosts.general.startup // { target = ".gemini/config/AGENTS.md"; };
      in
      hosts.general // {
        inherit startup;
        guides = [ startup ];
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
