local M = {}

local function shell_quote(value)
  local s = tostring(value)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function run(cmd)
  return os.execute(cmd)
end

function M.capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return out
end

function M.set(item, props)
  local parts = { "sketchybar", "--set", shell_quote(item) }
  for k, v in pairs(props) do
    table.insert(parts, string.format("%s=%s", k, shell_quote(v)))
  end
  return run(table.concat(parts, " "))
end

return M
