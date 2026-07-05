#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local theme = require("lib.theme")
local audio = require("lib.audio_devices")

local item = os.getenv("NAME") or "lua.volume"
local mode = arg[1] or "--refresh"
local arg2 = arg[2] or ""

local popup_open_file = "/tmp/sketchybar.volume.popup.open"
local popup_token_file = "/tmp/sketchybar.volume.popup.token"

local muted_color = os.getenv("VOLUME_MUTED_COLOR") or "0xFF4A6E86"
local on_color = os.getenv("VOLUME_ON_COLOR") or "0xFFC8AE6A"
local popup_text_color = os.getenv("VOLUME_LABEL_COLOR") or theme.colors.text_lightest

local popup_prefix = "lua.volume.device"
local popup_slots = 8

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
  sbar.set(item, { icon = icon, ["icon.color"] = color, drawing = "on" })
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
      click_script = string.format("%s/plugins/volume.lua --select %q", config_dir, name),
      ["background.drawing"] = "off",
      ["icon.drawing"] = "off",
    })
  end
end

local function fade_in()
  sh(string.format("sketchybar --animate sin 18 --set %q popup.drawing=on popup.background.alpha=0", item))
  sh(string.format("sketchybar --animate sin 18 --set %q popup.background.alpha=0xCC", item))
end

local function fade_out()
  sh(string.format("sketchybar --animate sin 18 --set %q popup.background.alpha=0", item))
  sh(string.format("sketchybar --set %q popup.drawing=off", item))
  hide_popup_rows()
end

local function open_popup_with_timeout()
  local token = tostring(os.time()) .. "." .. tostring(math.random(100000, 999999))
  file_write(popup_open_file, "1")
  file_write(popup_token_file, token)

  build_popup_rows()
  fade_in()

  local cmd = string.format(
    [[sh -c 'sleep 3; test "$(cat %s 2>/dev/null)" = "%s" || exit 0; test "$(cat %s 2>/dev/null)" = "1" || exit 0; %s/plugins/volume.lua --timeout-close >/dev/null 2>&1']],
    popup_token_file,
    token,
    popup_open_file,
    config_dir
  )
  os.execute(cmd)
end

local function close_popup()
  file_write(popup_open_file, "0")
  fade_out()
end

local function switch_output(device_name)
  if device_name == "" or device_name == "__EMPTY__" then
    return
  end

  os.execute(string.format("SwitchAudioSource -t output -s %q >/dev/null 2>&1", device_name))
  refresh_main_icon()
  close_popup()
end

if mode == "--refresh" then
  refresh_main_icon()
elseif mode == "--toggle-popup" then
  if file_read(popup_open_file) == "1" then
    close_popup()
  else
    open_popup_with_timeout()
  end
elseif mode == "--select" then
  switch_output(arg2)
elseif mode == "--timeout-close" then
  if file_read(popup_open_file) == "1" then
    close_popup()
  end
else
  refresh_main_icon()
end
