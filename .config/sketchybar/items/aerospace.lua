local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local KEYS = { "Q", "W", "E", "R", "`" }

local LEFT_START = settings.outer_padding
local CELL_GAP = 2

local ACTIVE_COLOR = colors.base0a
local INACTIVE_COLOR = colors.base04
local ACTIVE_ICON_SIZE = settings.icon_size + 8
local INACTIVE_ICON_SIZE = settings.icon_size

local items = {}

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", [['"'"']]) .. "'"
end

local function normalize_ws(value)
  local s = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" or s == "`" then
    return s
  end
  return s:upper()
end

local function focused_workspace(env)
  local from_env = (env and env.FOCUSED_WORKSPACE) or ""
  from_env = from_env:gsub("^%s+", ""):gsub("%s+$", "")
  if from_env ~= "" then
    return normalize_ws(from_env)
  end

  local ws = utils.capture("aerospace list-workspaces --focused 2>/dev/null | head -n1 | xargs")
  return normalize_ws(ws)
end

local function add_ws_item(idx, ws_id)
  local pad = ((idx == 1) and LEFT_START or CELL_GAP) + 2

  local icon_map = {
    ["Q"] = "􀂴 ",
    ["W"] = "􀃀 ",
    ["E"] = "􀂜 ",
    ["R"] = "􀂶 ",
    ["`"] = "􀓔 ",
  }
  local icon = icon_map[ws_id] or ws_id

  local item = Sbar.add("item", "aerospace.ws." .. idx, {
    position = "left",
    icon = icon,
    padding_left = pad,
    ["icon.drawing"] = true,
    ["icon.color"] = INACTIVE_COLOR,
    ["icon.padding_left"] = settings.inner_padding - 1,
    ["icon.padding_right"] = settings.inner_padding - 1,
    ["icon.font.size"] = INACTIVE_ICON_SIZE,
    padding_right = 2,
    ["label.drawing"] = false,
    ["background.drawing"] = false,
    click_script = "aerospace workspace " .. shell_quote(ws_id),
    update_freq = 0,
  })

  items[#items + 1] = {
    item = item,
    ws = normalize_ws(ws_id),
  }
end

for i, ws in ipairs(KEYS) do
  add_ws_item(i, ws)
end

local function refresh(env)
  local focused = focused_workspace(env)
  for _, ref in ipairs(items) do
    local active = (ref.ws == focused)
    ref.item:set({
      ["icon.color"] = active and ACTIVE_COLOR or INACTIVE_COLOR,
      ["icon.font.size"] = active and ACTIVE_ICON_SIZE or INACTIVE_ICON_SIZE,
    })
  end
end

for _, ref in ipairs(items) do
  ref.item:subscribe({ "aerospace_workspace_change", "system_woke", "forced", "display_change" }, refresh)
  ref.item:subscribe("mouse.clicked", function(_)
    refresh({ FOCUSED_WORKSPACE = ref.ws })
  end)
end

refresh(nil)
