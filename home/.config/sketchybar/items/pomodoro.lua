local icons = require("lib.icons")
local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")

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
local detail_visible = false
local detail_busy = false
local detail_signature
local apply_mode_ui
local detail_epoch = 0
local visibility_retries, visibility_retry_at = 0, nil
local detail_binary = utils.shell_quote((os.getenv("HOME") or "") .. "/.local/bin/sketchibar")

local function retry_visibility()
  if visibility_retry_at or visibility_retries >= 3 then return end
  visibility_retry_at = os.time() + 2 ^ visibility_retries
  visibility_retries = visibility_retries + 1
end

local INACTIVE_COLOR = colors.foreground
-- Work looks "poisoned" purple; breaks use the normal foreground.
local ACTIVE_WORK_COLOR = colors.base0e
local ACTIVE_SHORT_BREAK_COLOR = colors.foreground
local ACTIVE_LONG_BREAK_COLOR = colors.foreground

os.execute("mkdir -p " .. utils.shell_quote(pomo_dir))

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

local function notify(title, subtitle, message, sound, event)
  local cmd = table.concat({
    utils.shell_quote((os.getenv("HOME") or "") .. "/.local/bin/nudge"), "send",
    "--source", "pomodoro", "--event", utils.shell_quote(event),
    "--preset", "timer-ended", "--ttl-seconds", "60",
    "--title", utils.shell_quote(title), "--subtitle", utils.shell_quote(subtitle),
    "--body", utils.shell_quote(message), "--sound", utils.shell_quote(sound),
  }, " ")
  -- SketchyBar parses JSON stdout for us. Never wait for delivery or retry an
  -- uncertain outcome: timer transitions must not depend on Hammerspoon/IPC.
  local scheduled = pcall(Sbar.exec, cmd .. " 2>/dev/null", function(result, exit_code)
    if exit_code ~= 0 then
      utils.log("pomodoro: nudge delivery failed (exit " .. tostring(exit_code) .. ")")
    elseif type(result) ~= "table" or result.ok ~= true then
      utils.log("pomodoro: nudge returned an invalid or unsuccessful response")
    elseif type(result.sound) == "table" and result.sound.status == "failed" then
      utils.log("pomodoro: nudge sound playback failed")
    end
  end)
  if not scheduled then utils.log("pomodoro: could not schedule nudge delivery") end
end

-- There is only one timer engine. The detail bar receives display properties,
-- never a timer command, state-file write or notification schedule.
local function publish_detail(label)
  if not detail_visible or detail_busy then return end
  local active = mode ~= "none"
  local icon = mode == "break" and icons.vaccine_bottle or icons.vaccine
  local color = mode == "work" and ACTIVE_WORK_COLOR
    or (break_kind == "long" and ACTIVE_LONG_BREAK_COLOR or ACTIVE_SHORT_BREAK_COLOR)
  local signature = table.concat({tostring(active), icon, color, label or ""}, "|")
  if detail_signature == signature then return end
  local command = detail_binary .. " --set sketchibar.pomodoro "
    .. utils.shell_quote("drawing=" .. (active and "on" or "off")) .. " "
    .. utils.shell_quote("icon=" .. icon) .. " "
    .. utils.shell_quote("icon.color=" .. color) .. " "
    .. utils.shell_quote("label=" .. (label or ""))
  detail_busy = true
  detail_signature = signature
  local epoch = detail_epoch
  local scheduled = pcall(Sbar.exec, command .. " 2>/dev/null", function(_, exit_code)
    detail_busy = false
    if exit_code ~= 0 and epoch == detail_epoch then
      detail_visible = false
      detail_signature = nil
      retry_visibility()
      apply_mode_ui()
      utils.log("pomodoro: detail display unavailable, using main popup")
    elseif exit_code == 0 and epoch == detail_epoch then
      visibility_retries, visibility_retry_at = 0, nil
    end
  end)
  if not scheduled then
    detail_busy = false
    detail_visible = false
    detail_signature = nil
    retry_visibility()
    apply_mode_ui()
  end
end

apply_mode_ui = function()
  local remaining = math.max(0, duration_for_mode(mode) - (os.time() - (start_time or os.time())))
  local label = mode ~= "none" and popup_label(remaining) or nil
  if mode == "work" then
    pomodoro_work:set({ drawing = true, ["icon.color"] = ACTIVE_WORK_COLOR, ["popup.drawing"] = not detail_visible })
    pomodoro_work_popup:set({ drawing = not detail_visible, label = label })
    pomodoro_break:set({ drawing = false, ["icon.color"] = INACTIVE_COLOR, ["popup.drawing"] = false })
    pomodoro_break_popup:set({ drawing = false, label = "" })
  elseif mode == "break" then
    local color = (break_kind == "long") and ACTIVE_LONG_BREAK_COLOR or ACTIVE_SHORT_BREAK_COLOR
    pomodoro_break:set({ drawing = true, ["icon.color"] = color, ["popup.drawing"] = not detail_visible })
    pomodoro_break_popup:set({ drawing = not detail_visible, label = label })
    pomodoro_work:set({ drawing = false, ["icon.color"] = INACTIVE_COLOR, ["popup.drawing"] = false })
    pomodoro_work_popup:set({ drawing = false, label = "" })
  end
  publish_detail(label)
end

pomodoro_work = Sbar.add("item", "pomodoro_work", {
  position                           = "right",
  icon                               = icons.vaccine,
  ["icon.font.size"]                  = settings.icon_size,
  ["icon.padding_left"]              = 0,
  ["icon.padding_right"]             = 0,
  ["padding_right"]                  = 2,
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
  position                           = "right",
  icon                               = icons.vaccine_bottle,
  ["icon.font.size"]                 = settings.icon_size,
  ["icon.padding_left"]              = 0,
  ["icon.padding_right"]             = 0,
  ["padding_right"]                  = 2,
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

Sbar.add("event", "sketchibar_visibility")
local visibility_busy, visibility_pending = false, false
local function refresh_visibility()
  detail_epoch = detail_epoch + 1
  if visibility_busy then visibility_pending = true; return end
  visibility_busy = true
  local epoch = detail_epoch
  local scheduled = pcall(Sbar.exec, detail_binary .. " --query bar 2>/dev/null", function(info, exit_code)
    visibility_busy = false
    if epoch == detail_epoch then
      local valid = exit_code == 0 and type(info) == "table"
        and (info.hidden == "off" or info.hidden == "on")
      detail_visible = valid and info.hidden == "off" and info.drawing ~= "off"
      detail_signature = nil
      if valid then
        visibility_retry_at = nil
        -- A visible bar is usable only after its display update succeeds.
        if not detail_visible then visibility_retries = 0 end
      else
        retry_visibility()
      end
      apply_mode_ui()
    end
    if visibility_pending then
      visibility_pending = false
      refresh_visibility()
    end
  end)
  if not scheduled then
    visibility_busy = false
    visibility_pending = false
    detail_visible = false
    retry_visibility()
    apply_mode_ui()
  end
end

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
  publish_detail(nil)
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
    sound,
    "work-completed"
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
    settings.pomodoro_sound_break_done,
    "break-completed"
  )
  start_mode("work")
end

local function on_routine()
  if visibility_retry_at and os.time() >= visibility_retry_at then
    visibility_retry_at = nil
    refresh_visibility()
  end
  if mode == "none" then publish_detail(nil); return end
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
  publish_detail(label)
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

pomodoro_work:subscribe("sketchibar_visibility", function()
  visibility_retries, visibility_retry_at = 0, nil
  refresh_visibility()
end)
refresh_visibility()
