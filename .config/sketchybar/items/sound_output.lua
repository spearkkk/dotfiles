local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local ITEM = "sound_output"
local POPUP_SLOTS = 12
local POPUP_TIMEOUT_SECONDS = 5
local UPDATE_FREQ = 5
local SA_BIN = utils.capture("command -v SwitchAudioSource 2>/dev/null")
if SA_BIN == "" then
  SA_BIN = "/opt/homebrew/bin/SwitchAudioSource"
end

local popup_open = false
local popup_deadline = 0
local row_devices = {}
local row_items = {}

local DEVICE_PRESETS = {
  {
    key = "sony_xm5",
    match = { "wh-1000xm5", "xm5", "sony" },
    icon = "􀑈",
    popup = true,
  },
  {
    key = "airpods",
    match = { "airpods" },
    icon = "􁄡",
    popup = true,
  },
  {
    key = "lg_hdr_4k",
    match = { "lg hdr 4k", "lg hdr", "lg" },
    icon = "􀫑",
    popup = true,
  },
  {
    key = "macbook_pro",
    match = { "macbook pro", "macbook", "built-in", "internal" },
    icon = "􀊦",
    popup = false,
  },
}

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", [['"'"']]) .. "'"
end

local function parse_lines(raw)
  local out = {}
  for line in (raw or ""):gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      out[#out + 1] = trimmed
    end
  end
  return out
end

local function current_output_device()
  return utils.capture(shell_quote(SA_BIN) .. " -t output -c 2>/dev/null")
end

local function output_devices()
  return parse_lines(utils.capture(shell_quote(SA_BIN) .. " -t output -a 2>/dev/null"))
end

local function output_state()
  local raw = utils.capture(
    "osascript -e 'set v to get volume settings' -e 'return (output volume of v as text) & \",\" & (output muted of v as text)' 2>/dev/null"
  )
  local vol_s, muted_s = raw:match("([^,]+),([^,]+)")
  local v = tonumber((vol_s or ""):match("%d+")) or 0
  if v < 0 then v = 0 end
  if v > 100 then v = 100 end
  local muted = (muted_s or ""):gsub("%s+", "") == "true"
  return math.floor(v), muted
end

local function set_output_device(name)
  if not name or name == "" then
    return
  end
  os.execute(shell_quote(SA_BIN) .. " -t output -s " .. shell_quote(name) .. " >/dev/null 2>&1")
end

local function preset_for_device(name)
  local n = (name or ""):lower()
  for _, preset in ipairs(DEVICE_PRESETS) do
    for _, token in ipairs(preset.match) do
      if n:find(token, 1, true) then
        return preset
      end
    end
  end
  return nil
end

local function device_icon(name)
  local preset = preset_for_device(name)
  if preset then
    return preset.icon
  end
  return "􀊩"
end

local function volume_icon(vol, muted)
  if muted then
    return "􀊢"
  end
  local v = tonumber(vol) or 0
  if v <= 33 then
    return "􀊤"
  elseif v <= 66 then
    return "􀊦"
  end
  return "􀊨"
end

local sound_output = Sbar.add("item", ITEM, {
  position                = "right",
  icon                    = "􀊩",
  ["icon.font.size"]     = settings.icon_size,
  ["icon.padding_left"]  = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  ["label.drawing"]      = false,
  ["background.drawing"] = false,
  ["popup.align"]        = "right",
  ["popup.height"]       = 22,
  ["popup.background.drawing"] = true,
  ["popup.background.color"] = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_width"] = 0,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.alpha"] = "0xCC",
  update_freq             = UPDATE_FREQ,
})

for i = 1, POPUP_SLOTS do
  local name = string.format("%s.device.%d", ITEM, i)
  row_items[i] = Sbar.add("item", name, {
    position = "popup." .. ITEM,
    drawing = false,
    click_script = "",
    icon = {
      drawing = true,
      color = colors.base04,
      font = { size = settings.icon_size },
      padding_left = settings.inner_padding + 4,
      padding_right = settings.inner_padding + 8,
    },
    label = {
      drawing = true,
      color = colors.base05,
      font = { size = settings.label_size - 1 },
      padding_left = 0,
      padding_right = settings.inner_padding,
    },
    background = { drawing = false },
  })

end

local function hide_rows()
  for i = 1, POPUP_SLOTS do
    row_devices[i] = nil
    row_items[i]:set({ drawing = false, icon = "" })
  end
end

local function popup_devices()
  local devices = output_devices()
  local filtered, seen = {}, {}

  for _, dev in ipairs(devices) do
    local key = dev:lower()
    if not seen[key] then
      seen[key] = true
      filtered[#filtered + 1] = dev
    end
  end

  return filtered
end

local function rebuild_popup()
  hide_rows()

  local devices = popup_devices()
  local current = current_output_device()

  for i = 1, math.min(#devices, POPUP_SLOTS) do
    local dev = devices[i]
    row_devices[i] = dev
    local selected = (dev == current)
    row_items[i]:set({
      drawing = true,
      icon = device_icon(dev),
      label = dev,
      ["icon.color"] = selected and colors.foreground or colors.base04,
      ["label.color"] = selected and colors.foreground or colors.base05,
      click_script = shell_quote(SA_BIN) .. " -t output -s " .. shell_quote(dev)
        .. " >/dev/null 2>&1; sketchybar --set " .. ITEM .. " popup.drawing=off; sketchybar --trigger forced",
    })
  end
end

local function refresh_main()
  local dev = current_output_device()
  local vol, muted = output_state()

  local preset = preset_for_device(dev)
  local is_internal = preset and preset.key == "macbook_pro"

  local icon = is_internal and volume_icon(vol, muted) or device_icon(dev)
  local color = muted and colors.base04 or colors.foreground

  sound_output:set({
    icon = icon,
    ["icon.color"] = color,
  })
end

local function fade_in_popup()
  os.execute(string.format("sketchybar --animate sin 18 --set %q popup.drawing=on popup.background.alpha=0", ITEM))
  os.execute(string.format("sketchybar --animate sin 18 --set %q popup.background.alpha=0xCC", ITEM))
end

local function open_popup()
  popup_open = true
  popup_deadline = os.time() + POPUP_TIMEOUT_SECONDS
  rebuild_popup()
  fade_in_popup()
end

local function close_popup()
  popup_open = false
  sound_output:set({ ["popup.drawing"] = false })
  hide_rows()
end

sound_output:subscribe("mouse.clicked", function(_)
  if popup_open then
    close_popup()
  else
    open_popup()
  end
end)

sound_output:subscribe({ "volume_change", "routine", "forced", "system_woke" }, function(_)
  refresh_main()

  if popup_open then
    if os.time() >= popup_deadline then
      close_popup()
    end
  end
end)

refresh_main()
