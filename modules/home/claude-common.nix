# Shared constants for Claude skill selection and cleanup.
# Keep target dirs and disabled skill IDs in one place so the declarative
# agent-skills bundle and Claude runtime cleanup stay in lockstep.
{
  skillTargetDirs = {
    agents = ".agents/skills";
    claude = ".claude/skills";
    cursor = ".cursor/skills";
    codex = ".codex/skills";
    pi = ".pi/agent/skills";
  };

  disabledMattpocockSkills = [ "grill-me" ];

  transformedMattpocockSkills = [
    "grill-with-docs"
    "improve-codebase-architecture"
  ];
}
