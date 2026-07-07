local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local ITEM_LABEL = "media_label"
local ITEM_ICON = "media_icon"
local ITEM_GROUP = "media_group"
local CACHE_TSV = "/tmp/sketchybar_media.tsv"
local REQUEST_FILE = "/tmp/sketchybar_media_refresh_request"
local BLOCKLIST_PATH = (os.getenv("HOME") or "") .. "/.config/sketchybar/media_monitor_blocklist"
local LABEL_WIDTH = 200
local SCROLL_WINDOW = 30
local SCROLL_SPACER = "    "
local TICK_SECONDS = 1.2
local SCROLL_PAUSE_SECONDS = 12
local SCROLL_PAUSE_TICKS = math.floor(SCROLL_PAUSE_SECONDS / TICK_SECONDS + 0.5)
local STALE_SECONDS = 30

local function executable(path)
  local f = io.open(path, "r")
  if not f then
    return false
  end
  f:close()
  return true
end

local NP_BIN = executable("/opt/homebrew/bin/nowplaying-cli")
  and "/opt/homebrew/bin/nowplaying-cli"
  or "/usr/local/bin/nowplaying-cli"

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", [['"'"']]) .. "'"
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

local function read_cache()
  local f = io.open(CACHE_TSV, "r")
  if not f then
    return nil
  end

  local line = f:read("*l") or ""
  f:close()

  local updated_at, ok, playing, title, artist = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
  updated_at = tonumber(updated_at) or 0
  if updated_at == 0 or (os.time() - updated_at) > STALE_SECONDS then
    return nil
  end

  if ok ~= "true" or title == "" then
    return nil
  end

  return {
    title = title or "",
    artist = artist or "",
    playing = playing == "true",
  }
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
  ["label.padding_left"] = 2,
  ["label.padding_right"] = 2,
  ["background.drawing"] = false,
  update_freq = TICK_SECONDS,
})

local media_icon = Sbar.add("item", ITEM_ICON, {
  position = "right",
  icon = "􀱝",
  ["icon.font.size"] = settings.icon_size,
  ["icon.color"] = colors.base0b,
  ["icon.padding_left"] = 2,
  ["icon.padding_right"] = 2,
  ["label.drawing"] = false,
  ["background.drawing"] = false,
  drawing = false,
  update_freq = 0,
})

local media_group = Sbar.add("bracket", ITEM_GROUP, { ITEM_ICON, ITEM_LABEL }, {
  drawing = false,
  ["background.drawing"] = true,
  ["background.color"] = colors.background_alt,
  ["background.height"] = settings.defaults.bg_height + 4,
  ["background.corner_radius"] = settings.defaults.corner_radius,
  ["background.border_width"] = 3,
  ["background.border_color"] = utils.set_alpha(colors.base04, 90),
  ["background.y_offset"] = settings.defaults.bg_y_offset,
})

Sbar.add("event", "media_change")

local scroll_index = 1
local scroll_pause_ticks = 0
local full_label = ""
local current_key = ""
local current_color = colors.base04
local scroll_source = ""
local scroll_chars = {}
local scroll_width = 1
local last_label = ""
local last_color = ""
local last_visible = false
local is_playing = false
local paused_since = 0
local routine_counter = 0
local hide_for_blocked_display = false

local function read_blocklist()
  local out = {}
  local f = io.open(BLOCKLIST_PATH, "r")
  if not f then
    return out
  end
  for line in f:lines() do
    local name = (line or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name ~= "" and name:sub(1, 1) ~= "#" then
      out[name] = true
    end
  end
  f:close()
  return out
end

local monitor_blocklist = read_blocklist()

local function rebuild_scroll_source()
  scroll_source = full_label .. SCROLL_SPACER
  scroll_chars = {}
  scroll_width = 0
  for _, cp in utf8.codes(scroll_source) do
    local ch = utf8.char(cp)
    local w = (cp < 128) and 1 or 2
    scroll_chars[#scroll_chars + 1] = { ch = ch, w = w }
    scroll_width = scroll_width + w
  end
  if #scroll_chars < 1 then
    scroll_chars = { { ch = "", w = 1 } }
    scroll_width = 1
  end
end

local function set_visible(visible)
  if last_visible == visible then
    return
  end
  media_label:set({ drawing = visible })
  media_icon:set({ drawing = visible and is_playing })
  media_group:set({ drawing = visible })
  last_visible = visible
end

local function capture(cmd)
  return utils.capture(cmd)
end

local function refresh_display_gate()
  local config_dir = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar")
  local target_id = capture(shell_quote(config_dir .. "/helpers/resolve_display.lua"))

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

  hide_for_blocked_display = (target_name ~= "" and monitor_blocklist[target_name] == true)
end

local function refresh_meta()
  local info = read_cache()
  if not info then
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

local function marquee_cached(start_idx, width)
  if scroll_width <= width then
    return scroll_source
  end

  local out = {}
  local used = 0
  local i = start_idx
  local n = #scroll_chars
  while used < width and n > 0 do
    local idx = ((i - 1) % n) + 1
    local cell = scroll_chars[idx]
    if used > 0 and (used + cell.w) > width then
      break
    end
    out[#out + 1] = cell.ch
    used = used + cell.w
    i = i + 1
  end
  return joined(out)
end

local function render_tick(force)
  local hidden = hide_for_blocked_display
    or (full_label == "")
    or ((not is_playing) and paused_since > 0 and ((os.time() - paused_since) >= 60))

  if hidden then
    set_visible(false)
    return
  end

  local shown
  if not is_playing then
    shown = marquee_cached(1, SCROLL_WINDOW)
  else
    if scroll_pause_ticks > 0 then
      scroll_pause_ticks = scroll_pause_ticks - 1
      shown = marquee_cached(1, SCROLL_WINDOW)
    else
      shown = marquee_cached(scroll_index, SCROLL_WINDOW)
      scroll_index = scroll_index + 1
      if scroll_index > #scroll_chars then
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

  -- Make sure the first visible frame already uses the scroll-window-clamped label.
  set_visible(true)
  media_icon:set({ drawing = is_playing })
end

local function on_media_tick(env)
  local sender = (env and env.SENDER) or ""
  if sender == "display_change" or sender == "forced" or sender == "system_woke" then
    refresh_display_gate()
  end

  if sender == "media_change" or sender == "forced" or sender == "system_woke" then
    refresh_meta()
    render_tick(true)
    return
  end

  routine_counter = routine_counter + 1
  if routine_counter >= 5 then
    routine_counter = 0
    refresh_meta()
  end

  render_tick(false)
end

local function toggle_play_pause()
  if full_label ~= "" then
    is_playing = not is_playing
    current_color = is_playing and colors.foreground or colors.base04
    render_tick(true)
  end

  os.execute("("
    .. shell_quote(NP_BIN)
    .. " togglePlayPause >/dev/null 2>&1; touch "
    .. shell_quote(REQUEST_FILE)
    .. "; sketchybar --trigger media_change >/dev/null 2>&1"
    .. ") &")
end

media_label:subscribe({ "routine", "forced", "system_woke", "display_change", "media_change" }, on_media_tick)
media_label:subscribe("mouse.clicked", toggle_play_pause)
media_icon:subscribe("mouse.clicked", toggle_play_pause)

refresh_display_gate()
refresh_meta()
render_tick(true)
