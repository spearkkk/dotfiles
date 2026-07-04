#!/usr/bin/env lua

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function shell_quote(s)
  local v = tostring(s or "")
  return "'" .. v:gsub("'", "'\\''") .. "'"
end

local function set_item(item, props)
  local parts = { "sketchybar", "--set", shell_quote(item) }
  for _, kv in ipairs(props) do
    table.insert(parts, kv[1] .. "=" .. shell_quote(kv[2]))
  end
  os.execute(table.concat(parts, " "))
end

local function run(cmd)
  os.execute(cmd)
end

local inner_padding = 4
local outer_padding = 8
local pill_y_offset = 0

local base_icon_color = "0xFFEBDBB2"
local work_icon_color = "0xFFEA6962"
local break_icon_color = "0xFF7DAEA3"

local home = os.getenv("HOME") or ""
local pomo_dir = home .. "/.pomodoro"
local mode_file = pomo_dir .. "/pomo_mode"
local pid_file = pomo_dir .. "/pomo_timer.pid"
local history_file = pomo_dir .. "/pomodoro_history"
run("mkdir -p " .. shell_quote(pomo_dir))

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return ""
  end
  local data = f:read("*a") or ""
  f:close()
  return (data:gsub("%s+$", ""))
end

local function write_file(path, value)
  local f = io.open(path, "w")
  if not f then
    return
  end
  f:write(value)
  f:close()
end

local function stop_timer(button_id)
  local pid = read_file(pid_file)
  if pid ~= "" then
    run("kill " .. shell_quote(pid) .. " >/dev/null 2>&1 || true")
    run("rm -f " .. shell_quote(pid_file))
  end
  write_file(mode_file, "none\n")
  set_item(button_id, {
    { "drawing", "on" },
    { "label", "" },
    { "label.drawing", "off" },
    { "icon.color", base_icon_color },
    { "label.padding_left", "0" },
    { "label.padding_right", "0" },
    { "icon.padding_right", tostring(outer_padding) },
  })
end

local function start_background_countdown(script_path, duration, button_id, break_id, work_id, work_min, break_min)
  local cmd = table.concat({
    "nohup",
    shell_quote(script_path),
    "--countdown",
    tostring(duration),
    shell_quote(button_id),
    shell_quote(break_id),
    shell_quote(work_id),
    tostring(work_min),
    tostring(break_min),
    ">/dev/null 2>&1 & echo $! >",
    shell_quote(pid_file),
  }, " ")
  run(cmd)
end

local function finish_countdown(script_path, button_id, break_id, work_id, work_min, break_min, start_time)
  local end_time = os.date("%Y-%m-%d %H:%M:%S")
  run("rm -f " .. shell_quote(pid_file))
  write_file(mode_file, "none\n")

  if button_id == work_id then
    run("terminal-notifier -title 'Pomodoro' -message 'Work Timer is up! Take a Break 🍅' -sound Funk >/dev/null 2>&1 || true")
    run("printf '%s  %s  [WORK]  %s mins\\n' "
      .. shell_quote(start_time) .. " "
      .. shell_quote(end_time) .. " "
      .. tostring(work_min) .. " >> " .. shell_quote(history_file))
    run("afplay -v 1.5 '/System/Library/Sounds/Basso.aiff' >/dev/null 2>&1 &")

    run("sketchybar --set " .. shell_quote(break_id) .. " drawing=on")
    set_item(work_id, {
      { "drawing", "off" },
      { "label", "" },
      { "label.drawing", "off" },
      { "icon.color", base_icon_color },
      { "label.padding_left", "0" },
      { "label.padding_right", "0" },
      { "icon.padding_right", tostring(outer_padding) },
    })

    write_file(mode_file, break_id .. "\n")
    run("sketchybar --set " .. shell_quote(break_id) .. " drawing=off --set " .. shell_quote(work_id) .. " drawing=off")
    start_background_countdown(script_path, break_min, break_id, break_id, work_id, work_min, break_min)
  else
    run("terminal-notifier -title 'Pomodoro' -message 'Break is over! Get back to work ☕️' -sound Funk >/dev/null 2>&1 || true")
    run("printf '%s  %s  [REST]  %s mins\\n' "
      .. shell_quote(start_time) .. " "
      .. shell_quote(end_time) .. " "
      .. tostring(break_min) .. " >> " .. shell_quote(history_file))
    run("afplay -v 5 '/System/Library/Sounds/Blow.aiff' >/dev/null 2>&1 &")

    run("sketchybar --set " .. shell_quote(work_id) .. " drawing=on")
    set_item(break_id, {
      { "drawing", "off" },
      { "label", "" },
      { "label.drawing", "off" },
      { "icon.color", base_icon_color },
      { "label.padding_left", "0" },
      { "label.padding_right", "0" },
      { "icon.padding_right", tostring(outer_padding) },
    })
  end
