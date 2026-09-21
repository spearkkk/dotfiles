return {
  "nvim-lualine/lualine.nvim",
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status") -- show pending plugin updates
    local simhae = require("config.theme.simhae")
    local my_lualine_theme = simhae.lualine_theme()

    lualine.setup({
      options = {
        theme = my_lualine_theme,
        icons_enabled = false,
      },
      sections = {
        lualine_x = {
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = "#C8945A" },
          },
          { "encoding" },
          { "fileformat" },
          { "filetype" },
        },
      },
    })
  end,
}
