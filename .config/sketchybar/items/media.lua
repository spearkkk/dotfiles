local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local NP_BIN = utils.capture("command -v nowplaying-cli 2>/dev/null")
local HAS_NOWPLAYING = NP_BIN ~= ""

local ITEM_LABEL = "media_label"
local ITEM_ICON = "media_icon"
local LABEL_WIDTH = 200
local SCROLL_WINDOW = 26
local SCROLL_SPACER = "    "
local BLOCKLIST_PATH = (os.getenv("HOME") or "") .. "/.config/sketchybar/media_monitor_blocklist"
local TICK_SECONDS = 1.2
local SCROLL_PAUSE_SECONDS = 12
local SCROLL_PAUSE_TICKS = math.floor(SCROLL_PAUSE_SECONDS / TICK_SECONDS + 0.5)
local META_REFRESH_EVERY = 1

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", [['"'"']]) .. "'"
end

local function capture(cmd)
  return utils.capture(cmd)
end

local function np_get(field)
  if not HAS_NOWPLAYING then
    return ""
  end
  local v = utils.capture(shell_quote(NP_BIN) .. " get " .. field .. " 2>/dev/null")
  if v == "null" or v == "(null)" then
    return ""
  end
  return v
end

local function apple_music_info()
  local state = utils.capture([[osascript -e 'tell application "Music" to if it is running then player state as string' 2>/dev/null]])
  if state == "" or state == "stopped" then
    return nil
  end
  local title = utils.capture([[osascript -e 'tell application "Music" to if it is running then name of current track as string' 2>/dev/null]])
  local artist = utils.capture([[osascript -e 'tell application "Music" to if it is running then artist of current track as string' 2>/dev/null]])
  if title == "" then
    return nil
  end
  return {
    title = title,
    artist = artist,
    playing = (state == "playing"),
  }
end

local function spotify_info()
  local state = utils.capture([[osascript -e 'tell application "Spotify" to if it is running then player state as string' 2>/dev/null]])
  if state == "" or state == "stopped" then
    return nil
  end
  local title = utils.capture([[osascript -e 'tell application "Spotify" to if it is running then name of current track as string' 2>/dev/null]])
  local artist = utils.capture([[osascript -e 'tell application "Spotify" to if it is running then artist of current track as string' 2>/dev/null]])
  if title == "" then
    return nil
  end
  return {
    title = title,
    artist = artist,
    playing = (state == "playing"),
  }
end

local function nowplaying_info()
  if HAS_NOWPLAYING then
    local title = np_get("title")
    local artist = np_get("artist")
    local rate = np_get("playbackRate")
    if title ~= "" then
      local rate_num = tonumber(rate) or 0
      return {
        title = title,
        artist = artist,
        playing = rate_num > 0,
      }
    end
  end

  local music = apple_music_info()
  if music then
    return music
  end

  local spotify = spotify_info()
  if spotify then
    return spotify
  end

  return nil
end

