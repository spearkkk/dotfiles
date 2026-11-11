local root = "home/.config/sketchybar/"
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
local groups = {}
Sbar = { add = function(kind, name, members, options)
  assert(kind == "bracket")
  groups[name] = {members = members, options = options}
end }
local add_groups = require("items.right_groups")
local function check()
  assert(groups.right_utility == nil and groups.right_system == nil, "only weather and time have an underline")
  assert(table.concat(groups.right_clock.members, ",") == "weather_icon,timestamp_date,timestamp_time")
  for _, group in pairs(groups) do
    assert(group.options["background.drawing"] == true)
    assert(group.options["background.height"] == 2)
    assert(group.options["background.y_offset"] == -17)
    assert(group.options["background.padding_left"] == -3 and group.options["background.padding_right"] == -3)
    for _, member in ipairs(group.members) do assert(not member:match("^media"), "now playing stays unlined") end
  end
end
add_groups()
check()
groups = {}
add_groups({ right_utility_items = {"mosaic_monthly_icon"} })
check()
print("PASS: only weather, date and time have an underline")
