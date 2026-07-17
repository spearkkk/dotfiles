-- Tints every display that doesn't currently hold the focused window,
-- purely as a "you're not looking here" cue -- not meant to obscure content.
local DIM_COLOR = { hex = "#4A6E86", alpha = 0.45 } -- simhae-pelagic base04 (muted/slate)

local enabled = true
local overlays = {}

local function build_overlay(screen)
  local canvas = hs.canvas.new(screen:frame())
  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behavior({ "canJoinAllSpaces", "fullScreenAuxiliary" })
  canvas:appendElements({
    type = "rectangle",
    action = "fill",
    frame = { x = 0, y = 0, w = "100%", h = "100%" },
    fillColor = DIM_COLOR,
  })
  return canvas
end

local function overlay_for(screen)
  local id = screen:id()
  if not overlays[id] then
    overlays[id] = build_overlay(screen)
  end
  return overlays[id]
end

local function refresh_dimming(focused_screen)
  for _, screen in ipairs(hs.screen.allScreens()) do
    local canvas = overlay_for(screen)
    if not enabled or (focused_screen and screen:id() == focused_screen:id()) then
      canvas:hide()
    else
      canvas:show()
    end
  end
end

local function current_focused_screen()
  local win = hs.window.focusedWindow()
  return (win and win:screen()) or hs.screen.mainScreen()
end

hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(win)
  refresh_dimming(win and win:screen())
end)

-- Rebuild overlays when displays are connected/disconnected/reconfigured.
local screen_watcher = hs.screen.watcher.new(function()
  for _, canvas in pairs(overlays) do
    canvas:delete()
  end
  overlays = {}
  refresh_dimming(current_focused_screen())
end)
screen_watcher:start()

-- hammerspoon://dimset?state=on|off -- lets sketchybar (or anything else) toggle this explicitly.
hs.urlevent.bind("dimset", function(_, params)
  enabled = (params and params.state) ~= "off"
  refresh_dimming(current_focused_screen())
end)

refresh_dimming(current_focused_screen())
