local script_path = arg and arg[0] or debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*/)")
local config_dir = script_dir and script_dir:gsub("/tests/$", "") or "."

package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local audio = require("lib.audio_devices")

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected=%s actual=%s", label, tostring(expected), tostring(actual)))
  end
end

local list = audio.parse_list("MacBook Pro Speakers\nDELL U2720Q\nAirPods Pro\n")
assert_eq(#list, 3, "parse_list size")
assert_eq(list[1], "MacBook Pro Speakers", "parse_list[1]")

assert_eq(audio.icon_for_device("AirPods Pro"), audio.icons.headphones, "airpods icon")
assert_eq(audio.icon_for_device("DELL U2720Q HDMI"), audio.icons.display, "display icon")
assert_eq(audio.icon_for_device("MacBook Pro Speakers"), audio.icons.speaker, "speaker icon")
assert_eq(audio.icon_for_device("Unknown Device"), audio.icons.volume, "fallback icon")

print("ok: audio_devices_spec")
