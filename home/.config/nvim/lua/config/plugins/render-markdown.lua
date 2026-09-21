return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown render" },
    },
    opts = {
      heading = {
        sign = false,
        width = "block",
      },
      code = {
        style = "full",
      },
      bullet = {
        icons = { "●", "○", "◆", "◇" },
      },
      checkbox = {
        enabled = true,
      },
      quote = {
        enabled = true,
      },
      pipe_table = {
        style = "full",
      },
      link = {
        enabled = true,
      },
      anti_conceal = {
        enabled = true,
      },
    },
  },
}
