local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local WORK_SECS  = 25 * 60
local BREAK_SECS = 5 * 60
local pomo_dir   = (os.getenv("HOME") or "") .. "/.pomodoro"
local state_file = pomo_dir .. "/pomo_state"

local mode       = "none"
local start_time = nil

os.execute("mkdir -p " .. pomo_dir)

local function save_state()
  local f = io.open(state_file, "w")
  if not f then return end
  f:write(mode .. "\n")
  f:write(tostring(start_time or "") .. "\n")
  f:close()
end

local function load_state()
  local f = io.open(state_file, "r")
  if not f then return end
  local m = f:read("*l") or "none"
  local t = f:read("*l")
  f:close()
  if m == "work" or m == "break" then
    mode = m
    start_time = tonumber(t)
  end
end

local function format_time(secs)
  local m = math.floor(secs / 60)
  local s = secs % 60
  return string.format("%02d:%02d", m, s)
end

local width = utils.icon_width(27, 45, 0.02025, 33)

local pomodoro_work = Sbar.add("item", "pomodoro_work", "e", {
  icon                               = "􀠸",
  width                              = width,
  ["icon.padding_left"]              = settings.outer_padding,
  ["icon.padding_right"]             = 0,
  ["label.drawing"]                  = false,
  ["background.drawing"]             = false,
  drawing                            = true,
  update_freq                        = 1,
  ["popup.height"]                   = 22,
  ["popup.align"]                    = "center",
  ["popup.y_offset"]                 = -4,
  ["popup.background.height"]        = 20,
  ["popup.background.color"]         = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_color"]  = colors.base0a,
  ["popup.background.border_width"]  = 2,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.drawing"]       = true,
})

local pomodoro_work_popup = Sbar.add("item", "pomodoro_work_popup", "popup.pomodoro_work", {
  ["icon.drawing"]        = false,
  label                   = "",
  ["label.font.size"]     = 12,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
  drawing                 = false,
})

local pomodoro_break = Sbar.add("item", "pomodoro_break", "e", {
  icon                               = "􀼙",
  width                              = width,
  ["icon.padding_left"]              = settings.outer_padding,
  ["icon.padding_right"]             = 0,
  ["label.drawing"]                  = false,
  ["background.drawing"]             = false,
  drawing                            = false,
  update_freq                        = 1,
  ["popup.height"]                   = 22,
  ["popup.align"]                    = "center",
  ["popup.y_offset"]                 = -4,
  ["popup.background.height"]        = 20,
  ["popup.background.color"]         = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_color"]  = colors.base0a,
  ["popup.background.border_width"]  = 2,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.drawing"]       = true,
})

local pomodoro_break_popup = Sbar.add("item", "pomodoro_break_popup", "popup.pomodoro_break", {
  ["icon.drawing"]        = false,
  label                   = "",
  ["label.font.size"]     = 12,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
  drawing                 = false,
})

Sbar.add("bracket", "pomodoro_group", { "pomodoro_break", "pomodoro_work" }, {
  drawing                = false,
  ["padding_left"]       = 0,
  ["padding_right"]      = 0,
  ["background.drawing"] = false,
})

local function stop_timer()
  mode = "none"
  start_time = nil
  save_state()
  pomodoro_work:set({
    drawing            = true,
    ["icon.color"]     = colors.foreground,
    ["popup.drawing"]  = false,
  })
  pomodoro_work_popup:set({ drawing = false, label = "" })
  pomodoro_break:set({
    drawing            = false,
    ["icon.color"]     = colors.foreground,
    ["popup.drawing"]  = false,
  })
  pomodoro_break_popup:set({ drawing = false, label = "" })
  utils.log("pomodoro: stopped")
end

local function start_mode(m)
  mode = m
  start_time = os.time()
  save_state()
  if m == "work" then
    local label = format_time(WORK_SECS)
    pomodoro_work:set({ drawing = true, ["icon.color"] = colors.base0d, ["popup.drawing"] = true })
    pomodoro_work_popup:set({ drawing = true, label = label })
    pomodoro_break:set({ drawing = false, ["popup.drawing"] = false })
    pomodoro_break_popup:set({ drawing = false, label = "" })
  else
    local label = format_time(BREAK_SECS)
    pomodoro_break:set({ drawing = true, ["icon.color"] = colors.base0c, ["popup.drawing"] = true })
    pomodoro_break_popup:set({ drawing = true, label = label })
    pomodoro_work:set({ drawing = false, ["popup.drawing"] = false })
    pomodoro_work_popup:set({ drawing = false, label = "" })
  end
  utils.log("pomodoro: started " .. m)
end

local function on_routine()
  if mode == "none" then return end
  local duration  = (mode == "work") and WORK_SECS or BREAK_SECS
  local remaining = duration - (os.time() - (start_time or os.time()))
  if remaining <= 0 then
    local next_mode = (mode == "work") and "break" or "work"
    utils.log("pomodoro: " .. mode .. " done, switching to " .. next_mode)
    start_mode(next_mode)
    return
  end
  local label = format_time(remaining)
  if mode == "work" then
    pomodoro_work_popup:set({ label = label })
  else
    pomodoro_break_popup:set({ label = label })
  end
end

local function on_click(item_mode, env)
  local button = (env.BUTTON or ""):lower()
  local right  = (button == "right" or button == "secondary")
  if right then
    local other = (item_mode == "work") and "break" or "work"
    start_mode(other)
    return
  end
  if mode == item_mode then
    stop_timer()
  else
    start_mode(item_mode)
  end
end

-- Restore state from disk on load
load_state()
if mode == "work" then
  pomodoro_work:set({ drawing = true, ["icon.color"] = colors.base0d, ["popup.drawing"] = true })
  pomodoro_work_popup:set({ drawing = true })
elseif mode == "break" then
  pomodoro_break:set({ drawing = true, ["icon.color"] = colors.base0c, ["popup.drawing"] = true })
  pomodoro_break_popup:set({ drawing = true })
end

utils.log("pomodoro: loaded, mode=" .. mode)

pomodoro_work:subscribe("routine", function(env) on_routine() end)
pomodoro_break:subscribe("routine", function(env) on_routine() end)
pomodoro_work:subscribe("mouse.clicked", function(env) on_click("work", env) end)
pomodoro_break:subscribe("mouse.clicked", function(env) on_click("break", env) end)
