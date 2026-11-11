local colors = require("lib.colors")

return function()
  Sbar.add("bracket", "right_clock", { "weather_icon", "timestamp_date", "timestamp_time" }, {
    ["background.drawing"] = true,
    ["background.color"] = colors.base04,
    ["background.height"] = 2,
    ["background.y_offset"] = -17,
    ["background.corner_radius"] = 1,
    ["background.border_width"] = 0,
    ["background.padding_left"] = -3,
    ["background.padding_right"] = -3,
  })
end
