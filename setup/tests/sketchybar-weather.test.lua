local root = assert(arg[1])
package.path = root .. "/home/.config/sketchybar/?.lua;" .. package.path

local colors = {
  foreground = "foreground", base04 = "muted", base08 = "hot-day",
  base0a = "day", base0e = "hot-night", base0c = "cold-night", base0d = "night",
}
package.loaded["lib.colors"] = colors
package.loaded["lib.settings"] = {
  double_line_bottom_y = 0, double_line_top_y = 0,
  text_size_small = 12, text_size_large = 16,
}
-- Real lib.utils, real shell execution and the real Bash helper are exercised.
-- Only the SketchyBar UI/async boundary and external HTTP responses are replaced.
local popen = io.popen
io.popen = function() error("weather must not block Lua with io.popen") end
local jobs = {}
local scheduling_failed = false
local items = {}
Sbar = { exec = function(command, callback)
  if scheduling_failed then error("fixture scheduling failure") end
  jobs[#jobs + 1] = { command = command, callback = callback }
end, add = function(_, name, options)
  local item = { options = options, values = {}, callbacks = {} }
  function item:set(values)
    for key, value in pairs(values) do self.values[key] = value end
  end
  function item:subscribe(events, callback)
    for _, event in ipairs(events) do self.callbacks[event] = callback end
  end
  items[name] = item
  return item
end }

-- The real helper is run only when the test explicitly delivers completion.
local function complete()
  assert(#jobs == 1, "exactly one weather request may be in flight")
  local job = table.remove(jobs, 1)
  local pipe = assert(popen(job.command))
  local output = pipe:read("*a")
  local ok, _, code = pipe:close()
  job.callback(output, ok and 0 or code)
end

local function write(path, text)
  local f = assert(io.open(path, "w"))
  f:write(text)
  f:close()
end

dofile(root .. "/home/.config/sketchybar/items/weather.lua")
local icon, temp = items.weather_icon, items.weather_temp
assert(icon.options.update_freq == 1800, "retain the 30 minute refresh interval")
assert(temp.values.label == "--°", "show placeholder while startup fetch is pending")
for _, event in ipairs({ "routine", "forced", "system_woke", "wifi_change" }) do
  assert(icon.callbacks[event], "subscribe before startup request finishes: " .. event)
  icon.callbacks[event]()
end
assert(#jobs == 1, "startup and simultaneous events must not overlap requests")
complete()
assert(temp.values.label == "18°", "render startup weather")
assert(icon.values.icon == "􀇃" and icon.values["icon.color"] == colors.base0a)

local cases = {
  { 0, 28, 1, "28°", "􀆮", colors.base08 },
  { 61, 25, 0, "25°", "􀇝", colors.base0e },
  { 71, -3.6, 0, "-4°", "􀇏", colors.base0c },
  { 0, 0, 0, "0°", "􀇁", colors.base0d },
  { 999, 18.5, 1, "19°", "􀇃", colors.base0a },
}
for _, case in ipairs(cases) do
  write(os.getenv("WEATHER_FILE"), string.format(
    '{"current":{"weather_code":%s,"temperature_2m":%s,"is_day":%s}}', case[1], case[2], case[3]))
  local previous_label, previous_label_color = temp.values.label, temp.values["label.color"]
  local previous_icon, previous_icon_color = icon.values.icon, icon.values["icon.color"]
  local function assert_display_unchanged()
    assert(temp.values.label == previous_label, "keep current display until completion")
    assert(temp.values["label.color"] == previous_label_color, "keep temperature color while pending")
    assert(icon.values.icon == previous_icon, "keep weather icon while pending")
    assert(icon.values["icon.color"] == previous_icon_color, "keep weather icon color while pending")
  end
  icon.callbacks.routine()
  assert_display_unchanged()
  for _, event in ipairs({ "forced", "system_woke", "wifi_change" }) do
    icon.callbacks[event]()
  end
  assert(#jobs == 1, "coalesce events while a request is in flight")
  assert_display_unchanged()
  complete()
  assert(temp.values.label == case[4], "retain temperature rounding")
  assert(icon.values.icon == case[5], "retain day/night weather icons")
  assert(icon.values["icon.color"] == case[6], "retain temperature colors")
  assert(temp.values["label.color"] == colors.foreground)
end

local function assert_fallback()
  assert(temp.values.label == "--°", "failed fetch must show --°")
  assert(temp.values["label.color"] == colors.base04)
  assert(icon.values.icon == "􀇃" and icon.values["icon.color"] == colors.base04)
end
write(os.getenv("WEATHER_FILE"), '{}')
icon.callbacks.forced()
complete()
assert_fallback()
write(os.getenv("WEATHER_FILE"), '{"current":{"weather_code":0,"temperature_2m":20,"is_day":1}}')
for _, event in ipairs({ "routine", "forced", "system_woke", "wifi_change" }) do
  assert(icon.callbacks[event], "retain event subscription: " .. event)
  icon.callbacks[event]()
  complete()
  assert(temp.values.label == "20°", "recover after failed fetch")
end

-- Even valid-looking partial output from a failed child must be rejected.
icon.callbacks.forced()
local failed = table.remove(jobs, 1)
failed.callback("0\t99\t1\n", 28)
assert_fallback()
icon.callbacks.routine()
complete()
assert(temp.values.label == "20°", "timeout completion must release the in-flight guard")

for _, output in ipairs({ {}, false, 3 }) do
  icon.callbacks.forced()
  table.remove(jobs, 1).callback(output, 0)
  assert_fallback()
end

scheduling_failed = true
icon.callbacks.forced()
assert_fallback()
assert(#jobs == 0, "failed scheduling must not leave a queued job")
scheduling_failed = false
icon.callbacks.forced()
complete()
assert(temp.values.label == "20°", "recover after failed scheduling")

-- Remove only the test-home symlink: a valid curl response must not bypass
-- the private entry point by running the old inline curl pipeline.
local helper = os.getenv("HOME") .. "/.local/libexec/sketchybar-fetch-weather"
assert(os.remove(helper))
icon.callbacks.forced()
complete()
assert_fallback()

-- A malformed helper response must also fall back rather than break the UI.
for _, response in ipairs({
  "3\tinvalid\t1", "3\t1e999\t1", "3\t18.4\t2", "3\t18.4",
  "3\t18.4\t1\nextra", "3\t18.4\t1\tunexpected",
}) do
  local utils = require("lib.utils")
  write(helper, "#!/bin/sh\nprintf '%s\\n' " .. utils.shell_quote(response) .. "\n")
  assert(os.execute("chmod +x " .. utils.shell_quote(helper)))
  icon.callbacks.forced()
  complete()
  assert_fallback()
end
print("PASS: weather async dispatch, duplicate suppression, rendering and failure recovery")
