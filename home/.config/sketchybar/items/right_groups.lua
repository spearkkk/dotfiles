local colors = require("lib.colors")

return function()
  -- The date overlaps the time and has negative right padding; using it as the
  -- rightmost member can collapse the bracket's calculated width.
  Sbar.add("bracket", "right_clock", { "pomodoro_break", "pomodoro_work", "timestamp_time" }, {
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