end

local function countdown_mode(args, script_path)
  local duration = tonumber(args[2]) or 25
  local button_id = args[3] or ""
  local break_id = args[4] or ""
  local work_id = args[5] or ""
  local work_min = tonumber(args[6]) or 25
  local break_min = tonumber(args[7]) or 5

  if button_id == "" or break_id == "" or work_id == "" then
    return
  end

  local start_time = os.date("%Y-%m-%d %H:%M:%S")
  local time_left = duration * 60
  while time_left >= 0 do
    local minutes = math.floor(time_left / 60)
    local seconds = time_left % 60
    local time_str = string.format("%02d:%02d", minutes, seconds)

    set_item(button_id, {
      { "label", time_str },
      { "drawing", "on" },
      { "icon.padding_right", tostring(inner_padding) },
      { "label.drawing", "on" },
      { "label.padding_left", tostring(inner_padding) },
      { "label.padding_right", tostring(inner_padding) },
      { "label.y_offset", tostring(pill_y_offset) },
    })

    if button_id == work_id then
      run("sketchybar --set " .. shell_quote(break_id) .. " drawing=off")
      set_item(button_id, { { "icon.color", work_icon_color } })
    else
      run("sketchybar --set " .. shell_quote(work_id) .. " drawing=off")
      set_item(button_id, { { "icon.color", break_icon_color } })
    end

    run("sleep 1")
    time_left = time_left - 1
  end

  finish_countdown(script_path, button_id, break_id, work_id, work_min, break_min, start_time)
end

local function click_mode(args, script_path)
  local break_id = args[1] or ""
  local work_id = args[2] or ""
  local id = args[3] or ""
  local work_min = tonumber(args[4]) or 25
  local break_min = tonumber(args[5]) or 5
  local current_mode = read_file(mode_file)
  if current_mode == "" then
    current_mode = "none"
  end

  if id == work_id then
    if current_mode == work_id then
      stop_timer(work_id)
    else
      stop_timer(work_id)
      write_file(mode_file, work_id .. "\n")
      run("sketchybar --set " .. shell_quote(break_id) .. " drawing=off --set " .. shell_quote(work_id) .. " drawing=off")
      start_background_countdown(script_path, work_min, work_id, break_id, work_id, work_min, break_min)
    end
  elseif id == break_id then
    if current_mode == break_id then
      stop_timer(break_id)
    else
      stop_timer(break_id)
      write_file(mode_file, break_id .. "\n")
      run("sketchybar --set " .. shell_quote(break_id) .. " drawing=off --set " .. shell_quote(work_id) .. " drawing=off")
      start_background_countdown(script_path, break_min, break_id, break_id, work_id, work_min, break_min)
    end
  end
end

local script_path = arg[0] or ((os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")) .. "/plugins/pomodoro.lua")

if arg[1] == "--countdown" then
  countdown_mode(arg, script_path)
else
  click_mode(arg, script_path)
end
