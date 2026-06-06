// The Skill-read seam: how skill-router loads a resolved skill's body (the
// loadSkill / loadIntentSkill path). Scoped to skill-body reads — directory
// discovery still walks the real filesystem. See CONTEXT.md "Skill-read seam".
export type ReadText = (path: string) => Promise<string | null>;

// Production adapter. Returns null for a missing/unreadable path so callers'
// existence checks collapse into one read.
export const bunReadText: ReadText = async (path) => {
  const file = Bun.file(path);
  if (!(await file.exists())) return null;
  return file.text();
};
