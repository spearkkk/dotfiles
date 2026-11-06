local M = {}

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.read(path)
  local out = {}
  local f, _, errno = io.open(path, "r")
  if not f then
    if errno == 2 then return out end
    return nil, "policy_unreadable"
  end

  local contents = f:read("*a")
  f:close()
  if not contents then return nil, "policy_unreadable" end
  for line in (contents .. "\n"):gmatch("([^\n]*)\n") do
    local name = trim(line)
    if name ~= "" and name:sub(1, 1) ~= "#" then
      out[name] = true
    end
  end

  return out
end

return M
