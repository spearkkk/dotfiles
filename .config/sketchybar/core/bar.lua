local colors   = require("helpers.colors")
local settings = require("helpers.settings")

Sbar.bar({
  position      = "top",
  height        = settings.bar.height,
  margin        = settings.bar.margin,
  y_offset      = settings.bar.y_offset,
  corner_radius = settings.bar.corner_radius,
  border_width  = settings.bar.border_width,
  blur_radius   = settings.bar.blur_radius,
  padding_left  = settings.bar.padding_left,
  padding_right = settings.bar.padding_right,
  color         = colors.background,
  border_color  = colors.bar_border,
})
