# Remove the vendored Gemini CLI and all Gemini surfaces

Status: accepted

The `gemini-cli-preview` derivation (a fresh `buildNpmPackage` tracking the `@google/gemini-cli` `@preview` dist-tag) repeatedly broke `darwin-rebuild`: whenever the preview channel moved, its `fetchFromGitHub` source hash went stale and the fixed-output derivation failed, which wedged the *entire* system rebuild rather than just that one tool. We removed it in full — along with every other Gemini surface in the config (the Zed favorite model `gemini-3.1-pro-preview`, the `GEMINI_*`/`GOOGLE_API_KEY` env entries, the `⌃⌥⇧g` app-launcher hotkey, and the `gy` shell alias) — and deleted its updater so the nightly auto-update no longer tracks it.

## Considered options

- **Keep chasing hashes** — refresh `src` + `npmDepsHash` on every preview bump. Rejected: the preview channel moves fast and every stale hash blocks the whole rebuild.
- **Pin a stable tag, stop auto-updating** — keeps a working CLI but defeats the point of tracking `@preview`, and still rots over time.
- **Re-route through `bunx @google/gemini-cli`** — a runtime fetch that can never touch the build path. Viable, but the user chose to drop Gemini entirely rather than keep any surface.

## Consequences

- The global `~/.claude/CLAUDE.md` workflow (`gemini -y -p`) and the `/deep-research` skill that depend on a `gemini` binary no longer have one on this machine; those live outside this repo and must be adjusted there.
- `⌃⌥⇧g` is now an unbound hotkey, free for reuse.
- Gemini models are no longer reachable from Zed/agents (the API surface was removed too). Re-adding any Gemini surface is a deliberate new decision, not a regression fix — see CONTEXT.md "Flagged ambiguities".
