-- Neovim Layer F: zero Nix changes needed.
-- All binaries are already on $PATH from ~/nix-config/modules/home/lsp.nix.
-- Drop this in ~/.config/nvim/lua/plugins/lsp.lua (lazy.nvim) or merge
-- into your existing nvim-lspconfig setup.
--
-- Stack: TS 7 / tsgo --lsp + oxlint --lsp + Vite framework servers.

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig = require("lspconfig")
      local configs = require("lspconfig.configs")

      -- tsgo is not in nvim-lspconfig yet; register manually.
      if not configs.tsgo then
        configs.tsgo = {
          default_config = {
            cmd = { "tsgo", "--lsp", "--stdio" },
            filetypes = {
              "typescript", "typescriptreact", "typescript.tsx",
              "javascript", "javascriptreact", "javascript.jsx",
            },
            root_dir = lspconfig.util.root_pattern("tsconfig.json", "package.json", ".git"),
            init_options = {
              preferences = {
                includeInlayParameterNameHints = "all",
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayVariableTypeHints = true,
                importModuleSpecifierPreference = "non-relative",
              },
            },
          },
        }
      end
      lspconfig.tsgo.setup({})

      -- oxlint --lsp as second LSP for diagnostics.
      lspconfig.oxlint.setup({})        -- shipped in nvim-lspconfig

      -- Vite framework SFCs.
      lspconfig.volar.setup({})         -- vue-language-server (.vue)
      lspconfig.astro.setup({})         -- astro-language-server (.astro)
      lspconfig.svelte.setup({})        -- svelteserver (.svelte)
      lspconfig.tailwindcss.setup({})   -- tailwind utility-class intellisense
      lspconfig.emmet_language_server.setup({})

      -- Go.
      lspconfig.gopls.setup({
        settings = {
          gopls = {
            staticcheck = true,
            gofumpt = true,
            hints = { parameterNames = true, rangeVariableTypes = true },
          },
        },
      })

      -- Rust.
      lspconfig.rust_analyzer.setup({
        settings = {
          ["rust-analyzer"] = {
            cargo = { features = "all" },
            check = { command = "clippy" },
            procMacro = { enable = true },
          },
        },
      })

      -- Python.
      lspconfig.basedpyright.setup({
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "strict",
              diagnosticMode = "workspace",
              inlayHints = { variableTypes = true, callArgumentNames = true },
            },
          },
        },
      })
      lspconfig.ruff.setup({})

      -- Lua.
      lspconfig.lua_ls.setup({
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })
    end,
  },

  -- Optional: nvim-vtsls for the rare project that still needs tsserver
  -- plugins. Activate per-project via :LspStart vtsls.
  {
    "yioneko/nvim-vtsls",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    opts = {},
  },
}
