return {
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonUninstall" },
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()

      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              checkThirdParty = false,
              library = {
                vim.env.VIMRUNTIME,
              },
            },
          },
        },
      })

      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "bashls",
          "gopls",
          "rust_analyzer",
          "ts_ls",
          "jsonls",
          "yamlls",
          "dockerls",
          "lemminx",
          "jdtls",
        },
        automatic_enable = {
          exclude = { "jdtls" },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local opts = { buffer = event.buf }
          local telescope = require("telescope.builtin")

          vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "LSP hover" }))
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
          vim.keymap.set("n", "gr", telescope.lsp_references, vim.tbl_extend("force", opts, { desc = "Go to references" }))
          vim.keymap.set("n", "gI", telescope.lsp_implementations, vim.tbl_extend("force", opts, { desc = "Go to implementation" }))
          vim.keymap.set("n", "gy", telescope.lsp_type_definitions, vim.tbl_extend("force", opts, { desc = "Go to type definition" }))
          vim.keymap.set("n", "<leader>fd", function()
            telescope.diagnostics({ bufnr = 0 })
          end, vim.tbl_extend("force", opts, { desc = "Buffer diagnostics" }))
          vim.keymap.set("n", "<leader>fD", telescope.diagnostics, vim.tbl_extend("force", opts, { desc = "Workspace diagnostics" }))
          vim.keymap.set("n", "<leader>fs", telescope.lsp_document_symbols, vim.tbl_extend("force", opts, { desc = "Document symbols" }))
          vim.keymap.set("n", "<leader>fS", telescope.lsp_dynamic_workspace_symbols, vim.tbl_extend("force", opts, { desc = "Workspace symbols" }))
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol" }))
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
        end,
      })
    end,
  },
}
