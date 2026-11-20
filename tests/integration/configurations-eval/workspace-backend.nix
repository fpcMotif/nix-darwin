ctx:

let
  inherit (ctx) helpers lib evalsOk darwinDojjo darwinDojjoHome hasPackage darwinHome;
in
[
  (helpers.assertTest "darwin-dojjo-evaluates"
    (evalsOk darwinDojjo.system)
    "darwinConfigurations.f with workspaceBackend = dojjo should evaluate")

  (helpers.assertTest "darwin-dojjo-replaces-worktrunk"
    (darwinDojjoHome.martin.development.workspaceBackend == "dojjo"
      && darwinDojjoHome.programs.worktrunk.enable == false
      && !(darwinDojjoHome.xdg.configFile ? "worktrunk/config.toml")
      && darwinDojjoHome.xdg.configFile ? "dojjo/config.toml"
      && hasPackage "dojjo-bin" darwinDojjoHome.home.packages
      && !(hasPackage "worktrunk" darwinDojjoHome.home.packages))
    "dojjo backend should install djo and its config.toml, and drop wt and its config.toml")

  (helpers.assertTest "darwin-dojjo-zsh-integration"
    (lib.hasInfix "-dojjo-init.zsh" darwinDojjoHome.programs.zsh.initContent
      && !(lib.hasInfix "-worktrunk-init.zsh" darwinDojjoHome.programs.zsh.initContent))
    "dojjo backend should source the build-rendered djo wrapper and completion, not wt's")

  (helpers.assertTest "darwin-dojjo-drops-worktrunk-markers"
    (!(darwinDojjoHome.home.file ? ".claude/hooks/worktrunk-marker.sh")
      && darwinDojjoHome.home.activation ? "claudeSettingsOwnership")
    "dojjo backend should stop installing the Worktrunk marker script and keep the settings reconciler")

  (helpers.assertTest "darwin-dojjo-agent-guidance"
    (lib.all
      (target:
        let guide = darwinDojjoHome.home.file.${target}.source.text;
        in lib.hasInfix "djo switch --create" guide && !(lib.hasInfix "wt switch" guide))
      [ ".claude/guidance/development.md" ".codex/guidance/development.md" ".config/agent-guidance/development.md" ])
    "dojjo backend should render dojjo guidance for every agent host")

  (helpers.assertTest "darwin-default-agent-guidance"
    (lib.hasInfix "wt switch --create" darwinHome.home.file.".claude/guidance/development.md".source.text)
    "the default backend should keep Worktrunk guidance")
]
