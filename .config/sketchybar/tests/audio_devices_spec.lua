local function current_dir()
  local p = io.popen("pwd")
  if not p then
    return "."
  end

  local out = p:read("*a") or "."
  p:close()
  return (out:gsub("%s+$", ""))
end

local function normalize_path(path)
  local is_absolute = path:sub(1, 1) == "/"
  local parts = {}

  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #parts > 0 then
        table.remove(parts)
      end
    elseif part ~= "." and part ~= "" then
      parts[#parts + 1] = part
    end
  end

  local normalized = table.concat(parts, "/")
  if is_absolute then
    return "/" .. normalized
  end
  return normalized
end

local function resolve_script_path(argv0, source, cwd)
  local script_path = argv0 or ""
  if script_path == "" and source then
    script_path = source:gsub("^@", "")
  end

  if script_path == "" then
    return normalize_path((cwd or current_dir()) .. "/audio_devices_spec.lua")
  end

  if script_path:sub(1, 1) ~= "/" then
    script_path = normalize_path((cwd or current_dir()) .. "/" .. script_path)
  end

  return script_path
end

local function resolve_config_dir(argv0, source, cwd)
  local script_path = resolve_script_path(argv0, source, cwd)
  return (script_path:gsub("/tests/[^/]+$", ""))
end

local script_source = debug.getinfo(1, "S").source
local config_dir = resolve_config_dir(arg and arg[0], script_source, current_dir())

package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local audio = require("lib.audio_devices")

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected=%s actual=%s", label, tostring(expected), tostring(actual)))
  end
end

assert_eq(
  resolve_config_dir(config_dir .. "/tests/audio_devices_spec.lua", "@ignored", "/tmp"),
  config_dir,
  "resolve_config_dir absolute"
)

assert_eq(
  resolve_config_dir("tests/audio_devices_spec.lua", "@tests/audio_devices_spec.lua", config_dir),
  config_dir,
  "resolve_config_dir relative"
)

local list = audio.parse_list("MacBook Pro Speakers\nDELL U2720Q\nAirPods Pro\n")
assert_eq(#list, 3, "parse_list size")
assert_eq(list[1], "MacBook Pro Speakers", "parse_list[1]")

assert_eq(audio.icon_for_device("AirPods Pro"), audio.icons.headphones, "airpods icon")
assert_eq(audio.icon_for_device("DELL U2720Q HDMI"), audio.icons.display, "display icon")
assert_eq(audio.icon_for_device("MacBook Pro Speakers"), audio.icons.speaker, "speaker icon")
assert_eq(audio.icon_for_device("Unknown Device"), audio.icons.volume, "fallback icon")

local function load_volume_helpers(query_output, initial_files, env_overrides)
  local files = {}
  for path, value in pairs(initial_files or {}) do
    files[path] = value
  end

  local function fake_open(path, mode)
    if mode == "w" then
      local buffer = ""
      return {
        write = function(_, value)
          buffer = buffer .. (value or "")
        end,
        close = function()
          files[path] = buffer
        end,
      }
    end

    local value = files[path]
    if value == nil then
      return nil
    end

    return {
      read = function()
        return value
      end,
      close = function() end,
    }
  end

  local function fake_popen(_)
    return {
      read = function()
        return query_output or ""
      end,
      close = function() end,
    }
  end

  local env = setmetatable({
    __VOLUME_TEST = true,
    arg = {},
    io = { open = fake_open, popen = fake_popen },
    os = {
      getenv = function(name)
        if env_overrides and env_overrides[name] ~= nil then
          return env_overrides[name]
        end
        if name == "HOME" then
          return os.getenv("HOME")
        end
        if name == "CONFIG_DIR" then
          return config_dir
        end
        return nil
      end,
      execute = function()
        return true
      end,
      time = os.time,
    },
    package = { path = package.path },
  }, { __index = _G })

  local chunk, load_err = loadfile(config_dir .. "/plugins/volume.lua", "t", env)
  if not chunk then
    error(load_err)
  end

  local helpers = chunk()
  return helpers, files
end

local volume_helpers = assert(load_volume_helpers('{"popup":{"drawing":"on"}}', {}))
assert_eq(volume_helpers.popup_state_from_query('{"popup":{"drawing":"on"}}'), true, "popup query on")
assert_eq(volume_helpers.popup_state_from_query('{"popup":{"drawing":"off"}}'), false, "popup query off")
assert_eq(volume_helpers.popup_state_from_query('{"popup":{}}'), nil, "popup query unknown")
assert_eq(
  volume_helpers.popup_state_from_query([[
{
  "popup": {
    "background": {
      "drawing": "off"
    },
    "drawing": "on"
  }
}
]]),
  true,
  "popup query pretty json prefers popup drawing"
)

local stale_helpers, stale_files = load_volume_helpers('{"popup":{"drawing":"off"}}', {
  [volume_helpers.popup_open_file] = "1",
})
assert_eq(stale_helpers.popup_is_open(), false, "popup query overrides stale open flag")
assert_eq(stale_files[volume_helpers.popup_open_file], "0", "popup query syncs stale open flag")

local fallback_helpers = assert(load_volume_helpers("", {
  [volume_helpers.popup_open_file] = "1",
}))
assert_eq(fallback_helpers.popup_is_open(), true, "popup fallback uses open flag when query unavailable")

local env_helpers = assert(load_volume_helpers("", nil, {
  VOLUME_MUTED_COLOR = "0xFF112233",
  VOLUME_ON_COLOR = "0xFF445566",
  VOLUME_LABEL_COLOR = "0xFF778899",
}))
assert_eq(
  env_helpers.color_env_prefix,
  "VOLUME_MUTED_COLOR='0xFF112233' VOLUME_ON_COLOR='0xFF445566' VOLUME_LABEL_COLOR='0xFF778899'",
  "volume env prefix"
)
assert_eq(
  env_helpers.plugin_command({ "--select", "AirPods Pro" }),
  "VOLUME_MUTED_COLOR='0xFF112233' VOLUME_ON_COLOR='0xFF445566' VOLUME_LABEL_COLOR='0xFF778899' '" ..
    config_dir ..
    "/plugins/volume.lua' '--select' 'AirPods Pro'",
  "volume plugin command env prefix"
)
assert_eq(
  env_helpers.select_output_command("Office Speaker 'Main'"),
  "SwitchAudioSource -t output -s 'Office Speaker '\"'\"'Main'\"'\"'' >/dev/null 2>&1",
  "volume select command quoting"
)

print("ok: audio_devices_spec")
