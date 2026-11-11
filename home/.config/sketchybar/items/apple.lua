local icons = require("lib.icons")
local colors = require("lib.colors")
local settings = require("lib.settings")

Sbar.add("item", "apple", {
  position = "left",
  icon = icons.brand_apple,
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
