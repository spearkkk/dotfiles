local icons = require("lib.icons")
local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")

local UPDATE_FREQ = 1

local function current_input_source()
  local out = utils.capture("defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null")
  if out == "" then
    return "en"
  end

  -- Common Korean IME ids on macOS
  if out:find("com.apple.inputmethod.Korean", 1, true)
      or out:find("2SetKorean", 1, true)
      or out:find("Korean", 1, true) then
    return "ko"
  end

  -- Common English layouts
  if out:find("com.apple.keylayout.ABC", 1, true)
      or out:find("com.apple.keylayout.US", 1, true)
      or out:find("U.S.", 1, true)
      or out:find("ABC", 1, true) then
    return "en"
  end

  return "en"
end

local input_source = Sbar.add("item", "input_source", {
  position = "right",
  width = settings.icon_cell_width,
  padding_left = settings.defaults.padding_left,
  padding_right = settings.defaults.padding_right,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = true,
    align = "center",
    color = colors.foreground,
    font = {
      size = settings.icon_size,
    },
    y_offset = 0,
    padding_left = settings.inner_padding,
    padding_right = settings.inner_padding,
  },
  label = {
    drawing = false,
  },
  background = {
    drawing = false,
  },
})

local function update_input_source()
  local src = current_input_source()
  input_source:set({
    icon = icons.abc,
    ["icon.font.size"] = 24,
    ["icon.color"] = src == "ko" and colors.base04 or colors.foreground,
  })
end

local function switch_input_source()
  local src = current_input_source()
  local target = (src == "ko") and "com.apple.keylayout.ABC" or "com.apple.inputmethod.Korean.2SetKorean"

  -- Prefer im-select for deterministic source switching.
  os.execute("im-select " .. target .. " >/dev/null 2>&1")

  os.execute("sleep 0.08")
  update_input_source()
end

input_source:subscribe({ "routine", "forced" }, update_input_source)
input_source:subscribe("mouse.clicked", function(_)
  switch_input_source()
end)

update_input_source()
