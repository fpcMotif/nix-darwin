---
name: clean
description: >-
  Polish your own diff when asked to clean up code or before a PR handoff.
---

# Clean

Polish the current diff while preserving its intended behavior and scope.
Prefer clear code and neighboring conventions over clever shorthand.

1. Read the current diff and enough surrounding code to judge each cleanup.
2. Remove dead code, temporary logging, and duplication introduced by the change.
3. Reuse existing helpers where they fit. Keep unrelated refactors outside this pass.
4. Inspect the resulting diff. Run required checks and any checks needed for changed behavior.

For UI code, preserve the agreed visual design while polishing its implementation.
For a PR handoff, describe the resulting change and relevant verification in the title and body.
Commit, push, and merge only within the user's authorization.

The pass is complete when each changed hunk has been inspected and any cleanup risks are resolved or reported.
