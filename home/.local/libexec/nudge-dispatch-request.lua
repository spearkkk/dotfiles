-- Fixed hs entry. _cli.args contains this file's path, then the JSON envelope.
-- Never compile or interpolate input as Lua, and never expose service errors.
local invalid = '{"ok":false,"exit_code":2,"error":"Missing IPC envelope."}'
local unavailable = '{"ok":false,"exit_code":4,"error":"Nudge service unavailable."}'
local args = type(_cli) == "table" and _cli.args
if type(args) ~= "table" or type(args[2]) ~= "string" or args[3] ~= nil then
  return invalid
end
local service = rawget(_G, "nudge")
if type(service) ~= "table" or type(service.handle_json) ~= "function" then
  return unavailable
end
local ok, response = pcall(service.handle_json, service, args[2])
if not ok or type(response) ~= "string" then
  return unavailable
end
return response
