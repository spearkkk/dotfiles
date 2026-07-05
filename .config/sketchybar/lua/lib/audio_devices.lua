local M = {}

M.icons = {
  volume = "􀊩",
  headphones = "􀑪",
  display = "􀌆",
  speaker = "􀊣",
  media = "􀑨",
}

local ordered_patterns = {
  { { "airpods pro", "airpods max", "airpods" }, "headphones" },
  { { "headphone", "headset", "earphone", "buds" }, "headphones" },
  { { "monitor", "display", "hdmi", "dp", "usb%-c monitor" }, "display" },
  { { "macbook", "built%-in", "internal speakers" }, "speaker" },
  { { "apple tv", "homepod", " tv" }, "media" },
}

function M.normalize(name)
  return (name or ""):lower()
end

function M.parse_list(raw)
  local out = {}
  for line in (raw or ""):gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      out[#out + 1] = trimmed
    end
  end
  return out
end

function M.icon_for_device(name)
  local normalized = M.normalize(name)

  for _, entry in ipairs(ordered_patterns) do
    local patterns, icon_key = entry[1], entry[2]
    for _, pattern in ipairs(patterns) do
      if normalized:find(pattern) then
        return M.icons[icon_key]
      end
    end
  end

  return M.icons.volume
end

return M
