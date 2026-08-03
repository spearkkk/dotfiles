local AEROSPACE = "/opt/homebrew/bin/aerospace"

local M = {}

local COLORS = {
  background = { hex = "#142C3E", alpha = 1 },
  border     = { hex = "#4A6E86", alpha = 0.90 },
  icon       = { hex = "#C8AE6A", alpha = 1 },
  text       = { hex = "#C6D8E4", alpha = 1 },
  empty      = { hex = "#4A6E86", alpha = 1 },
  selected   = { hex = "#C8AE6A", alpha = 0.22 },
}

local WORKSPACE_ICONS = {
  Q = "􀂴",
  W = "􀃀",
  E = "􀂜",
  R = "􀂶",
  ["`"] = "􀓔",
}

local WORKSPACE_ORDER = { "Q", "W", "E", "R", "`" }

local ICON_SIZE = 28
local ICON_AREA_HEIGHT = 56
local ROW_HEIGHT = 26
local VERTICAL_PADDING = 28
local HORIZONTAL_PADDING = 20
local BORDER_WIDTH = 5
local TITLE_MAX_CHARS = 28
local WINDOW_TEXT_SIZE = 15
local WINDOW_TEXT_FRAME_EXTRA = 6
local WINDOW_TEXT_BASELINE_OFFSET = 1
local WORKSPACE_ROW_HEIGHT = 42
local WORKSPACE_ITEM_WIDTH = 52
local WORKSPACE_VERTICAL_PADDING = 18
local WORKSPACE_TEXT_SIZE = 22
local WORKSPACE_SELECTED_TEXT_SIZE = 30
local WORKSPACE_TEXT_FRAME_EXTRA = 8
local WORKSPACE_TEXT_BASELINE_OFFSET = 1
local SWITCHER_WIDTH_RATIO = 0.24
local SWITCHER_MIN_WIDTH = 300
local SWITCHER_MAX_WIDTH = 420
local WINDOW_HEIGHT_RATIO = 0.30
local WINDOW_MIN_ROWS = 4
local WINDOW_MAX_ROWS = 10
local WORKSPACE_HEIGHT_RATIO = 0.09
local WORKSPACE_MIN_HEIGHT = 78
local WORKSPACE_MAX_HEIGHT = 96

local active = false
local mode = nil
local current_workspace = ""
local windows = {}
local workspaces = {}
local selected_index = 1
local current_canvas = nil

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", [['"'"']]) .. "'"
end

local function run(cmd)
  return hs.execute(cmd .. " 2>/dev/null") or ""
end

local function truncate(str, max_chars)
  str = tostring(str or "")
  if #str <= max_chars then
    return str
  end
  return str:sub(1, max_chars - 1) .. "…"
end

local function focused_workspace()
  return trim(run(AEROSPACE .. " list-workspaces --focused | head -n1"))
end

