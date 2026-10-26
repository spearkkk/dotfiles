local tooling = require("config.tooling")

return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({
            async = true,
            lsp_format = "fallback",
          })
        end,
        desc = "Format file",
      },
    },
    opts = {
      formatters_by_ft = tooling.formatters_by_ft,
      notify_on_error = true,
    },
  },
}
