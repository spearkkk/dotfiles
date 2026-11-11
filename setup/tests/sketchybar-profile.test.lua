local repo_root = assert(arg[1], "repo root required")
local expect_profile = arg[2] == "profile"

for _, name in ipairs({ "core.bar", "core.default", "items" }) do
  package.preload[name] = function() return true end
end

Sbar = {
  default = function(values) _G.__profile_icon_font = values["icon.font"] end,
  add = function() end,
}
package.preload["lib.settings"] = function() return { font = "SF Pro" } end
_G.__profile_loaded = false
local home = assert(os.getenv("HOME"))
package.path = home .. "/.config/sketchybar/?.lua;"
  .. home .. "/.config/sketchybar/?/init.lua;"
  .. repo_root .. "/home/.config/sketchybar/?.lua;" .. package.path

dofile(repo_root .. "/home/.config/sketchybar/init.lua")
assert(_G.__profile_loaded == expect_profile,
  expect_profile and "available profile was not loaded" or "missing profile must be ignored")

assert(not expect_profile or _G.__profile_icon_font == "SF Mono", "profile retains preexisting icon font")
