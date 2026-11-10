local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")

local ITEM = "front_app"
local MAX_CHARS = 28

local front_app = Sbar.add("item", ITEM, {
  position = "left",
  icon = {
    drawing = false,
  },
  label = {
    string = "",
    drawing = true,
    color = colors.foreground,
    align = "left",
    max_chars = MAX_CHARS,
    padding_left = 10,
    padding_right = 10,
    font = {
      style = "Italic",
      size = settings.label_size,
    },
  },
  background = {
    drawing = true,
    color = colors.background_alt,
    padding_left = 6,
    padding_right = 6,
    height = settings.defaults.bg_height + 4,
    corner_radius = settings.defaults.corner_radius,
    border_width = 3,
    border_color = utils.set_alpha(colors.base04, 90),
    y_offset = settings.defaults.bg_y_offset,
  },
  update_freq = 0,
  click_script = "open -a 'Mission Control'",
})

-- Sbar.event_loop() requests the initial app event, including after a reload.
front_app:subscribe("front_app_switched", function(env)
  front_app:set({ label = env.INFO or "" })
end)
