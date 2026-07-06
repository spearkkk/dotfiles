local colors = require("helpers.colors")
local settings = require("helpers.settings")

local TOP_Y = settings.double_line_top_y
local BOTTOM_Y = settings.double_line_bottom_y
local TIME_SIZE = settings.text_size_large 
local DATE_SIZE = settings.text_size_small
local TIME_UPDATE_FREQ = settings.update_freq_fast
local DATE_UPDATE_FREQ = settings.update_freq_slow
local STACK_WIDTH = 54
local STACK_RIGHT_GAP = 8

-- Two items stacked on the same x-position.
local timestamp_time = Sbar.add("item", "timestamp_time", {
  position = "right",
  width = STACK_WIDTH,
  padding_right = STACK_RIGHT_GAP,
  y_offset = TOP_Y,
  update_freq = TIME_UPDATE_FREQ,
  icon = {
    drawing = false,
  },
  label = {
    drawing = true,
    align = "left",
    padding_left = 0,
    padding_right = 0,
    color = colors.foreground,
    font = {
      size = TIME_SIZE,
    },
  },
  background = {
    drawing = false,
  },
})

local timestamp_date = Sbar.add("item", "timestamp_date", {
  position = "right",
  width = STACK_WIDTH,
  padding_right = -STACK_WIDTH + STACK_RIGHT_GAP,
  y_offset = BOTTOM_Y,
  update_freq = DATE_UPDATE_FREQ,
  icon = {
    drawing = false,
  },
  label = {
    drawing = true,
    align = "left",
    padding_left = 0,
    padding_right = 2,
    color = colors.foreground,
    font = {
      size = DATE_SIZE,
    },
  },
  background = {
    drawing = false,
  },
})

local weekday_map = {
  ["Sun"] = "일",
  ["Mon"] = "월",
  ["Tue"] = "화",
  ["Wed"] = "수",
  ["Thu"] = "목",
  ["Fri"] = "금",
  ["Sat"] = "토",
}

local weekday_prefix = ""


local function update_date_context()
  local weekday_en = os.date("%a")
  local weekday_ko = weekday_map[weekday_en] or weekday_en
  weekday_prefix = weekday_ko .. " "
  timestamp_date:set({ label = "􀉉 " .. os.date("%Y-%m-%d") })
end

local function update_time()
  if weekday_prefix == "" then
    local weekday_en = os.date("%a")
    weekday_prefix = (weekday_map[weekday_en] or weekday_en) .. " "
  end
  local sec = tonumber(os.date("%S")) or 0
  local time_fmt = (sec % 2 == 0) and "%H:%M:%S" or "%H %M %S"
  timestamp_time:set({ label = weekday_prefix .. os.date(time_fmt) })
end

timestamp_time:subscribe({ "routine", "forced" }, update_time)
timestamp_date:subscribe({ "routine", "forced" }, update_date_context)

update_date_context()
update_time()
