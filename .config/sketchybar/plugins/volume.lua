#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local MAIN_ITEM = "lua.volume"
local mode = arg[1] or "--refresh"
local arg2 = arg[2] or ""

local popup_open_file = "/tmp/sketchybar.volume.popup.open"
local popup_token_file = "/tmp/sketchybar.volume.popup.token"

local muted_color = os.getenv("VOLUME_MUTED_COLOR") or "0xFF4A6E86"
local on_color = os.getenv("VOLUME_ON_COLOR") or "0xFFC8AE6A"
local popup_text_color_env = os.getenv("VOLUME_LABEL_COLOR")
local theme = require("lib.theme")
local popup_text_color = popup_text_color_env or theme.colors.text_lightest

local popup_prefix = "lua.volume.device"
local popup_slots = 8
local popup_close_delay_seconds = "0.18"
local popup_timeout_seconds = "3"

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end

  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function sh(cmd)
  os.execute(cmd .. " >/dev/null 2>&1")
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", [['"'"']]) .. "'"
end

local color_env_prefix = table.concat({
  "VOLUME_MUTED_COLOR=" .. shell_quote(muted_color),
  "VOLUME_ON_COLOR=" .. shell_quote(on_color),
  "VOLUME_LABEL_COLOR=" .. shell_quote(popup_text_color),
}, " ")

local function spawn(script)
  os.execute(string.format("sh -c %s >/dev/null 2>&1 &", shell_quote(script)))
end

