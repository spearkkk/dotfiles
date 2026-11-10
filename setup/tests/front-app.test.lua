local repo_root = assert(os.getenv("REPO_ROOT"), "REPO_ROOT is required")

package.path = table.concat({
  repo_root .. "/home/.config/sketchybar/?.lua",
  repo_root .. "/home/.config/sketchybar/?/init.lua",
  package.path,
}, ";")

local latest_item
local capture_calls = 0

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
  capture = function()
    capture_calls = capture_calls + 1
    return '"LSDisplayName"="Ghostty"'
  end,
  set_alpha = function() return "0xff4a6e86" end,
}

Sbar = {
  add = function(_, _, options)
    local item = {
      values = { label = options.label.string },
      callbacks = {},
      set = function(self, values) self.values = values end,
      subscribe = function(self, events, callback)
        if type(events) == "string" then events = { events } end
        for _, event in ipairs(events) do self.callbacks[event] = callback end
      end,
    }
    latest_item = item
    return item
  end,
}

local failures = {}
local function check(condition, message)
  if not condition then failures[#failures + 1] = message end
end

dofile(repo_root .. "/home/.config/sketchybar/items/front_app.lua")
check(latest_item.values.label == "", "front app must start empty until SketchyBar supplies the app name")
check(capture_calls == 0, "front app initialization must not query an external command")

local function emit(event, info)
  local callback = latest_item.callbacks[event]
  if callback then callback({ SENDER = event, INFO = info }) end
end

check(type(latest_item.callbacks.front_app_switched) == "function", "front app must subscribe to SketchyBar app events")
emit("front_app_switched", "Ghostty")
check(latest_item.values.label == "Ghostty", "the first SketchyBar app event must populate the label")
emit("front_app_switched", "시스템 설정")
check(latest_item.values.label == "시스템 설정", "later app events must replace the label with the supplied name")

for _, event in ipairs({ "aerospace_workspace_change", "display_change", "system_woke", "forced" }) do
  check(latest_item.callbacks[event] == nil, "front app must not subscribe to " .. event)
  emit(event)
  check(latest_item.values.label == "시스템 설정", event .. " must not overwrite the app name")
end

for _, event in ipairs({ {}, { INFO = "" } }) do
  emit("front_app_switched", "Ghostty")
  emit("front_app_switched", event.INFO)
  check(latest_item.values.label == "", "missing or empty app names must clear the label without a fallback query")
end

check(capture_calls == 0, "front app events must not query an external command")
assert(#failures == 0, table.concat(failures, "\n"))

print("PASS: front-app")
