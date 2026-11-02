return {
  {
    "keaising/im-select.nvim",
    lazy = false,
    opts = {
      default_im_select = "com.apple.keylayout.ABC",
      default_command = "/opt/homebrew/bin/im-select",
      set_default_events = {
        "VimEnter",
        "FocusGained",
        "InsertLeave",
        "CmdlineEnter",
        "CmdlineLeave",
      },
      set_previous_events = {},
      keep_quiet_on_no_binary = false,
      async_switch_im = true,
    },
  },
}
