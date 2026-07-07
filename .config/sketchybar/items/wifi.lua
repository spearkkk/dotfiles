local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local ITEM = "wifi"
local IFACE = "en0"
local UPDATE_FREQ = 30

local function wifi_connected()
  local out = utils.capture("ifconfig " .. IFACE .. " 2>/dev/null")
  return out:find("status:%s*active") ~= nil and out:find("\n%s*inet%s+") ~= nil
end

local wifi = Sbar.add("item", ITEM, {
  position = "right",
  icon = "􀙈",
  ["icon.font.size"] = settings.icon_size,
  ["icon.padding_left"] = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  ["label.drawing"] = false,
  ["background.drawing"] = false,
  drawing = false,
  update_freq = UPDATE_FREQ,
})

local function update_wifi()
  local connected = wifi_connected()
  wifi:set({
    drawing = not connected,
    ["icon.color"] = colors.base04,
  })
end

update_wifi()

wifi:subscribe({ "routine", "forced", "system_woke", "wifi_change" }, update_wifi)
