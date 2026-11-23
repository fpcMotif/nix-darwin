{
  # Only the buckets upstream's CLAUDE.md promotes.
  mattpocockBuckets = [ "engineering" "productivity" ];
  disabledMattpocockSkills = [
    "grill-me" # the `grilling` + `grill-with-docs` pairing is the tradeoff we want
    "teach" # unused for months
  ];
  coworkSyncedSkills = {
    enable = false;
    namespace = "anthropic-skills";
    ids = [
      "consolidate-memory"
      "deep-research"
      "docx"
      "explain-usage"
      "google-workspace"
      "import-memory"
      "mcp-builder"
      "morning"
      "pdf"
      "pptx"
      "setup-claude"
      "setup-cowork"
      "skill-creator"
      "web-artifacts-builder"
      "xlsx"
    ];
  };
  # Niche skills trimmed to keep the auto-loaded catalog small. Handled like
  # disabledMattpocockSkills, listed apart because the reason is noise, not
  # breakage.
  leanExcludedMattpocockSkills = [ ];
  removedSkillIds = [ "git-workflow" "lazygit" "ralph-loop" "unslop" ];
  # Ids the Claude harness already ships (e.g. anthropic-skills:notebooklm);
  # the local copy is hidden in Claude but stays visible to other agents.
  harnessProvidedSkillIds = [ "notebooklm" "impeccable" ];
  convexPluginProvidedSkillIds = [ "design" ];
  interfacesSkillNames = [
    "better-accessibility"
    "better-colors"
    "better-interface"
    "better-layout"
    "better-typography"
    "better-ui"
    "better-writing"
    "break"
    "build-design"
    "explain-interface"
    "interface-review"
    "state-machine"
    "variant"
  ];
}
