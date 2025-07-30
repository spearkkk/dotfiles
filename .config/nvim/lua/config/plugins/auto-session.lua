return {
  "rmagatti/auto-session",
  config = function()
    local auto_session = require("auto-session")

    auto_session.setup({
      auto_restore_enabled = false,
      auto_session_suppress_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" },
      pre_save_cmds = {
        function()
          local cwd = vim.fn.getcwd()
          if cwd:match("^" .. vim.fn.expand("~/Projects")) then
            vim.b.auto_session_enabled = true
          else
            vim.b.auto_session_enabled = false
          end
        end
      },

      pre_restore_cmds = {
        function()
          local cwd = vim.fn.getcwd()
          if cwd:match("^" .. vim.fn.expand("~/Projects")) then
            require("auto-session").AutoRestoreSession()
          end
        end
      },
    })

    local keymap = vim.keymap

    keymap.set("n", "<leader>wr", "<cmd>SessionRestore<CR>", { desc = "Restore session for cwd" }) -- restore last workspace session for current directory
    keymap.set("n", "<leader>ws", "<cmd>SessionSave<CR>", { desc = "Save session for auto session root dir" }) -- save workspace session for current working directory
  end,
}
