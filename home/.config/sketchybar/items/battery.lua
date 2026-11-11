local icons = require("lib.icons")
local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")

local ICON_SIZE = 22
local UPDATE_FREQ = settings.update_freq_slow

local function battery_status()
  local batt = utils.capture("pmset -g batt")
  local pct = tonumber(batt:match("(%d+)%%") or "")
  if not pct then
    return nil, nil
  end

  local charging = batt:find("AC Power", 1, true) ~= nil

  local icon
  if charging then                 icon = icons.battery_vertical_charging
  elseif pct >= 90 then            icon = icons.battery_vertical_4
  elseif pct >= 60 then            icon = icons.battery_vertical_3
  elseif pct >= 30 then            icon = icons.battery_vertical_2
  elseif pct >= 5 then             icon = icons.battery_vertical_1
  else                             icon = icons.battery_vertical_exclamation
  end

  local color
  if pct > 50 then                 color = colors.base0b
  elseif pct > 20 then             color = colors.base09
  else                             color = colors.base08
  end

  return {
    pct = pct,
    icon = icon,
    color = color,
  }, charging
end

-- Centered icon
local battery_icon = Sbar.add("item", "battery_icon", {
  position = "right",
  -- Right-side items flow right-to-left: reduce the reserved width without
  -- moving the 22pt glyph, pulling preceding items four points closer.
  width = settings.icon_cell_width - 4,
  padding_left = settings.defaults.padding_left,
  padding_right = settings.defaults.padding_right,
  y_offset = 0,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = true,
    align = "center",
    y_offset = 0,
    padding_left = settings.inner_padding,
    padding_right = settings.inner_padding,
    color = colors.foreground,
    font = {
      size = ICON_SIZE,
    },
  },
  label = {
    drawing = false,
  },
  background = {
    drawing = false,
  },
  ["popup.height"] = 22,
  ["popup.align"] = "center",
  ["popup.y_offset"] = -4,
  ["popup.background.height"] = 20,
  ["popup.background.color"] = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_color"] = colors.border,
  ["popup.background.border_width"] = 2,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.drawing"] = true,
})

-- Percentage in the hover popup
local battery_percent = Sbar.add("item", "battery_percent", {
  position = "popup.battery_icon",
  icon = { drawing = false },
  label = {
    drawing = true,
    color = colors.foreground,
    font = { size = 12 },
    padding_left = settings.inner_padding,
    padding_right = settings.inner_padding,
  },
  background = { drawing = false },
})


local function update_battery()
  local st = battery_status()
  if not st then
    return
  end

  battery_icon:set({
    icon = st.icon,
    ["icon.color"] = st.color,
  })

  battery_percent:set({
    label = string.format("%d%%", st.pct),
    ["label.color"] = colors.foreground,
  })
end

update_battery()

battery_icon:subscribe("mouse.entered", function()
  battery_icon:set({ ["popup.drawing"] = true })
end)
battery_icon:subscribe("mouse.exited", function()
  battery_icon:set({ ["popup.drawing"] = false })
end)

battery_icon:subscribe({ "routine", "forced", "system_woke", "power_source_change" }, update_battery)
