return {
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<leader>z", "<cmd>ZenMode<cr>", desc = "Toggle Zen Mode" },
    },
    opts = {
      border = "rounded",
      zindex = 40,
      window = {
        backdrop = 0.8,
        width = 120,
        height = 1,
        options = {
          wrap = true,
          linebreak = true,
          number = true,
          relativenumber = true,
          cursorline = true,
          cursorcolumn = false,
          signcolumn = "yes",
          foldcolumn = "1",
          list = false,
        },
      },
      plugins = {
        options = { enabled = true, ruler = false, showcmd = false },
        twilight = { enabled = false },
        gitsigns = { enabled = false },
        tmux = { enabled = false },
        diagnostics = { enabled = false },
        todo = { enabled = false },
        kitty = { enabled = false },
        alacritty = { enabled = false },
        wezterm = { enabled = false },
        neovide = { enabled = false },
      },
    },
  },
}
