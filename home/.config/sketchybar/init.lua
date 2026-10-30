require("core.bar")
require("core.default")
require("items")

-- Profile overlays may add work- or machine-specific items without replacing
-- the common registry. GNU Stow removes this file with the active profile, so
-- absence is the normal state and an existing profile must still fail loudly.
local home = os.getenv("HOME") or ""
local profile_init = home .. "/.config/sketchybar/profile/init.lua"
local profile_file = io.open(profile_init, "r")
if profile_file then
  profile_file:close()
  require("profile")
end
