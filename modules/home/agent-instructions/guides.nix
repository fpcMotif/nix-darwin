{ lib, pkgs, startupSections ? [ ], developmentSections ? [ ] }:

let
  renderAgentGuide = import ./render-agent-guide.nix { inherit lib; };
  shared = {
    workingContract = ./shared/working-contract.md;
    development = ./shared/development.md;
    filesystemLookups = ./shared/filesystem-lookups.md;
    qualityAndStyle = ./shared/quality-and-style.md;
    humanDocuments = ./shared/human-documents.md;
    plainEnglish = ./shared/plain-english.md;
    searchRules = ./shared/search-rules.md;
  };
  guidesSection = name: { developmentTarget, humanDocumentsTarget }:
    let
      languagesDir = "~/${builtins.dirOf developmentTarget}/languages";
    in
    builtins.toFile "${name}-guides.md" (''
      ## Guides

      - **Develop**: Before choosing a shell command, adding an environment variable, using version control, or setting up Git hooks, read `~/${developmentTarget}`.
      - **Languages**: Before writing or running TypeScript, Python, Go, or Rust, read that language's file: `${languagesDir}/typescript.md`, `python.md`, `go.md`, or `rust.md`.
    '' + lib.optionalString (humanDocumentsTarget != null) ''
      - **Documents**: Before writing an issue, specification, PRD, analysis, ADR, or GLOSSARY.md, read `~/${humanDocumentsTarget}`.
    '' + ''
      - **Workspaces**: Before creating a Git worktree or JJ workspace, read Parallel checkouts in `~/${developmentTarget}`.
    '');
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
            (guidesSection name { inherit developmentTarget humanDocumentsTarget; })
            shared.searchRules
            shared.workingContract
            shared.qualityAndStyle
          ] ++ lib.optional plainEnglish shared.plainEnglish ++ startupSections);
          development = mkGuide "${name}-development.md" developmentTarget developmentAdapter
            ([ shared.development shared.filesystemLookups ] ++ developmentSections);
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
