# Per-project LSP overrides

Drop one of these files at the **project root** to override the
user-global LSP config from `~/nix-config/modules/home/lsp.nix`.

Claude Code's config cascade (highest priority first):

1. `.lsp.json` / `lsp.json` at project root  ← **these templates**
2. `~/.claude/lsp.json`                      ← Nix-managed in `lsp.nix`
3. Enabled plugins from `claude-plugins-official`

Codex CLI honours `.codex/config.toml` at the project root with the
same `[lsp]` / `[lsp.servers.*]` schema.

## Modern TypeScript stack

The default stack uses Microsoft's TS 7 / `tsgo --lsp` for type
intelligence and `oxlint --lsp` for lint — both Rust/Go-native, both
10-30x faster than the legacy `tsserver`. Vite ecosystem is the
reference target (rolldown, Vue/Astro/Svelte SFCs, Tailwind).

| Template | Stack | When |
|---|---|---|
| [`ts-effect.lsp.json`](./ts-effect.lsp.json) | tsgo + oxlint | TypeScript + Effect-TS |
| [`vite-vue.lsp.json`](./vite-vue.lsp.json) | tsgo + vue-language-server + oxlint + tailwindcss | Vite + Vue 3 |
| [`vite-react.lsp.json`](./vite-react.lsp.json) | tsgo + oxlint + tailwindcss | Vite + React |
| [`tsserver-fallback.lsp.json`](./tsserver-fallback.lsp.json) | vtsls + oxlint | Legacy projects needing tsserver plugins |
| [`rust-nightly.lsp.json`](./rust-nightly.lsp.json) | rust-analyzer (nightly via devShell) | Rust |
| [`python-strict.lsp.json`](./python-strict.lsp.json) | basedpyright strict + ruff | Python |
| [`go-modules.lsp.json`](./go-modules.lsp.json) | gopls + workspace settings | Multi-module Go |
| [`devshell.flake.nix`](./devshell.flake.nix) | All of the above pinned | Per-project Nix devShell |
| [`neovim.lua`](./neovim.lua) | nvim-lspconfig | Neovim, same servers |
| [`mcp-bridge.json`](./mcp-bridge.json) | mcp-language-server | Claude Desktop / Codex App |

## Why tsgo + oxlint as default

| Concern | tsgo --lsp | oxlint --lsp | What it replaces |
|---|---|---|---|
| Type-checking, hover, definitions | ✅ | — | typescript-language-server (tsserver wrapper) |
| Lint diagnostics | — | ✅ | eslint-language-server |
| Vue/Astro/Svelte SFC type-checking | partial (delegate to vue-language-server) | ✅ lint only | volar / astro / svelte LSPs supplement |
| Plugins (`@effect/language-service`) | ✅ in interactive mode | n/a | tsserver |
| Startup time | ~10x faster | ~30x faster | both |
| Memory | ~3x less | ~5x less | both |

The two servers register the same filetypes and run in parallel —
Claude Code/Codex merges diagnostics from both. `oxlint` is marked
`isLinter: true` so hover/definitions only come from `tsgo`.

## Schema reminder

```jsonc
{
  "lspServers": {
    "<id>": {
      "command": "<binary>",                  // must be on PATH
      "args": ["..."],
      "extensionToLanguage": { ".ext": "lang-id" },
      "initializationOptions": { },           // passed to LSP initialize
      "settings": { },                         // didChangeConfiguration
      "isLinter": true,                        // diagnostics-only role
      "startupTimeout": 120000
    }
  }
}
```

Unsupported by the runtime (will reject init): `fileTypes`, `rootMarkers`,
`restartOnCrash`, `maxRestarts`. Use `extensionToLanguage` for filetype
binding.

## Disabling the official typescript-lsp plugin

The `typescript-lsp@claude-plugins-official` plugin registers a
`typescript` server-id pointing at `typescript-language-server`. With
tsgo as our primary, that plugin becomes redundant. To disable it:

```bash
jq '.enabledPlugins["typescript-lsp@claude-plugins-official"] = false' \
  ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

(Leaving it enabled is harmless — it just adds another LSP process per
.ts file with overlapping diagnostics.)
