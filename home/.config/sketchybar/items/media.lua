local icons = require("lib.icons")
local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")
local paths    = require("lib.paths")
local display  = require("lib.display")

local ITEM_LABEL = "media_label"
local ITEM_ICON = "media_icon"
local ITEM_GROUP = "media_group"
local CACHE_TSV = paths.media_tsv
local REQUEST_FILE = paths.media_refresh_request
local LABEL_WIDTH = 200
local SCROLL_WINDOW = 24
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
    return nil, "cache_missing"
  end

  local line = f:read("*l") or ""
  f:close()

  local updated_at, ok, playing, title, artist = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
  updated_at = tonumber(updated_at)
  if not updated_at or updated_at <= 0 or updated_at == math.huge
    or (ok ~= "true" and ok ~= "false")
    or (playing ~= "true" and playing ~= "false")
    or not utf8.len(title) or not utf8.len(artist) then
    return nil, "cache_invalid"
  end
  if (os.time() - updated_at) > STALE_SECONDS then
    return nil, "cache_stale"
  end
  if ok == "false" or title == "" then
    return nil, "no_media"
  end

  return {
    title = title or "",
    artist = artist or "",
    playing = playing == "true",
  }, "ready"
end

local function normalized_label(info)
  local title = tostring(info.title or "")
  local artist = tostring(info.artist or "")
  if artist ~= "" then
    return string.format("%s - %s", title, artist)
  end
  return title
end

-- Right-side items are inserted right-to-left; only reserve the gap while
-- the media widget is visible on the same displays.
local media_spacer = Sbar.add("item", "media_spacer", {
  position = "right",
  drawing = false,
  width = 8,
  padding_left = 0,
  padding_right = 0,
  ["icon.drawing"] = false,
  ["label.drawing"] = false,
  ["background.drawing"] = false,
})

local media_label = Sbar.add("item", ITEM_LABEL, {
  drawing = false,
  position = "right",
  width = LABEL_WIDTH,
  ["icon.drawing"] = false,
  ["label.align"] = "left",
  label = "",
  ["label.max_chars"] = SCROLL_WINDOW,
  ["label.font.size"] = settings.label_size - 1,
  ["label.padding_left"] = 2,
  ["label.padding_right"] = 2,
  ["background.drawing"] = false,
  update_freq = TICK_SECONDS,
})

local media_icon = Sbar.add("item", ITEM_ICON, {
  position = "right",
  width = settings.icon_cell_width,
  padding_left = settings.defaults.padding_left,
  padding_right = settings.defaults.padding_right,
  icon = icons.brand_spotify,
  ["icon.align"] = "center",
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
local last_rendered_key = nil
local last_color = ""
local last_visible = nil
local last_display = nil
local last_generation = nil
local is_playing = false
local paused_since = 0
local routine_counter = 0
local display_state = { status = "error", reason = "query_failed", allowed_ids = {}, generation = 0 }
local content_reason = "cache_missing"

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

local function apply_visibility(attrs)
  if last_visible == attrs.drawing and last_display == attrs.display
    and last_generation == display_state.generation then
    return
  end
  if not attrs.drawing then attrs["popup.drawing"] = false end
  media_spacer:set(attrs)
  media_label:set(attrs)
  media_icon:set(attrs)
  media_group:set(attrs)
  last_visible = attrs.drawing
  last_display = attrs.display
  last_generation = display_state.generation
end

local function refresh_meta()
  local info, reason = read_cache()
  content_reason = reason
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

local function render_tick(force, advance_scroll)
  local reason = content_reason
  if full_label ~= "" and not is_playing and paused_since > 0 and os.time() - paused_since >= 60 then
    reason = "paused_timeout"
  end
  local attrs = display.attributes(display_state, reason == "ready")
  display.log_visibility("media", display_state, reason, attrs.drawing)
  if not attrs.drawing then
    apply_visibility(attrs)
    return
  end

  local shown
  if advance_scroll == false then
    -- A display notification must neither consume a tick nor jump to the next frame.
    shown = last_rendered_key == current_key and last_label or marquee_cached(scroll_index, SCROLL_WINDOW)
  elseif not is_playing then
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

  last_rendered_key = current_key
  media_icon:set({ ["icon.color"] = is_playing and colors.base0b or current_color })

  -- Make sure the first visible frame already uses the scroll-window-clamped label.
  apply_visibility(attrs)
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
    .. utils.shell_quote(NP_BIN)
    .. " togglePlayPause >/dev/null 2>&1; touch "
    .. utils.shell_quote(REQUEST_FILE)
    .. "; sketchybar --trigger media_change >/dev/null 2>&1"
    .. ") &")
end

media_label:subscribe({ "routine", "forced", "system_woke", "media_change" }, on_media_tick)
media_label:subscribe("mouse.clicked", toggle_play_pause)
media_icon:subscribe("mouse.clicked", toggle_play_pause)

display.subscribe("media", function(state)
  display_state = state
  render_tick(false, false)
end)
refresh_meta()
render_tick(true)
