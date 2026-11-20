{ pkgs, lib, ... }:

let
  docLockGuide = ../../modules/home/doc-lock/guide.md;
  guideHosts = startupSections: workspaceGuide: (import ../../modules/home/agent-instructions/guides.nix {
    inherit lib pkgs startupSections;
    developmentSections = [ workspaceGuide ];
  }).hosts;
  hosts = guideHosts [ docLockGuide ] ../../modules/home/workspace-backend/guide-worktrunk.md;
  dojjoHosts = guideHosts [ docLockGuide ] ../../modules/home/workspace-backend/guide-dojjo.md;
  unlockedHosts = guideHosts [ ] ../../modules/home/workspace-backend/guide-worktrunk.md;
  # Each backend's guide names only its own isolation commands.
  workspaceGuideFits = backendHosts: required: forbidden:
    lib.all
      (host:
        lib.all (text: lib.hasInfix text host.development.content) required
        && lib.all (text: !(lib.hasInfix text host.development.content)) forbidden)
      (lib.attrValues backendHosts);
  hasWord = word: text:
    lib.any
      (line:
        builtins.match ".*(^|[^A-Za-z0-9_])${word}($|[^A-Za-z0-9_]).*" line != null)
      (lib.splitString "\n" text);
  contentForHost = host:
    lib.concatStringsSep "\n" (map (guide: guide.content) ([
      host.startup
      host.development
    ] ++ lib.attrValues host.languages));
  count = marker: text: builtins.length (lib.splitString marker text) - 1;
  requiredSections = [
    "## Working contract"
    "## Completion"
    "## What I need from you"
    "## Command routing"
    "## Code search"
    "## Python"
    "## Go"
    "## Version control"
    "## Git hooks"
    "## Parallel checkouts"
    "## Code quality"
    "## Current-state integrity"
    "## Writing"
    "## Docs lock"
  ];
  onceSections = [
    "## Working contract"
    "## Code quality"
    "## Current-state integrity"
    "## Command routing"
    "## Parallel checkouts"
    "## Docs lock"
    "## JavaScript and TypeScript"
    "## Python"
    "## Go"
    "## Rust"
  ];
  # The adapter line that links human-documents.md must name ADRs, or an
  # agent writing one never loads the ADR rules.
  documentsTriggerNamesAdr = host:
    lib.any
      (line: lib.hasInfix "~/${host.humanDocuments.target}" line && lib.hasInfix "ADR" line)
      (lib.splitString "\n" host.startup.content);
  # The adapter line that links development.md must name JJ workspaces, or
  # an agent reaches for a Git worktree before it loads Parallel checkouts.
  workspacesTriggerNamesJj = host:
    lib.any
      (line: lib.hasInfix "~/${host.development.target}" line && lib.hasInfix "JJ workspace" line)
      (lib.splitString "\n" host.startup.content);
  # The adapter line that links the language files must name each language,
  # or an agent writing Go never connects its task to go.md.
  languagesTriggerNamesEach = host:
    lib.any
      (line:
        lib.hasInfix "~/${host.languages.typescript.target}" line
        && lib.all (language: lib.hasInfix "${language}.md" line) (lib.attrNames host.languages)
        && lib.all (name: lib.hasInfix name line) [ "TypeScript" "Python" "Go" "Rust" ])
      (lib.splitString "\n" host.startup.content);
  bannedTerms = [ "gemini" "deepwiki" "mgrep" "lazygit" "deep-research" "chezmoi" ];
  requiredTools = [ "fd" "rg" "bat" "eza" "dust" "procs" "btm" "ax" "delta" "hyperfine" ];
  noModelCache = text: lib.all (term: !(lib.hasInfix term text)) [
    "gpt-"
    "Gemini"
    "Astra"
    "Sol"
    "Terra"
    "Luna"
  ];
  checkHost = name: host:
    let
      content = contentForHost host;
      links = builtins.filter
        (guide: guide.target != host.startup.target
          && !(builtins.elem guide (lib.attrValues host.languages))
          && !(builtins.elem guide host.extras))
        host.guides;
      tools = requiredTools ++ lib.optional (name == "claude") "fff";
    in
    assert lib.all (section: lib.hasInfix section content) requiredSections;
    assert lib.all (section: count section content == 1) onceSections;
    assert lib.all
      (term: !(lib.hasInfix (lib.toLower term) (lib.toLower content)))
      bannedTerms;
    assert noModelCache content;
    assert lib.all (tool: hasWord tool content) tools;
    assert lib.all
      (guide: lib.hasInfix "~/${guide.target}" host.startup.content)
      links;
    true;
  hostChecks = lib.mapAttrsToList checkHost hosts;
in
assert !(hasWord "bat" "batch");
assert lib.all (passed: passed) hostChecks;
assert workspaceGuideFits hosts [ "wt switch --create" ] [ "djo" ];
assert workspaceGuideFits dojjoHosts
  [ "djo switch --create" "jj workspace forget" "never a Git worktree" ]
  [ "wt switch" "wt remove" ];
assert lib.hasInfix "The document is done when" hosts.claude.humanDocuments.content;
assert lib.hasInfix "## ADRs and domain documents" hosts.claude.humanDocuments.content;
assert !(lib.hasInfix "## Plain English" hosts.claude.startup.content);
assert !(lib.hasInfix "ste80" (contentForHost hosts.claude));
assert lib.all
  (name:
  count "## Plain English" hosts.${name}.startup.content == 1
    && lib.hasInfix "~/.agents/skills/ste80/SKILL.md" hosts.${name}.startup.content)
  [ "general" "codex" "omp" "antigravity" ];
assert lib.all
  (host: lib.hasInfix "the `prompt-coach` skill" host.startup.content
    && !(lib.hasInfix "archify" host.startup.content)
    && !(lib.hasInfix "skills/prompt-coach" host.startup.content))
  (lib.attrValues hosts);
assert lib.all
  (host: count "## Guides" host.startup.content == 1
    && count "## Search rules" host.startup.content == 1
    && count "**Code Mode**" host.startup.content == 1
    && count "**Trust**" host.startup.content == 1
    && count "**Develop**" host.startup.content == 1
    && lib.hasInfix "## Filesystem and Nix lookups" host.development.content)
  (lib.attrValues hosts);
assert lib.all
  (adapter: lib.all (label: !(lib.hasInfix label (builtins.readFile adapter)))
    [ "**Develop**" "**Languages**" "**Documents**" "**Workspaces**" "**Trust**" "**Coverage**" ])
  [
    ../../modules/home/agent-instructions/AGENTS.md
    ../../modules/home/agent-instructions/codex/AGENTS.md
    ../../modules/home/agent-instructions/omp/agent/AGENTS.md
    ../../modules/home/claude/claude-adapter.md
  ];
assert hosts.antigravity.startup.target == ".gemini/config/AGENTS.md";
assert hosts.antigravity.startup.content == hosts.general.startup.content;
assert lib.all documentsTriggerNamesAdr
  (builtins.filter (host: host ? humanDocuments) (lib.attrValues hosts));
assert lib.all workspacesTriggerNamesJj (lib.attrValues hosts ++ lib.attrValues dojjoHosts);
assert lib.all languagesTriggerNamesEach (lib.attrValues hosts);
assert lib.all
  (name: hosts.${name}.startup.content
    == unlockedHosts.${name}.startup.content + "\n" + builtins.readFile docLockGuide)
  (builtins.attrNames hosts);
pkgs.runCommand "unit-agent-guides" { } ''
  touch $out
''
