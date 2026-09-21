return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = {
        preset = "default",
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        documentation = {
          auto_show = false,
        },
      },
      sources = {
        default = { "lsp", "path", "buffer" },
      },
      signature = {
        enabled = true,
        trigger = {
          show_on_accept = true,
          show_on_accept_on_trigger_character = true,
        },
        window = {
          border = "rounded",
        },
      },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
        use_proximity = true,
      },
    },
  },
}
