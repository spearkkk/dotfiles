-- Pure Lua JSON and input policy. Never include user data in diagnostics.
local M = {}
local object_mt, array_mt, null_mt = {}, {}, {}
M.null = setmetatable({}, null_mt)
-- Intake is limited separately, leaving room for snapshot/event wrappers.
local MAX_DEPTH, MAX_INPUT_DEPTH = 256, 128
local function fail(message) error(message, 0) end
local function json_error() fail("invalid JSON") end
local function value_error() fail("invalid JSON value") end

function M.object(value)
  if type(value) ~= "table" or value == M.null then value_error() end
  return setmetatable(value, object_mt)
end

function M.array(value)
  if type(value) ~= "table" or value == M.null then value_error() end
  return setmetatable(value, array_mt)
end

-- Reject overlong UTF8, surrogate scalars, truncated sequences, and > U+10FFFF.
local function valid_utf8(text)
  local i = 1
  while i <= #text do
    local a, b, c, d = text:byte(i, i + 3)
    local function continuation(n) return n and n >= 0x80 and n <= 0xbf end
    if a < 0x80 then i = i + 1
    elseif a >= 0xc2 and a <= 0xdf and continuation(b) then i = i + 2
    elseif a >= 0xe0 and a <= 0xef and continuation(b) and continuation(c)
      and (a ~= 0xe0 or b >= 0xa0) and (a ~= 0xed or b < 0xa0) then i = i + 3
    elseif a >= 0xf0 and a <= 0xf4 and continuation(b) and continuation(c) and continuation(d)
      and (a ~= 0xf0 or b >= 0x90) and (a ~= 0xf4 or b <= 0x8f) then i = i + 4
    else return false end
  end
  return true
end

local function utf8_scalar(n)
  if n < 0x80 then return string.char(n) end
  if n < 0x800 then return string.char(0xc0 + math.floor(n / 64), 0x80 + n % 64) end
  if n < 0x10000 then
    return string.char(0xe0 + math.floor(n / 4096), 0x80 + math.floor(n / 64) % 64, 0x80 + n % 64)
  end
  return string.char(0xf0 + math.floor(n / 262144), 0x80 + math.floor(n / 4096) % 64,
    0x80 + math.floor(n / 64) % 64, 0x80 + n % 64)
end

local function finite(n) return n == n and n ~= math.huge and n ~= -math.huge end

