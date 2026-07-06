return {
  "nvim-lua/plenary.nvim", -- lua functions that many plugins use
  "christoomey/vim-tmux-navigator", -- tmux & split window navigation
  {
    "simhae/local-colorscheme",
    dir = "~/.config/nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.simhae_variant = "pelagic" -- trench | hadal | pelagic | benthic
      vim.g.simhae_background = "medium" -- hard | medium | soft
      vim.g.simhae_foreground = "material" -- material | mix | original
      vim.g.simhae_transparent = 0
      vim.g.simhae_enable_italic = 1
      vim.g.simhae_disable_italic_comment = 0
      vim.g.simhae_enable_bold = 1
      vim.g.simhae_diagnostic_text_highlight = 0
      vim.cmd.colorscheme("simhae")
    end,
  },
}
