return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")

      local langs = {
        "lua",
        "vim",
        "vimdoc",
        "query",
        "bash",
        "fish",
        "json",
        "yaml",
        "toml",
        "markdown",
        "markdown_inline",
        "gitignore",
        "dockerfile",
        "groovy",
        "java",
        "scala",
        "python",
        "go",
        "rust",
        "javascript",
        "typescript",
        "tsx",
        "html",
        "css",
        "xml",
        "sql",
      }

      treesitter.install(langs)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = langs,
        callback = function()
          pcall(vim.treesitter.start)
          vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo.foldmethod = "expr"
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
