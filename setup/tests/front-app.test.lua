local repo_root = assert(os.getenv("REPO_ROOT"), "REPO_ROOT is required")

package.path = table.concat({
  repo_root .. "/home/.config/sketchybar/?.lua",
  repo_root .. "/home/.config/sketchybar/?/init.lua",
  package.path,
}, ";")

local front_info = ""
local latest_item

package.loaded["lib.colors"] = {
  foreground = "0xffc6d8e4",
  background_alt = "0xff142c3e",
  base04 = "0xff4a6e86",
}
package.loaded["lib.settings"] = {
  label_size = 13,
  defaults = { bg_height = 26, corner_radius = 4, bg_y_offset = 0 },
}
package.loaded["lib.utils"] = {
  capture = function() return front_info end,
  set_alpha = function() return "0xff4a6e86" end,
}

Sbar = {
  add = function(_, _, _)
    local item = {
      set = function(self, values) self.values = values end,
      subscribe = function() end,
    }
    latest_item = item
    return item
  end,
}

local function load_front_app(info)
  front_info = info
  latest_item = nil
  dofile(repo_root .. "/home/.config/sketchybar/items/front_app.lua")
  return latest_item.values.label
end

assert(
  load_front_app('"Ghostty" ASN:0x0-0x8d08d:\n    bundleID=[ NULL ]\n') == "Ghostty",
  "front app fallback must extract the quoted application name from lsappinfo output"
)

assert(
  load_front_app("bundleID=[ NULL ]\n bundle path=[ NULL ]") == "",
  "front app fallback must clear the label when lsappinfo has no application name"
)

print("PASS: front-app")
