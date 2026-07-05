local colors   = require("helpers.colors")
local settings = require("helpers.settings")

Sbar.default({
  ["background.height"]        = settings.defaults.bg_height,
  ["background.y_offset"]      = settings.defaults.bg_y_offset,
  ["background.padding_left"]  = settings.defaults.padding_left,
  ["background.padding_right"] = settings.defaults.padding_right,
  ["background.corner_radius"] = settings.defaults.corner_radius,
  ["background.border_width"]  = settings.defaults.border_width,
  ["background.color"]         = colors.background_alt,
  ["label.color"]              = colors.foreground,
  ["icon.color"]               = colors.foreground,
  ["label.font"]               = settings.font,
  ["icon.font"]                = settings.font,
  ["label.font.size"]          = settings.label_size,
  ["icon.font.size"]           = settings.icon_size,
})
