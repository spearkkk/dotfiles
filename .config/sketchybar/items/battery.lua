local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local TOP_Y = settings.double_line_bottom_y
local BOTTOM_Y = settings.double_line_top_y
local ICON_SIZE = settings.text_size_small - 1
local PERCENT_SIZE = settings.text_size_large - 2
local UPDATE_FREQ = settings.update_freq_slow

local STACK_WIDTH = 16
local STACK_RIGHT_GAP = 0

local function battery_status()
  local batt = utils.capture("pmset -g batt")
  local pct = tonumber(batt:match("(%d+)%%") or "")
  if not pct then
    return nil, nil
  end

  local charging = batt:find("AC Power", 1, true) ~= nil

  local icon
  if charging then                 icon = "􀢋 "
  elseif pct >= 90 then            icon = "􀛨 "
  elseif pct >= 60 then            icon = "􀺸 "
  elseif pct >= 30 then            icon = "􀺶 "
  elseif pct >= 10 then            icon = "􀛩 "
  else                             icon = "􀛪 "
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

-- Top line: icon
local battery_icon = Sbar.add("item", "battery_icon", {
  position = "right",
  width = STACK_WIDTH,
  padding_left = 0,
  padding_right = STACK_RIGHT_GAP,
  y_offset = TOP_Y,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = true,
    align = "right",
    padding_right = 6,
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
})

-- Bottom line: xx%
local battery_percent = Sbar.add("item", "battery_percent", {
  position = "right",
  width = STACK_WIDTH,
  padding_left = 0,
  padding_right = -STACK_WIDTH + STACK_RIGHT_GAP,
  y_offset = BOTTOM_Y,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = false,
  },
  label = {
    drawing = true,
    align = "right",
    color = colors.foreground,
    font = {
      size = PERCENT_SIZE,
    },
  },
  background = {
    drawing = false,
  },
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

battery_icon:subscribe({ "routine", "forced", "system_woke", "power_source_change" }, update_battery)
battery_percent:subscribe({ "routine", "forced", "system_woke", "power_source_change" }, update_battery)
