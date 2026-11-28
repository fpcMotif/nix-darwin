# The guide catalog owns every installed guide

Status: accepted

Previously, `claude.nix` linked Claude's guides without archiving existing files first, so a runtime edit to `~/.claude/CLAUDE.md` aborted `darwin-rebuild switch` at `checkLinkTargets`. Non-Claude guides deployed only on Darwin, and the test suite kept a duplicate list of extra guide files. We consolidated every agent host's guide definitions (startup, development, language, human-documents, and `extras`) into one guide catalog (`modules/home/agent-instructions/guides.nix`). That catalog generates each host's `## Guides` pointer lines, installs and archives every target across Darwin and Linux, and feeds `integration-configurations-eval`.

## Considered options

- **Keep non-Claude guides Darwin-only.** Rejected: guides are plain text files, Linux hosts can run Codex and OMP, and cross-platform installation lets Linux CI check the catalog.
- **Add a per-host `platforms` filter to the guide catalog.** Rejected: no host needs a platform restriction for text files, so the field adds unused complexity.
- **Let each harness module (`claude.nix`, `codex.nix`, `omp`) install its own guides.** Rejected: splitting installation across modules is how Claude's guides missed the pre-activation backup step.

## Consequences and trade-offs

- Every host installs all catalog guide files on Darwin and Linux, even when an agent binary (such as OMP) builds only on Darwin.
- Any new guide file linked from a startup guide must appear in `guides.nix`, or `integration-configurations-eval` fails the build.
- **Reversal trigger:** If a harness needs guide files built from Darwin-only derivations, gate that host entry in `guides.nix` rather than splitting installation across modules.
