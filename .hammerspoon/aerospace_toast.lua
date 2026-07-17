local AEROSPACE = "/opt/homebrew/bin/aerospace"

-- simhae-pelagic palette (.dotfiles/simhae/simhae-pelagic.yaml),
-- matched to sketchybar's front_app item styling (.config/sketchybar/items/front_app.lua)
local COLORS = {
  background = { hex = "#142C3E", alpha = 1 },    -- base01 / colors.background_alt
  border     = { hex = "#4A6E86", alpha = 0.90 }, -- base04 @ 90%, same as front_app's border_color
  icon       = { hex = "#C8AE6A", alpha = 1 },    -- base0A (accent/active)
  text       = { hex = "#C6D8E4", alpha = 1 },    -- base05 / colors.foreground
  empty      = { hex = "#4A6E86", alpha = 1 },    -- base04 (muted)
}
local BORDER_WIDTH = 5
local TITLE_MAX_CHARS = 28

local WORKSPACE_ICONS = {
  Q = "􀂴",
  W = "􀃀",
  E = "􀂜",
  R = "􀂶",
  ["`"] = "􀓔",
}

local TOAST_WIDTH = 300
local ICON_SIZE = 28
local ICON_AREA_HEIGHT = 56
local APP_TEXT_SIZE = 15
local LINE_HEIGHT = 26
local VERTICAL_PADDING = 28
local HORIZONTAL_PADDING = 20
local DISPLAY_SECONDS = 1.0
local FADE_IN_SECONDS = 0.2
local FADE_SECONDS = 0.3

local current_canvas = nil
local current_timer = nil

local function monitor_for_workspace(ws)
  local cmd = string.format("%s list-workspaces --all --format '%%{workspace}|%%{monitor-name}' 2>/dev/null", AEROSPACE)
  local output = hs.execute(cmd) or ""
  for line in output:gmatch("[^\r\n]+") do
    local w, monitor_name = line:match("^(.-)|(.*)$")
    if w == ws then
      return monitor_name
    end
  end
  return nil
end

local function truncate(str, max_chars)
  if #str <= max_chars then
    return str
  end
  return str:sub(1, max_chars - 1) .. "…"
end

-- One entry per window (not deduped by app), so an app with multiple
-- windows shows up multiple times, each with its own window title.
-- Pulls the monitor name from the same call (windows already know their
-- monitor), only falling back to a second aerospace call for empty workspaces.
local function workspace_windows_and_monitor(ws)
  local cmd = string.format(
    "%s list-windows --workspace '%s' --format '%%{app-name}|%%{window-title}|%%{monitor-name}' 2>/dev/null",
    AEROSPACE, ws
  )
  local output = hs.execute(cmd) or ""

  local windows = {}
  local monitor_name = nil
  for raw_line in output:gmatch("[^\r\n]+") do
    local app, title, mon = raw_line:match("^(.-)|(.-)|(.*)$")
    app = (app or ""):gsub("^%s+", ""):gsub("%s+$", "")
    title = (title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    mon = (mon or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if app ~= "" then
      windows[#windows + 1] = { app = app, title = title }
      monitor_name = monitor_name or mon
    end
  end

  return windows, monitor_name or monitor_for_workspace(ws)
end

local function dismiss_toast()
  if current_timer then
    current_timer:stop()
    current_timer = nil
  end
  if current_canvas then
    local dying = current_canvas
    current_canvas = nil
    dying:hide(FADE_SECONDS)
    hs.timer.doAfter(FADE_SECONDS, function()
      dying:delete()
    end)
  end
end

local function show_toast(ws)
  dismiss_toast()

  local icon = WORKSPACE_ICONS[ws] or ws
  local windows, monitor_name = workspace_windows_and_monitor(ws)
  local has_windows = #windows > 0

  local lines = {}
  if has_windows then
    for _, w in ipairs(windows) do
      local title = truncate(w.title, TITLE_MAX_CHARS)
      lines[#lines + 1] = (title ~= "" and (w.app .. " - " .. title)) or w.app
    end
  else
    lines = { "(empty)" }
  end

  local height = VERTICAL_PADDING * 2 + ICON_AREA_HEIGHT + (#lines * LINE_HEIGHT)
  local screen = (monitor_name and hs.screen.find(monitor_name)) or hs.screen.mainScreen()
  local screen_frame = screen:frame()
  local x = screen_frame.x + (screen_frame.w - TOAST_WIDTH) / 2
  local y = screen_frame.y + (screen_frame.h - height) / 2

  local canvas = hs.canvas.new({ x = x, y = y, w = TOAST_WIDTH, h = height })

  canvas:appendElements({
    type = "rectangle",
    action = "strokeAndFill",
    frame = { x = 0, y = 0, w = "100%", h = "100%" },
    fillColor = COLORS.background,
    strokeColor = COLORS.border,
    strokeWidth = BORDER_WIDTH,
  })

  canvas:appendElements({
    type = "text",
    text = icon,
    frame = { x = 0, y = VERTICAL_PADDING - 6, w = TOAST_WIDTH, h = ICON_AREA_HEIGHT },
    textSize = ICON_SIZE,
    textColor = COLORS.icon,
    textAlignment = "center",
  })

  local list_top = VERTICAL_PADDING + ICON_AREA_HEIGHT
  for i, line in ipairs(lines) do
    canvas:appendElements({
      type = "text",
      text = has_windows and ("-  " .. line) or line,
      frame = {
        x = HORIZONTAL_PADDING,
        y = list_top + (i - 1) * LINE_HEIGHT,
        w = TOAST_WIDTH - HORIZONTAL_PADDING * 2,
        h = LINE_HEIGHT,
      },
      textSize = APP_TEXT_SIZE,
      textColor = has_windows and COLORS.text or COLORS.empty,
      textAlignment = "left",
    })
  end

  canvas:show(FADE_IN_SECONDS)
  current_canvas = canvas
  current_timer = hs.timer.doAfter(DISPLAY_SECONDS, dismiss_toast)
end

-- Fast path: called directly over hs.ipc's socket (`hs -c`) from
-- exec-on-workspace-change, skipping the open(1)/LaunchServices round trip
-- that hammerspoon:// URLs go through.
function AerospaceWorkspaceChanged(ws)
  show_toast(ws)
end

-- Kept as a fallback entry point.
hs.urlevent.bind("workspacechanged", function(_, params)
  local ws = (params and params.workspace) or ""
  show_toast(ws)
end)
