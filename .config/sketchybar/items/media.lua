local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local ITEM_LABEL = "media_label"
local ITEM_ICON = "media_icon"
local ITEM_GROUP = "media_group"
local CACHE_TSV = "/tmp/sketchybar_media.tsv"
local REQUEST_FILE = "/tmp/sketchybar_media_refresh_request"
local LABEL_WIDTH = 200
local SCROLL_WINDOW = 26
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
local scroll_len = 1
local last_label = ""
local last_color = ""
local last_visible = false
local is_playing = false
local paused_since = 0
local routine_counter = 0

local function rebuild_scroll_source()
  scroll_source = full_label .. SCROLL_SPACER
  scroll_chars = utf8_chars(scroll_source)
  scroll_len = #scroll_chars
  if scroll_len < 1 then
    scroll_len = 1
    scroll_chars = { "" }
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
  if scroll_len <= width then
    return scroll_source
  end

  local out = {}
  for i = 0, width - 1 do
    local idx = ((start_idx - 1 + i) % scroll_len) + 1
    out[#out + 1] = scroll_chars[idx]
  end
  return joined(out)
end

local function render_tick(force)
  local hidden = (full_label == "")
    or ((not is_playing) and paused_since > 0 and ((os.time() - paused_since) >= 60))

  if hidden then
    set_visible(false)
    return
  end

  set_visible(true)
  media_icon:set({ drawing = is_playing })

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

local function on_media_tick(env)
  local sender = (env and env.SENDER) or ""
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

media_label:subscribe({ "routine", "forced", "system_woke", "media_change" }, on_media_tick)
media_label:subscribe("mouse.clicked", toggle_play_pause)
media_icon:subscribe("mouse.clicked", toggle_play_pause)

refresh_meta()
render_tick(true)
