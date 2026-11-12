local icons = require("lib.icons")
local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")

local ITEM = "sound_output"
local UPDATE_FREQ = 10
local SA_BIN = utils.capture("command -v SwitchAudioSource 2>/dev/null")
if SA_BIN == "" then
  SA_BIN = "/opt/homebrew/bin/SwitchAudioSource"
end

local DEVICE_PRESETS = {
  {
    key = "sony_xm5",
    match = { "wh-1000xm5", "xm5", "sony" },
    icon = icons.headphones,
  },
  {
    key = "airpods",
    match = { "airpods" },
    icon = icons.device_airpods,
  },
  {
    key = "lg_hdr_4k",
    match = { "lg hdr 4k", "lg hdr", "lg" },
    icon = icons.device_desktop,
  },
  {
    key = "macbook_pro",
    match = { "macbook pro", "macbook", "built-in", "internal" },
    icon = icons.device_laptop,
  },
}


local function current_output_device()
  return utils.capture(utils.shell_quote(SA_BIN) .. " -t output -c 2>/dev/null")
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
  return icons.volume
end

local sound_output = Sbar.add("item", ITEM, {
  position                = "right",
  width                   = settings.icon_cell_width,
  padding_left            = settings.defaults.padding_left,
  padding_right           = settings.defaults.padding_right,
  icon                    = icons.volume,
  ["icon.align"]         = "center",
  ["icon.font.size"]     = settings.icon_size,
  ["icon.padding_left"]  = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  ["label.drawing"]      = false,
  ["background.drawing"] = false,
  update_freq             = UPDATE_FREQ,
})

local function refresh_main()
  local dev = current_output_device()
  local _, muted = output_state()
  local icon = muted and icons.volume_off or device_icon(dev)
  local color = muted and colors.base04 or colors.foreground

  sound_output:set({
    icon = icon,
    ["icon.color"] = color,
  })
end

sound_output:subscribe({ "volume_change", "routine", "forced", "system_woke" }, function(_)
  refresh_main()
end)

refresh_main()
