local colors = require("helpers.colors")
local settings = require("helpers.settings")

Sbar.add("item", "settings", {
  position = "right",
  icon = "􀍟",
  ["icon.drawing"] = true,
  ["icon.color"] = colors.foreground,
  ["icon.font.size"] = settings.icon_size,
  ["icon.padding_left"] = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  click_script = [[open -a "System Settings" >/dev/null 2>&1; osascript -e 'tell application "System Settings" to activate' >/dev/null 2>&1]],
  label = {
    drawing = false,
  },
  background = {
    drawing = false,
  },
})