local function all_workspaces()
  local output = run(AEROSPACE .. " list-workspaces --all")
  local seen = {}
  for line in output:gmatch("[^\r\n]+") do
    local ws = trim(line)
    if ws ~= "" then
      seen[ws] = true
    end
  end

  local result = {}
  for _, ws in ipairs(WORKSPACE_ORDER) do
    if seen[ws] then
      result[#result + 1] = ws
      seen[ws] = nil
    end
  end
  for ws in pairs(seen) do
    result[#result + 1] = ws
  end
  return result
end

local function focused_screen()
  local win = hs.window.focusedWindow()
  if win and win:screen() then
    return win:screen()
  end
  return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

local function focused_window_id()
  return trim(run(AEROSPACE .. " list-windows --focused --format '%{window-id}'"))
end

local function workspace_windows(ws)
  local output = run(string.format(
    "%s list-windows --workspace %s --format '%%{window-id}|%%{app-name}|%%{window-title}'",
    AEROSPACE,
    shell_quote(ws)
  ))

  local result = {}
  for line in output:gmatch("[^\r\n]+") do
    local id, app, title = line:match("^(.-)|(.-)|(.*)$")
    id = trim(id)
    app = trim(app)
    title = trim(title)
    if id ~= "" and app ~= "" then
      result[#result + 1] = {
        id = id,
        app = app,
        title = title,
      }
    end
  end
  return result
end

local function index_from_focused(items, step)
  local focused_id = focused_window_id()
  if focused_id == "" or #items == 0 then
    return 1
  end

  for i, item in ipairs(items) do
    if item.id == focused_id then
      return ((i - 1 + step) % #items) + 1
    end
  end
  return 1
end

local function dismiss_overlay()
  if current_canvas then
    current_canvas:delete()
    current_canvas = nil
  end
end

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

local function switcher_layout()
  local screen_frame = focused_screen():frame()
  local width = clamp(screen_frame.w * SWITCHER_WIDTH_RATIO, SWITCHER_MIN_WIDTH, SWITCHER_MAX_WIDTH)
  local window_min_height = VERTICAL_PADDING * 2 + ICON_AREA_HEIGHT + ROW_HEIGHT * WINDOW_MIN_ROWS
  local window_max_height = VERTICAL_PADDING * 2 + ICON_AREA_HEIGHT + ROW_HEIGHT * WINDOW_MAX_ROWS
  local window_height = clamp(screen_frame.h * WINDOW_HEIGHT_RATIO, window_min_height, window_max_height)
  local workspace_height = clamp(screen_frame.h * WORKSPACE_HEIGHT_RATIO, WORKSPACE_MIN_HEIGHT, WORKSPACE_MAX_HEIGHT)

  return {
    screen_frame = screen_frame,
    width = math.floor(width),
    window_height = math.floor(window_height),
    workspace_height = math.floor(workspace_height),
  }
end

local function visible_range(row_capacity)
  local count = math.min(#windows, row_capacity)
  local first = selected_index - math.floor(count / 2)
  if first < 1 then
    first = 1
  end
  if first + count - 1 > #windows then
    first = math.max(1, #windows - count + 1)
  end
  return first, count
end

local function base_canvas(layout, height)
  dismiss_overlay()
  local screen_frame = layout.screen_frame
  local frame = {
    x = screen_frame.x + (screen_frame.w - layout.width) / 2,
    y = screen_frame.y + (screen_frame.h - height) / 2,
    w = layout.width,
    h = height,
  }

  local canvas = hs.canvas.new(frame)
  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behavior({ "canJoinAllSpaces", "fullScreenAuxiliary" })
  canvas:appendElements({
    type = "rectangle",
    action = "strokeAndFill",
    frame = { x = 0, y = 0, w = "100%", h = "100%" },
    fillColor = COLORS.background,
    strokeColor = COLORS.border,
    strokeWidth = BORDER_WIDTH,
  })

  return canvas
end

local function append_workspace_header(canvas, width)
  canvas:appendElements({
    type = "text",
    text = WORKSPACE_ICONS[current_workspace] or current_workspace,
    frame = { x = 0, y = VERTICAL_PADDING - 6, w = width, h = ICON_AREA_HEIGHT },
    textSize = ICON_SIZE,
    textColor = COLORS.icon,
    textAlignment = "center",
  })
end

local function render_window_overlay()
  if #windows == 0 then
    dismiss_overlay()
    return
  end

  local layout = switcher_layout()
  local list_capacity = math.max(1, math.floor((layout.window_height - VERTICAL_PADDING * 2 - ICON_AREA_HEIGHT) / ROW_HEIGHT))
  local first, count = visible_range(list_capacity)
  local canvas = base_canvas(layout, layout.window_height)
  append_workspace_header(canvas, layout.width)

  local list_top = VERTICAL_PADDING + ICON_AREA_HEIGHT
  for row = 1, count do
    local index = first + row - 1
    local item = windows[index]
    local y = list_top + (row - 1) * ROW_HEIGHT
    local selected = index == selected_index
    local title = truncate(item.title, TITLE_MAX_CHARS)
    local line = (title ~= "" and (item.app .. " - " .. title)) or item.app
    local text_height = WINDOW_TEXT_SIZE + WINDOW_TEXT_FRAME_EXTRA
    local text_y = y + (ROW_HEIGHT - text_height) / 2 + WINDOW_TEXT_BASELINE_OFFSET

    if selected then
      canvas:appendElements({
        type = "rectangle",
        action = "fill",
        frame = {
          x = HORIZONTAL_PADDING - 8,
          y = y,
          w = layout.width - HORIZONTAL_PADDING * 2 + 16,
          h = ROW_HEIGHT,
        },
        fillColor = COLORS.selected,
      })
    end

    canvas:appendElements({
      type = "text",
      text = "-  " .. line,
      frame = {
        x = HORIZONTAL_PADDING,
        y = text_y,
        w = layout.width - HORIZONTAL_PADDING * 2,
        h = text_height,
      },
      textSize = WINDOW_TEXT_SIZE,
      textColor = selected and COLORS.text or COLORS.empty,
      textAlignment = "left",
    })
  end

  canvas:show()
  current_canvas = canvas
end

local function render_workspace_overlay()
  if #workspaces == 0 then
    dismiss_overlay()
    return
  end

  local layout = switcher_layout()
  local canvas = base_canvas(layout, layout.workspace_height)

  local row_center = layout.workspace_height / 2
  local total_width = #workspaces * WORKSPACE_ITEM_WIDTH
  local start_x = (layout.width - total_width) / 2

  for i, ws in ipairs(workspaces) do
    local selected = i == selected_index
    local x = start_x + (i - 1) * WORKSPACE_ITEM_WIDTH
    local icon = WORKSPACE_ICONS[ws] or ws
    local text_size = selected and WORKSPACE_SELECTED_TEXT_SIZE or WORKSPACE_TEXT_SIZE
    local text_height = text_size + WORKSPACE_TEXT_FRAME_EXTRA
    local text_y = row_center - (text_height / 2) + WORKSPACE_TEXT_BASELINE_OFFSET

    canvas:appendElements({
      type = "text",
      text = icon,
      frame = { x = x, y = text_y, w = WORKSPACE_ITEM_WIDTH, h = text_height },
      textSize = text_size,
      textColor = selected and COLORS.icon or COLORS.empty,
      textAlignment = "center",
    })
  end

  canvas:show()
  current_canvas = canvas
end

local function start_window_switcher(step)
  local ws = focused_workspace()
  if ws == "" then
    return
  end

  mode = "windows"
  current_workspace = ws
  windows = workspace_windows(ws)
  if #windows == 0 then
    return
  end

  active = true
  selected_index = index_from_focused(windows, step)
  render_window_overlay()
end

local function index_after_workspace(items, current)
  if #items == 0 then
    return 1
  end

  for i, item in ipairs(items) do
    if item == current then
      return (i % #items) + 1
    end
  end
  return 1
end

local function start_workspace_switcher()
  local ws = focused_workspace()
  if ws == "" then
    return
  end

  mode = "workspaces"
  current_workspace = ws
  workspaces = all_workspaces()
  if #workspaces == 0 then
    return
  end

  active = true
  selected_index = index_after_workspace(workspaces, ws)
  current_workspace = workspaces[selected_index]
  render_workspace_overlay()
end

local function cycle_window_selection(step)
  if not active then
    start_window_switcher(step)
    return
  end

  if mode ~= "windows" then
    start_window_switcher(step)
    return
  end

  if #windows == 0 then
    dismiss_overlay()
    active = false
    return
  end

  selected_index = ((selected_index - 1 + step) % #windows) + 1
  render_window_overlay()
end

local function cycle_workspace_selection()
  if not active then
    start_workspace_switcher()
    return
  end

  if mode ~= "workspaces" then
    start_workspace_switcher()
    return
  end

  if #workspaces == 0 then
    dismiss_overlay()
    active = false
    return
  end

  selected_index = (selected_index % #workspaces) + 1
  current_workspace = workspaces[selected_index]
  render_workspace_overlay()
end

local function finish_switcher()
  if not active then
    return
  end

  local selected = windows[selected_index]
  local selected_workspace = workspaces[selected_index]
  local finish_mode = mode

  active = false
  mode = nil
  dismiss_overlay()

  if finish_mode == "windows" and selected and selected.id then
    run(AEROSPACE .. " focus --window-id " .. shell_quote(selected.id))
  elseif finish_mode == "workspaces" and selected_workspace then
    run(AEROSPACE .. " workspace " .. shell_quote(selected_workspace))
  end
end

M.forward_hotkey = hs.hotkey.bind({ "alt" }, "tab", function()
  cycle_window_selection(1)
end)

M.workspace_hotkey = hs.hotkey.bind({ "alt", "shift" }, "tab", function()
  cycle_workspace_selection()
end)

M.alt_release_watcher = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
  if active and not event:getFlags().alt then
    finish_switcher()
  end
  return false
end)

M.alt_release_watcher:start()

return M