local function plugin_command(args)
  local parts = { color_env_prefix, shell_quote(config_dir .. "/plugins/volume.lua") }
  for _, value in ipairs(args) do
    parts[#parts + 1] = shell_quote(value)
  end
  return table.concat(parts, " ")
end

local function file_write(path, value)
  local f = io.open(path, "w")
  if f then
    f:write(value or "")
    f:close()
  end
end

local function file_read(path)
  local f = io.open(path, "r")
  if not f then
    return ""
  end

  local value = f:read("*a") or ""
  f:close()
  return value:gsub("%s+$", "")
end

local function skip_json_whitespace(text, index)
  local i = index or 1
  while i <= #text and text:sub(i, i):match("%s") do
    i = i + 1
  end
  return i
end

local function find_json_string_end(text, start_index)
  local i = start_index + 1
  while i <= #text do
    local ch = text:sub(i, i)
    if ch == "\\" then
      i = i + 2
    elseif ch == '"' then
      return i
    else
      i = i + 1
    end
  end

  return nil
end

local function parse_top_level_json_string_field(text, object_key, field_key)
  local _, object_start = tostring(text or ""):find('"' .. object_key .. '"%s*:%s*{')
  if not object_start then
    return nil
  end

  local depth = 0
  local i = object_start
  while i <= #text do
    local ch = text:sub(i, i)

    if ch == '"' then
      local string_end = find_json_string_end(text, i)
      if not string_end then
        return nil
      end

      if depth == 1 then
        local key = text:sub(i + 1, string_end - 1)
        local cursor = skip_json_whitespace(text, string_end + 1)
        if text:sub(cursor, cursor) == ":" then
          cursor = skip_json_whitespace(text, cursor + 1)
          if key == field_key and text:sub(cursor, cursor) == '"' then
            local value_end = find_json_string_end(text, cursor)
            if not value_end then
              return nil
            end
            return text:sub(cursor + 1, value_end - 1)
          end
        end
      end

      i = string_end
    elseif ch == "{" then
      depth = depth + 1
    elseif ch == "}" then
      depth = depth - 1
      if depth == 0 then
        return nil
      end
    end

    i = i + 1
  end

  return nil
end

local function popup_state_from_query(query)
  local state = parse_top_level_json_string_field(tostring(query or ""), "popup", "drawing")
  if state == "on" then
    return true
  end
  if state == "off" then
    return false
  end
  return nil
end

local function popup_query_state()
  local query = capture("sketchybar --query " .. shell_quote(MAIN_ITEM) .. " 2>/dev/null")
  return popup_state_from_query(query)
end

local function select_output_command(device_name)
  return "SwitchAudioSource -t output -s " .. shell_quote(device_name) .. " >/dev/null 2>&1"
end

local function popup_is_open()
  local query_state = popup_query_state()
  if query_state ~= nil then
    file_write(popup_open_file, query_state and "1" or "0")
    return query_state
  end

  return file_read(popup_open_file) == "1"
end

if __VOLUME_TEST then
  return {
    color_env_prefix = color_env_prefix,
    plugin_command = plugin_command,
    popup_open_file = popup_open_file,
    popup_token_file = popup_token_file,
    popup_state_from_query = popup_state_from_query,
    popup_is_open = popup_is_open,
    select_output_command = select_output_command,
  }
end

local sbar = require("lib.sketchybar")
local audio = require("lib.audio_devices")

local function current_device()
  return capture("SwitchAudioSource -t output -c")
end

local function output_devices()
  local raw = capture("SwitchAudioSource -t output -a")
  return audio.parse_list(raw)
end

local function is_muted()
  return capture("osascript -e 'output muted of (get volume settings)'") == "true"
end

local function refresh_main_icon()
  local device = current_device()
  local icon = audio.icon_for_device(device)
  local color = is_muted() and muted_color or on_color
  sbar.set(MAIN_ITEM, { icon = icon, ["icon.color"] = color, drawing = "on" })
  popup_is_open()
end

local function hide_popup_rows()
  for i = 1, popup_slots do
    sbar.set(string.format("%s.%d", popup_prefix, i), { drawing = "off", label = "" })
  end
end

local function build_popup_rows()
  local devices = output_devices()
  local current = current_device()

  hide_popup_rows()

  for i = 1, math.min(#devices, popup_slots) do
    local name = devices[i]
    local selected = name == current
    local row = string.format("%s.%d", popup_prefix, i)
    local prefix = selected and "● " or "○ "

    sbar.set(row, {
      drawing = "on",
      label = prefix .. name,
      ["label.color"] = popup_text_color,
      click_script = plugin_command({ "--select", name }),
      ["background.drawing"] = "off",
      ["icon.drawing"] = "off",
    })
  end
end

local function fade_in()
  sh(string.format("sketchybar --animate sin 18 --set %q popup.drawing=on popup.background.alpha=0", MAIN_ITEM))
  sh(string.format("sketchybar --animate sin 18 --set %q popup.background.alpha=0xCC", MAIN_ITEM))
end

local function schedule_popup_hide(token)
  local script = table.concat({
    "sleep " .. popup_close_delay_seconds,
    string.format('test "$(cat %s 2>/dev/null)" = "0" || exit 0', shell_quote(popup_open_file)),
    string.format('test "$(cat %s 2>/dev/null)" = %s || exit 0', shell_quote(popup_token_file), shell_quote(token)),
    plugin_command({ "--finish-close", token }),
  }, "; ")
  spawn(script)
end

local function fade_out(token)
  sh(string.format("sketchybar --animate sin 18 --set %q popup.background.alpha=0", MAIN_ITEM))
  schedule_popup_hide(token)
end

local function open_popup_with_timeout()
  local token = tostring(os.time()) .. "." .. tostring(math.random(100000, 999999))
  file_write(popup_open_file, "1")
  file_write(popup_token_file, token)

  build_popup_rows()
  fade_in()

  local script = table.concat({
    "sleep " .. popup_timeout_seconds,
    string.format('test "$(cat %s 2>/dev/null)" = %s || exit 0', shell_quote(popup_token_file), shell_quote(token)),
    string.format('test "$(cat %s 2>/dev/null)" = "1" || exit 0', shell_quote(popup_open_file)),
    plugin_command({ "--timeout-close" }),
  }, "; ")
  spawn(script)
end

local function close_popup()
  local token = file_read(popup_token_file)
  file_write(popup_open_file, "0")
  fade_out(token)
end

local function finish_close(token)
  if token == "" then
    return
  end

  if file_read(popup_open_file) ~= "0" then
    return
  end

  if file_read(popup_token_file) ~= token then
    return
  end

  sh(string.format("sketchybar --set %q popup.drawing=off popup.background.alpha=0", MAIN_ITEM))
  hide_popup_rows()
end

local function switch_output(device_name)
  if device_name == "" or device_name == "__EMPTY__" then
    return
  end

  os.execute(select_output_command(device_name))
  refresh_main_icon()
  close_popup()
end

if mode == "--refresh" then
  refresh_main_icon()
elseif mode == "--toggle-popup" then
  if popup_is_open() then
    close_popup()
  else
    open_popup_with_timeout()
  end
elseif mode == "--select" then
  switch_output(arg2)
elseif mode == "--timeout-close" then
  if popup_is_open() then
    close_popup()
  end
elseif mode == "--finish-close" then
  finish_close(arg2)
else
  refresh_main_icon()
end