-- Decoding deliberately has no 64KiB limit: the store also uses this codec.
function M.decode(raw)
  if type(raw) ~= "string" or not valid_utf8(raw) then json_error() end
  local pos, length = 1, #raw
  local function skip() local _, finish = raw:find("^[ \t\r\n]*", pos); pos = finish + 1 end
  local escapes = {['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t'}
  local function hex4()
    local text = raw:sub(pos, pos + 3)
    if #text ~= 4 or text:find("[^0-9a-fA-F]") then json_error() end
    pos = pos + 4
    return tonumber(text, 16)
  end
  local function parse_string()
    pos = pos + 1
    local parts, start = {}, pos
    while pos <= length do
      local byte = raw:byte(pos)
      if byte == 34 then
        parts[#parts + 1] = raw:sub(start, pos - 1)
        pos = pos + 1
        return table.concat(parts)
      elseif byte == 92 then
        parts[#parts + 1] = raw:sub(start, pos - 1)
        pos = pos + 1
        local escaped = raw:sub(pos, pos)
        pos = pos + 1
        if escaped == "u" then
          local n = hex4()
          if n >= 0xd800 and n <= 0xdbff then
            if raw:sub(pos, pos + 1) ~= "\\u" then json_error() end
            pos = pos + 2
            local low = hex4()
            if low < 0xdc00 or low > 0xdfff then json_error() end
            n = 0x10000 + (n - 0xd800) * 1024 + low - 0xdc00
          elseif n >= 0xdc00 and n <= 0xdfff then json_error() end
          parts[#parts + 1] = utf8_scalar(n)
        elseif escapes[escaped] then parts[#parts + 1] = escapes[escaped]
        else json_error() end
        start = pos
      elseif byte < 32 then json_error()
      else pos = pos + 1 end
    end
    json_error()
  end
  local function digit() local b = raw:byte(pos); return b and b >= 48 and b <= 57 end
  local function parse_number()
    local start = pos
    if raw:sub(pos, pos) == "-" then pos = pos + 1 end
    if raw:sub(pos, pos) == "0" then pos = pos + 1
    else
      if not digit() then json_error() end
      repeat pos = pos + 1 until not digit()
    end
    if raw:sub(pos, pos) == "." then
      pos = pos + 1
      if not digit() then json_error() end
      repeat pos = pos + 1 until not digit()
    end
    if raw:sub(pos, pos):lower() == "e" then
      pos = pos + 1
      if raw:sub(pos, pos) == "+" or raw:sub(pos, pos) == "-" then pos = pos + 1 end
      if not digit() then json_error() end
      repeat pos = pos + 1 until not digit()
    end
    local n = tonumber(raw:sub(start, pos - 1))
    if not n or not finite(n) then json_error() end
    return n
  end
  local parse
  parse = function(depth)
    if depth > MAX_DEPTH then json_error() end
    skip()
    local char = raw:sub(pos, pos)
    if char == '"' then return parse_string() end
    if char == "{" or char == "[" then
      local object = char == "{"
      local result = object and M.object{} or M.array{}
      local close = object and "}" or "]"
      pos = pos + 1; skip()
      if raw:sub(pos, pos) == close then pos = pos + 1; return result end
      while true do
        local key
        if object then
          if raw:sub(pos, pos) ~= '"' then json_error() end
          key = parse_string(); skip()
          if result[key] ~= nil or raw:sub(pos, pos) ~= ":" then json_error() end
          pos = pos + 1
        else key = #result + 1 end
        result[key] = parse(depth + 1); skip()
        char = raw:sub(pos, pos); pos = pos + 1
        if char == close then return result end
        if char ~= "," then json_error() end
        skip()
      end
    end
    for text, value in pairs({["true"]=true, ["false"]=false, ["null"]=M.null}) do
      if raw:sub(pos, pos + #text - 1) == text then pos = pos + #text; return value end
    end
    if char == "-" or digit() then return parse_number() end
    json_error()
  end
  local result = parse(0); skip()
  if pos <= length then json_error() end
  return result
end

local function kind(value)
  if value == M.null then return "null" end
  if type(value) ~= "table" then return type(value) end
  local mt = getmetatable(value)
  if mt == object_mt then return "object" end
  if mt == array_mt then return "array" end
  if mt ~= nil then value_error() end
  if next(value) == nil then return "object" end
  for key in pairs(value) do if type(key) ~= "number" then return "object" end end
  return "array"
end

-- Container classification without serializing payloads (snapshot validation).
M.kind = kind

local function quote(value)
  if not valid_utf8(value) then value_error() end
  return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
    if char == '"' then return '\\"' end
    if char == '\\' then return '\\\\' end
    return string.format("\\u%04x", char:byte())
  end) .. '"'
end

function M.encode(value)
  local visiting = {}
  local function encode(item, depth)
    if depth > MAX_DEPTH then value_error() end
    local k = kind(item)
    if k == "null" then return "null" end
    if k == "boolean" then return item and "true" or "false" end
    if k == "string" then return quote(item) end
    if k == "number" then
      if not finite(item) then value_error() end
      if math.type and math.type(item) == "integer" then return tostring(item) end
      return (string.format("%.17g", item):gsub(",", "."))
    end
    if k ~= "array" and k ~= "object" then value_error() end
    if visiting[item] then value_error() end
    visiting[item] = true
    local parts, keys = {}, {}
    for key in pairs(item) do keys[#keys + 1] = key end
    if k == "array" then
      local count = #keys
      for _, key in ipairs(keys) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then value_error() end
      end
      for i = 1, count do parts[i] = encode(item[i], depth + 1) end
    else
      for _, key in ipairs(keys) do if type(key) ~= "string" then value_error() end end
      table.sort(keys)
      for _, key in ipairs(keys) do parts[#parts + 1] = quote(key) .. ":" .. encode(item[key], depth + 1) end
    end
    visiting[item] = nil
    if k == "array" then return "[" .. table.concat(parts, ",") .. "]" end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return encode(value, 0)
end

function M.copy(value)
  -- Validate before recursing, including cycle/depth/UTF8 checks.
  M.encode(value)
  local function copy(item)
    if item == M.null or type(item) ~= "table" then return item end
    local result = kind(item) == "array" and M.array{} or M.object{}
    for key, child in pairs(item) do result[key] = copy(child) end
    return result
  end
  return copy(value)
end

function M.deepEqual(a, b)
  -- Validate JSON first, then compare values rather than number spellings.
  M.encode(a); M.encode(b)
  local function equal(left, right)
    local k = kind(left)
    if k ~= kind(right) then return false end
    if k ~= "array" and k ~= "object" then return left == right end
    for key, value in pairs(left) do
      if right[key] == nil or not equal(value, right[key]) then return false end
    end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
  end
  return equal(a, b)
end

local builtins = require("nudge.defaults")
local MAX_SAFE_INTEGER = 9007199254740991
local function invalid() fail("invalid request or configuration") end
local function object(value)
  if kind(value) ~= "object" then invalid() end
end
local function fields(value, allowed)
  object(value)
  for key in pairs(value) do if not allowed[key] then invalid() end end
end
local function text(value, nonempty)
  if type(value) ~= "string" or not valid_utf8(value) or (nonempty and #value == 0) then invalid() end
end
local function safe_integer(value)
  if type(value) ~= "number" or not finite(value) or value < 0 or value > MAX_SAFE_INTEGER or value % 1 ~= 0 then invalid() end
end
local function input_value(value)
  -- Only the transport/store knows original wire size. Re-encoding can expand
  -- escapes or change number spelling, so it must not impose a byte limit.
  M.encode(value)
  local function depth(item, level)
    if level > MAX_INPUT_DEPTH then fail("request or configuration nested too deeply") end
    if type(item) == "table" and item ~= M.null then
      for _, child in pairs(item) do depth(child, level + 1) end
    end
  end
  depth(value, 0)
end
local function version(value)
  if value ~= nil and value ~= 1 then invalid() end
end
local function severity(value)
  if value ~= "info" and value ~= "success" and value ~= "warning" and value ~= "error" then invalid() end
end
local function content(value)
  fields(value, {title=true,subtitle=true,body=true})
  for _, v in pairs(value) do text(v) end
end
local function policy(value, allow_preset)
  fields(value, {ttl_seconds=true,dedupe_seconds=true,preset=allow_preset})
  for key, v in pairs(value) do
    if key == "preset" then text(v, true) else safe_integer(v) end
  end
end
local function nonblank(value)
  text(value)
  local stripped = value:gsub("%s", "")
  -- Unicode White_Space in addition to the ASCII whitespace accepted by Lua.
  for _, cp in ipairs({0x85,0xa0,0x1680,0x2000,0x2001,0x2002,0x2003,0x2004,0x2005,
    0x2006,0x2007,0x2008,0x2009,0x200a,0x2028,0x2029,0x202f,0x205f,0x3000}) do
    stripped = stripped:gsub(utf8_scalar(cp), "")
  end
  if stripped == "" then invalid() end
end

local function sound(value)
  if value == false then return end
  fields(value, {name=true,file=true})
  if (value.name == nil) == (value.file == nil) then invalid() end
  local item = value.name or value.file
  nonblank(item)
  if item:find('\0',1,true) then invalid() end
  if value.file and value.file:sub(1,1) ~= '/' then invalid() end
end
local function fragment(value)
  fields(value, {severity=true,content=true,policy=true,sound=true})
  if value.severity ~= nil then severity(value.severity) end
  if value.content ~= nil then content(value.content) end
  if value.policy ~= nil then policy(value.policy, false) end
  if value.sound ~= nil then sound(value.sound) end
end
local function merge(base, overlay)
  local result = M.copy(base)
  for key, value in pairs(overlay) do
    if key ~= "sound" and kind(value) == "object" and kind(result[key]) == "object" then result[key] = merge(result[key], value)
    else result[key] = M.copy(value) end
  end
  return result
end

function M.config(input)
  local result = M.copy(builtins)
  if input == nil then return result end
  input_value(input)
  fields(input, {version=true,defaults=true,presets=true})
  version(input.version)
  if input.defaults ~= nil then
    fragment(input.defaults)
    result.defaults = merge(result.defaults, input.defaults)
  end
  if input.presets ~= nil then
    object(input.presets)
    for name, preset in pairs(input.presets) do
      text(name, true); fragment(preset)
      -- A user definition owns the entire preset, including builtin names.
      result.presets[name] = M.copy(preset)
    end
  end
  return result
end

-- Shared with snapshot validation: resolved values have no wire-size limit and
-- must remain valid after a named preset is changed or removed from config.
function M.validate_normalized(value)
  fields(value, {version=true,source=true,event=true,key=true,severity=true,content=true,context=true,policy=true,sound=true})
  if value.version ~= 1 then invalid() end
  text(value.source, true); text(value.event, true)
  if value.key ~= nil then text(value.key, true) end
  severity(value.severity)
  if value.sound ~= nil then sound(value.sound) end
  content(value.content); nonblank(value.content.title)
  policy(value.policy, true)
  safe_integer(value.policy.ttl_seconds); safe_integer(value.policy.dedupe_seconds)
  if value.context ~= nil then
    object(value.context)
    M.encode(value.context) -- Only context has arbitrary nested JSON values.
  end
  return value
end

function M.send(input, config)
  input_value(input)
  fields(input, {version=true,source=true,event=true,key=true,severity=true,content=true,context=true,policy=true,sound=true})
  version(input.version)
  for _, key in ipairs({"source", "event", "key"}) do if input[key] ~= nil then text(input[key], true) end end
  if input.severity ~= nil then severity(input.severity) end
  if input.content ~= nil then content(input.content) end
  if input.context ~= nil then object(input.context) end
  if input.policy ~= nil then policy(input.policy, true) end
  if input.sound ~= nil then sound(input.sound) end
  config = config or M.config(nil)
  local result = M.copy(config.defaults)
  local preset = input.policy and input.policy.preset
  if preset ~= nil then
    if config.presets[preset] == nil then invalid() end
    result = merge(result, config.presets[preset])
  end
  result = merge(result, input)
  result.version = 1
  result.source = result.source or "manual"
  result.event = result.event or "generic"
  nonblank(result.content.title)
  return result
end

function M.request(envelope, config)
  input_value(envelope)
  object(envelope)
  local op = envelope.operation
  if op == "send" then
    fields(envelope, {operation=true,request=true,request_json=true,raw_fields=true,dry_run=true})
    if envelope.dry_run ~= nil and type(envelope.dry_run) ~= "boolean" then invalid() end
    local input = envelope.request
    if envelope.request_json ~= nil then
      -- jq accepts some non-JSON tokens and repairs malformed Unicode. Keep
      -- original file/stdin bytes as a string until this strict boundary.
      if input ~= nil or envelope.raw_fields ~= nil then invalid() end
      text(envelope.request_json)
      if #envelope.request_json > 65536 then fail("request too large") end
      input = M.decode(envelope.request_json)
    elseif envelope.raw_fields ~= nil then
      object(input)
      fields(envelope.raw_fields, {version=true,context=true,
        ["policy.ttl_seconds"]=true,["policy.dedupe_seconds"]=true})
      input = M.copy(input)
      for key, raw in pairs(envelope.raw_fields) do
        text(raw)
        if #raw > 65536 then fail("request too large") end
        local target, name = input, key
        if key == "policy.ttl_seconds" or key == "policy.dedupe_seconds" then
          if input.policy == nil then input.policy = M.object{} end
          object(input.policy)
          target, name = input.policy, key:sub(8)
        end
        if target[name] ~= nil then invalid() end
        target[name] = M.decode(raw)
      end
    end
    local result = M.object{operation=op,request=M.send(input, config)}
    result.dry_run = envelope.dry_run
    return result
  elseif op == "list" then
    fields(envelope, {operation=true,source=true})
    if envelope.source ~= nil then text(envelope.source, true) end
  elseif op == "inspect" or op == "dismiss" then
    fields(envelope, {operation=true,id=true,source=true,key=true})
    if envelope.id ~= nil then
      text(envelope.id, true)
      if envelope.source ~= nil or envelope.key ~= nil then invalid() end
    else text(envelope.source, true); text(envelope.key, true) end
  elseif op == "doctor" or op == "capabilities" then fields(envelope, {operation=true})
  else invalid() end
  return M.copy(envelope)
end

return M
