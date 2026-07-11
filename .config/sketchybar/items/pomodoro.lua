local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local pomo_dir   = (os.getenv("HOME") or "") .. "/.pomodoro"
local state_file = pomo_dir .. "/pomo_state"

local mode       = "none"
local start_time = nil
local tomatoes_done = 0
local break_kind = "short"
local pomodoro_work
local pomodoro_work_popup
local pomodoro_break
local pomodoro_break_popup

local INACTIVE_COLOR = colors.foreground
local ACTIVE_WORK_COLOR = colors.base04
local ACTIVE_SHORT_BREAK_COLOR = colors.base0d
local ACTIVE_LONG_BREAK_COLOR = colors.base0e

os.execute("mkdir -p " .. pomo_dir)

local function save_state()
  local f = io.open(state_file, "w")
  if not f then return end
  f:write(mode .. "\n")
  f:write(tostring(start_time or "") .. "\n")
  f:write(tostring(tomatoes_done or 0) .. "\n")
  f:write(tostring(break_kind or "short") .. "\n")
  f:close()
end

local function load_state()
  local f = io.open(state_file, "r")
  if not f then return end
  local m = f:read("*l") or "none"
  local t = f:read("*l")
  local tomatoes = f:read("*l")
  local kind = f:read("*l")
  f:close()
  if m == "work" or m == "break" then
    mode = m
    start_time = tonumber(t)
    tomatoes_done = math.max(0, tonumber(tomatoes) or 0)
    if kind == "long" or kind == "short" then
      break_kind = kind
    else
      break_kind = "short"
    end
  end
end

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", [['"'"']]) .. "'"
end

local function format_time(secs)
  local m = math.floor(secs / 60)
  local s = secs % 60
  return string.format("%02d:%02d", m, s)
end

local function break_duration()
  if break_kind == "long" then
    return settings.pomodoro_long_break_seconds
  end
  return settings.pomodoro_short_break_seconds
end

local function duration_for_mode(m)
  if m == "work" then
    return settings.pomodoro_work_seconds
  end
  return break_duration()
end

local function cycle_label()
  return string.format("%d/%d", tomatoes_done, settings.pomodoro_long_break_every)
end

local function popup_label(remaining)
  local prefix = string.format("[%s]", cycle_label())
  if mode == "work" then
    return string.format("%s %s", prefix, format_time(remaining))
  elseif break_kind == "long" then
    return string.format("%s %s(!)", prefix, format_time(remaining))
  end
  return string.format("%s %s", prefix, format_time(remaining))
end

local function notify(title, subtitle, message, sound)
  local cmd = table.concat({
    "osascript",
    "-e", shell_quote("display notification " .. string.format("%q", message)
      .. " with title " .. string.format("%q", title)
      .. " subtitle " .. string.format("%q", subtitle)
      .. " sound name " .. string.format("%q", sound)),
  }, " ")
  os.execute(cmd .. " >/dev/null 2>&1 &")
end

local function apply_mode_ui()
  if mode == "work" then
    local label = popup_label(settings.pomodoro_work_seconds)
    pomodoro_work:set({ drawing = true, ["icon.color"] = ACTIVE_WORK_COLOR, ["popup.drawing"] = true })
    pomodoro_work_popup:set({ drawing = true, label = label })
    pomodoro_break:set({ drawing = false, ["icon.color"] = INACTIVE_COLOR, ["popup.drawing"] = false })
    pomodoro_break_popup:set({ drawing = false, label = "" })
  elseif mode == "break" then
    local label = popup_label(break_duration())
    local color = (break_kind == "long") and ACTIVE_LONG_BREAK_COLOR or ACTIVE_SHORT_BREAK_COLOR
    pomodoro_break:set({ drawing = true, ["icon.color"] = color, ["popup.drawing"] = true })
    pomodoro_break_popup:set({ drawing = true, label = label })
    pomodoro_work:set({ drawing = false, ["icon.color"] = INACTIVE_COLOR, ["popup.drawing"] = false })
    pomodoro_work_popup:set({ drawing = false, label = "" })
  end
end