local function utf8_chars(s)
  local out = {}
  for _, cp in utf8.codes(s or "") do
    out[#out + 1] = utf8.char(cp)
  end
  return out
end

local function joined(chars)
  return table.concat(chars, "")
end

local function marquee_text(text, start_idx, width)
  local chars = utf8_chars(text)
  local n = #chars
  if n <= width then
    return text
  end

  local out = {}
  for i = 0, width - 1 do
    local idx = ((start_idx - 1 + i) % n) + 1
    out[#out + 1] = chars[idx]
  end
  return joined(out)
end

local function normalized_label(info)
  local title = tostring(info.title or "")
  local artist = tostring(info.artist or "")
  if artist ~= "" then
    return string.format("%s - %s", title, artist)
  end
  return title
end

local media_label = Sbar.add("item", ITEM_LABEL, {
  position = "right",
  width = LABEL_WIDTH,
  ["icon.drawing"] = false,
  ["label.align"] = "left",
  label = "",
  ["label.max_chars"] = 999,
  ["label.font.size"] = settings.label_size - 1,
  ["label.padding_left"] = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"] = false,
  update_freq = TICK_SECONDS,
})

local media_icon = Sbar.add("item", ITEM_ICON, {
  position = "right",
  icon = "􀱝",
  ["icon.font.size"] = settings.icon_size,
  ["icon.color"] = colors.base0b,
  ["icon.padding_left"] = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  ["label.drawing"] = false,
  ["background.drawing"] = false,
  drawing = false,
  update_freq = 0,
})

local meta_counter = 0
local scroll_index = 1
local scroll_pause_ticks = 0
local full_label = ""
local current_key = ""
local current_color = colors.base04
local scroll_source = ""
local scroll_len = 1
local last_label = ""
local last_color = ""
local last_visible = false
local is_playing = false
local paused_since = 0
local hide_for_small_display = false

local function rebuild_scroll_source()
  scroll_source = full_label .. SCROLL_SPACER
  scroll_len = #utf8_chars(scroll_source)
  if scroll_len < 1 then
    scroll_len = 1
  end
end

local function refresh_display_gate()
  local config_dir = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar")
  local target_id = capture(shell_quote(config_dir .. "/helpers/resolve_display.lua"))
  local blocklist = {}
  do
    local f = io.open(BLOCKLIST_PATH, "r")
    if f then
      for line in f:lines() do
        local name = (line or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and name:sub(1, 1) ~= "#" then
          blocklist[name] = true
        end
      end
      f:close()
    end
  end

  if target_id ~= "" then
    media_label:set({ display = target_id })
    media_icon:set({ display = target_id })
  else
    media_label:set({ display = "all" })
    media_icon:set({ display = "all" })
  end

  local target_name = ""
  if target_id ~= "" then
    local monitors = capture("aerospace list-monitors 2>/dev/null")
    for line in (monitors .. "\n"):gmatch("([^\n]*)\n") do
      local id, name = line:match("^%s*([^|]+)%s*|%s*(.-)%s*$")
      if id and name then
        id = id:gsub("%s+", "")
        if id == target_id then
          target_name = name
          break
        end
      end
    end
  end

  hide_for_small_display = (target_name ~= "" and blocklist[target_name] == true)
end

local function set_visible(visible)
  if last_visible == visible then
    return
  end
  media_label:set({ drawing = visible })
  media_icon:set({ drawing = visible and is_playing })
  last_visible = visible
end

local function refresh_meta()
  refresh_display_gate()
  local info = nowplaying_info()
  if not info or tostring(info.title or "") == "" then
    current_color = colors.base04
    full_label = ""
    current_key = "none"
    is_playing = false
    if paused_since == 0 then
      paused_since = os.time()
    end
    scroll_index = 1
    scroll_pause_ticks = 0
    rebuild_scroll_source()
    return
  end

  local key = table.concat({
    tostring(info.title or ""),
    tostring(info.artist or ""),
    tostring(info.playing or false),
  }, "|")
  if key ~= current_key then
    current_key = key
    scroll_index = 1
    scroll_pause_ticks = 0
  end

  is_playing = info.playing == true
  if is_playing then
    paused_since = 0
  elseif paused_since == 0 then
    paused_since = os.time()
  end

  current_color = is_playing and colors.foreground or colors.base04
  full_label = normalized_label(info)
  rebuild_scroll_source()
end

local function render_tick(force)
  local hidden = hide_for_small_display
    or (full_label == "")
    or ((not is_playing) and paused_since > 0 and ((os.time() - paused_since) >= 60))
  if hidden then
    set_visible(false)
    return
  end

  set_visible(true)
  media_icon:set({ drawing = is_playing })

  local shown
  if not is_playing then
    shown = marquee_text(scroll_source, 1, SCROLL_WINDOW)
  else
    if scroll_pause_ticks > 0 then
      scroll_pause_ticks = scroll_pause_ticks - 1
      shown = marquee_text(scroll_source, 1, SCROLL_WINDOW)
    else
      shown = marquee_text(scroll_source, scroll_index, SCROLL_WINDOW)
      scroll_index = scroll_index + 1
      if scroll_index > scroll_len then
        scroll_index = 1
        scroll_pause_ticks = SCROLL_PAUSE_TICKS
      end
    end
  end

  if force or shown ~= last_label or current_color ~= last_color then
    media_label:set({
      label = shown,
      ["label.color"] = current_color,
    })
    last_label = shown
    last_color = current_color
  end
end

local function toggle_play_pause()
  if HAS_NOWPLAYING then
    os.execute(shell_quote(NP_BIN) .. " togglePlayPause >/dev/null 2>&1")
    meta_counter = 0
    refresh_meta()
    render_tick(true)
  end
end

local function on_media_tick(_)
  if meta_counter <= 0 then
    refresh_meta()
    meta_counter = META_REFRESH_EVERY
  else
    meta_counter = meta_counter - 1
  end
  render_tick(false)
end

media_label:subscribe({ "routine", "forced", "system_woke", "display_change", "media_change" }, on_media_tick)

media_label:subscribe("mouse.clicked", function(_)
  toggle_play_pause()
end)

media_icon:subscribe("mouse.clicked", function(_)
  toggle_play_pause()
end)

refresh_meta()
render_tick(true)
