local primary = { id = function() return 1 end, frame = function() return {} end }
local secondary = { id = function() return 2 end, frame = function() return {} end }
local focused_screen = primary
local mouse_screen = primary
local canvases = {}
local periodic_callback

package.preload["lib.theme"] = function()
  return { inactive_display_dim = { overlay = {} } }
end

local function new_canvas()
  local canvas = { visible = false }
  function canvas:level() return self end
  function canvas:behavior() return self end
  function canvas:appendElements() return self end
  function canvas:show() self.visible = true return self end
  function canvas:hide() self.visible = false return self end
  function canvas:delete() return self end
  return canvas
end

hs = {
  canvas = {
    windowLevels = { overlay = 1 },
    new = function()
      local canvas = new_canvas()
      table.insert(canvases, canvas)
      return canvas
    end,
  },
  mouse = { getCurrentScreen = function() return mouse_screen end },
  screen = {
    allScreens = function() return { primary, secondary } end,
    mainScreen = function() return primary end,
    watcher = { new = function() return { start = function() end } end },
  },
  timer = {
    doAfter = function(_, callback) callback() end,
    doEvery = function(_, callback)
      periodic_callback = callback
      return { stop = function() end }
    end,
  },
  urlevent = { bind = function() end },
  window = {
    focusedWindow = function()
      if not focused_screen then return nil end
      return { screen = function() return focused_screen end }
    end,
    filter = {
      windowFocused = "windowFocused",
      default = { subscribe = function() end },
    },
  },
}

local module = dofile("home/.hammerspoon/modules/inactive_display_dim.lua")

assert(periodic_callback, "focus state must be reconciled when macOS emits no windowFocused event")
assert(type(module) == "table", "module must retain its long-lived Hammerspoon objects")
assert(module.focus_reconciler, "module must retain the focus reconciliation timer")
assert(module.screen_watcher, "module must retain the screen watcher")

focused_screen = secondary
periodic_callback()
assert(canvases[1].visible, "the old focused display should become dimmed")
assert(not canvases[2].visible, "the newly focused display should be undimmed")

focused_screen = nil
mouse_screen = primary
periodic_callback()
assert(not canvases[1].visible, "mouse display should be undimmed when no standard window is focused")
assert(canvases[2].visible, "the display away from the mouse should be dimmed")

print("inactive-display-dim tests passed")
