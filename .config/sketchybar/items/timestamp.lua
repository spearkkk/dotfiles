local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local function update(time_item, date_item)
  local clock = utils.capture("TZ=Asia/Seoul date '+%H:%M:%S'")
  local date  = utils.capture("TZ=Asia/Seoul date '+%Y-%m-%d'")
  time_item:set({ label = clock })
  date_item:set({ label = date })
end

local timestamp_time = Sbar.add("item", "timestamp_time", "right", {
  ["icon.drawing"]       = false,
  ["label.padding_left"] = settings.inner_padding,
  ["background.drawing"] = false,
  update_freq            = 1,
})

local timestamp_date = Sbar.add("item", "timestamp_date", "right", {
  icon                    = "􀉉",
  ["icon.padding_right"]  = settings.inner_padding,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
})

Sbar.add("bracket", "timestamp_group", { "timestamp_time", "timestamp_date" }, {
  drawing                = true,
  ["background.color"]   = colors.background,
  ["background.drawing"] = true,
})

utils.log("timestamp: loaded")

timestamp_time:subscribe("routine", function(env)
  update(timestamp_time, timestamp_date)
end)
