local M = {}

local log_path = (os.getenv("HOME") or "") .. "/.sketchybar.log"

function M.log(msg)
  local f = io.open(log_path, "a")
  if not f then return end
  f:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), tostring(msg)))
  f:close()
end

function M.set_alpha(hex, percent)
  local h = tostring(hex or ""):gsub("^#", ""):gsub("^0[xX]", "")
  if #h == 8 then h = h:sub(-6) end  -- keep last 6 hex chars (strip alpha prefix)
  h = h:upper()
  if #h ~= 6 then h = "C6D8E4" end
  local p = math.max(0, math.min(100, tonumber(percent) or 100))
  local a = math.floor(p * 255 / 100)
  return string.format("0x%02X%s", a, h)
end

function M.capture(cmd)
  local p = io.popen(cmd)
  if not p then return "" end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

function M.icon_width(min, max, ratio, fallback)
  local ok, displays = pcall(function() return Sbar.query("displays") end)
  if not ok or type(displays) ~= "table" then return fallback end
  -- displays is keyed by string "1", "2", … for each display index
  local first = displays["1"] or displays[1]
  if type(first) ~= "table" then return fallback end
  local w = (first.bounds and first.bounds.w) or first.width
  if type(w) ~= "number" then return fallback end
  return math.max(min, math.min(max, math.floor(w * ratio)))
end

return M
