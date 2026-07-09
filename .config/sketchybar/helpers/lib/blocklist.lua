local M = {}

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.read(path)
  local out = {}
  local f = io.open(path, "r")
  if not f then
    return out
  end

  for line in f:lines() do
    local name = trim(line)
    if name ~= "" and name:sub(1, 1) ~= "#" then
      out[name] = true
    end
  end

  f:close()
  return out
end

return M
