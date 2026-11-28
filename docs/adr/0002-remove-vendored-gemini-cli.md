# Remove the vendored Gemini CLI and all Gemini surfaces

Status: accepted

The vendored `gemini-cli-preview` derivation tracked the moving `@google/gemini-cli` `@preview` npm tag. Every upstream preview release invalidated its `fetchFromGitHub` hash and blocked `darwin-rebuild`. We removed the derivation, its nightly updater, and all Gemini configuration surfaces. Those surfaces covered the Zed favorite model, `GEMINI_*` and `GOOGLE_API_KEY` variables, `⌃⌥⇧g`, and `gy`.

## Considered options

- **Keep refreshing `src` and `npmDepsHash` on every preview bump.** Rejected: the preview channel moves too fast, and any stale hash blocks the rebuild.
- **Pin a static version and stop auto-updating.** Rejected: a frozen preview CLI drifts behind upstream API changes and still needs maintenance.
- **Run `@google/gemini-cli` at command time through `bunx`.** Rejected: keeps Gemini off the build path, but the operator dropped Gemini across the profile.
- **Remove all Gemini derivations and configuration surfaces (chosen).** Eliminates a recurring rebuild failure on an unused tool.

## Consequences and trade-offs

- External scripts outside this repo that call a `gemini` binary fail until updated.
- Zed and local CLI agents no longer receive Gemini API keys or model slots from this flake.
- **Reversal trigger:** If Gemini returns to daily use, expose it via API-only access or a command-time `bunx` wrapper off the rebuild path.
