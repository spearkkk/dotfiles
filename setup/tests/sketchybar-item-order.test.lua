local loaded = {}
local names = {
  "apple", "front_app", "aerospace", "todays", "timestamp", "pomodoro",
  "input_source", "cafe", "dim_toggle", "settings", "wifi",
  "sound_output", "media",
}
for _, name in ipairs(names) do
  package.preload["items." .. name] = function() loaded[#loaded + 1] = name end
end
dofile("home/.config/sketchybar/items/init.lua")
local index = {}
for i, name in ipairs(loaded) do index[name] = i end
-- Right-side items appear in reverse insertion order.
local right_to_left = {
  "timestamp", "pomodoro", "settings", "sound_output", "wifi",
  "input_source", "dim_toggle", "cafe", "media",
}
for i = 2, #right_to_left do
  local first, second = right_to_left[i - 1], right_to_left[i]
  assert(index[first] < index[second], first .. " must be to the right of " .. second)
end
print("PASS: right-side groups follow the requested order")
