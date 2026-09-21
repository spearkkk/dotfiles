return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 500
    end,
    opts = {
      delay = function(ctx)
        -- Do not pop up automatically when pressing plain "z".
        -- Use :WhichKey z when you want to inspect fold keys.
        if ctx.keys == "z" then
          return 1000000
        end

        return ctx.plugin and 0 or 200
      end,
      triggers = {
        { "<auto>", mode = "nxso" },
      },
      spec = {
        { "z", group = "folds" },
        { "za", desc = "Toggle fold" },
        { "zA", desc = "Toggle recursively" },
        { "zc", desc = "Close fold" },
        { "zC", desc = "Close recursively" },
        { "zo", desc = "Open fold" },
        { "zO", desc = "Open recursively" },
        { "zM", desc = "Close all folds" },
        { "zR", desc = "Open all folds" },
        { "zm", desc = "Fold more" },
        { "zr", desc = "Fold less" },
        { "zi", desc = "Toggle folding" },
      },
    },
  },
}