pomodoro_work = Sbar.add("item", "pomodoro_work", {
  position                           = "e",
  icon                               = "􀠸",
  ["icon.font.size"]                  = settings.icon_size,
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

pomodoro_work_popup = Sbar.add("item", "pomodoro_work_popup", {
  position                = "popup.pomodoro_work",
  ["icon.drawing"]        = false,
  label                   = "",
  ["label.font.size"]     = 12,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
  drawing                 = false,
})

pomodoro_break = Sbar.add("item", "pomodoro_break", {
  position                           = "e",
  icon                               = "􀼙",
  ["icon.font.size"]                 = settings.icon_size,
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

pomodoro_break_popup = Sbar.add("item", "pomodoro_break_popup", {
  position                = "popup.pomodoro_break",
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

Sbar.add("event", "pomodoro_change")

local function stop_timer()
  mode = "none"
  start_time = nil
  save_state()
  pomodoro_work:set({
    drawing            = true,
    ["icon.color"]     = INACTIVE_COLOR,
    ["popup.drawing"]  = false,
  })
  pomodoro_work_popup:set({ drawing = false, label = "" })
  pomodoro_break:set({
    drawing            = false,
    ["icon.color"]     = INACTIVE_COLOR,
    ["popup.drawing"]  = false,
  })
  pomodoro_break_popup:set({ drawing = false, label = "" })
  utils.log("pomodoro: stopped")
end

local function start_mode(m, kind)
  mode = m
  start_time = os.time()
  if kind == "short" or kind == "long" then
    break_kind = kind
  elseif m == "break" then
    break_kind = "short"
  end
  save_state()
  apply_mode_ui()
  utils.log("pomodoro: started " .. m .. ", tomatoes=" .. tomatoes_done .. ", break_kind=" .. break_kind)
end

local function complete_work()
  tomatoes_done = tomatoes_done + 1
  local long_break = (tomatoes_done % settings.pomodoro_long_break_every) == 0
  local next_break_kind = long_break and "long" or "short"
  local break_mins = math.floor((long_break and settings.pomodoro_long_break_seconds or settings.pomodoro_short_break_seconds) / 60)
  local sound = long_break and settings.pomodoro_sound_long_break or settings.pomodoro_sound_work_done
  notify(
    "Pomodoro",
    tomatoes_done .. " tomato" .. ((tomatoes_done == 1) and "" or "es") .. " done",
    (long_break and "Long" or "Short") .. " break: " .. break_mins .. " min",
    sound
  )
  start_mode("break", next_break_kind)
end

local function complete_break()
  local finished_long_break = break_kind == "long"
  if finished_long_break then
    tomatoes_done = 0
  end
  local work_mins = math.floor(settings.pomodoro_work_seconds / 60)
  notify(
    "Pomodoro",
    "Break done",
    "Work time: " .. work_mins .. " min",
    settings.pomodoro_sound_break_done
  )
  start_mode("work")
end

local function on_routine()
  if mode == "none" then return end
  local duration  = duration_for_mode(mode)
  local remaining = duration - (os.time() - (start_time or os.time()))
  if remaining <= 0 then
    utils.log("pomodoro: " .. mode .. " done, tomatoes=" .. tomatoes_done .. ", break_kind=" .. break_kind)
    if mode == "work" then
      complete_work()
    else
      complete_break()
    end
    return
  end
  local label = popup_label(remaining)
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

local function on_command(env)
  local action = (env.ACTION or "toggle"):lower()

  if action == "start" or action == "work" then
    start_mode("work")
  elseif action == "break" then
    start_mode("break")
  elseif action == "stop" then
    stop_timer()
  elseif action == "toggle" then
    if mode == "work" then
      stop_timer()
    else
      start_mode("work")
    end
  else
    utils.log("pomodoro: ignored unknown command " .. action)
  end
end

-- Restore state from disk on load
load_state()
if mode == "work" then
  apply_mode_ui()
elseif mode == "break" then
  apply_mode_ui()
end

utils.log("pomodoro: loaded, mode=" .. mode .. ", tomatoes=" .. tomatoes_done .. ", break_kind=" .. break_kind)

pomodoro_work:subscribe("routine", function(env) on_routine() end)
pomodoro_break:subscribe("routine", function(env) on_routine() end)
pomodoro_work:subscribe("mouse.clicked", function(env) on_click("work", env) end)
pomodoro_break:subscribe("mouse.clicked", function(env) on_click("break", env) end)
pomodoro_work:subscribe("pomodoro_change", on_command)
