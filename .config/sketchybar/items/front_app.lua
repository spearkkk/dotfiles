local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local ITEM = "front_app"
local MAX_CHARS = 28
local EMPTY_WORKSPACE_LABEL = "∅ idle"

local function current_front_app(env)
  local info = (env and env.INFO) or ""
  info = info:gsub("^%s+", ""):gsub("%s+$", "")
  if info ~= "" then
    return info
  end

  local app = utils.capture("lsappinfo info -only name $(lsappinfo front) 2>/dev/null | cut -d'\"' -f4 | xargs")
  if app ~= "" then
    return app
  end

  return "-"
end

local front_app = Sbar.add("item", ITEM, {
  position = "left",
  icon = {
    drawing = false,
  },
  label = {
    drawing = true,
    color = colors.foreground,
    align = "left",
    max_chars = MAX_CHARS,
    padding_left = 10,
    padding_right = 10,
    font = {
      style = "Italic",
      size = settings.label_size,
    },
  },
  background = {
    drawing = true,
    color = colors.background_alt,
    padding_left = 6,
    padding_right = 6,
    height = settings.defaults.bg_height + 4,
    corner_radius = settings.defaults.corner_radius,
    border_width = 3,
    border_color = utils.set_alpha(colors.base04, 90),
    y_offset = settings.defaults.bg_y_offset,
  },
  update_freq = 0,
  click_script = "open -a 'Mission Control'",
})

local function refresh(env)
  local app = current_front_app(env)
  if app == "" or app == "-" then
    front_app:set({ label = EMPTY_WORKSPACE_LABEL })
    return
  end
  front_app:set({ label = app })
end

local function on_event(env)
  local sender = (env and env.SENDER) or ""
  if sender == "front_app_switched" then
    refresh(env)
    return
  end

  if sender == "aerospace_workspace_change" or sender == "display_change" then
    refresh(nil)
    return
  end

  refresh(env)
end

-- Keep the same event set as the original front_app.sh item.
front_app:subscribe({ "front_app_switched", "display_change", "aerospace_workspace_change", "system_woke" }, on_event)
front_app:subscribe("forced", function(_)
  refresh(nil)
end)

refresh(nil)
