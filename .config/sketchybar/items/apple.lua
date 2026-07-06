local colors = require("helpers.colors")
local settings = require("helpers.settings")

Sbar.add("item", "apple", {
  position = "left",
  icon = "􀣺",
  ["icon.drawing"] = true,
  ["icon.color"] = colors.base08,
  ["icon.font.size"] = settings.icon_size,
  ["icon.padding_left"] = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  label = {
    drawing = false,
  },
  background = {
    drawing = false,
  },
})
