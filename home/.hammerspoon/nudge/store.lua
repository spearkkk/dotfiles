-- Persistence has no Hammerspoon dependency: all filesystem access is injected.
-- Adapters must create directories privately and clean their own partial writes.
-- Path checks are defense in depth, not a substitute for openat/O_NOFOLLOW against
-- a hostile same-UID process. Atomic rename is not a power-loss fsync guarantee.
local M = {}
local DIRECTORY_MODE, FILE_MODE = 448, 384 -- 0700, 0600
local CONFIG_LIMIT, SNAPSHOT_LIMIT = 65536, 8 * 1024 * 1024
local error_mt = { __tostring = function(value) return value.message end }

local function fail(message, code)
  error(setmetatable({code = code or "storage_error", message = message}, error_mt), 0)
end

local function checked(fn)
  local ok, result = pcall(fn)
  if not ok then
    if getmetatable(result) == error_mt then error(result, 0) end
    -- Never forward arbitrary adapter/codec exceptions, even structured ones.
    fail("Storage operation failed")
  end
  return result
end

local function invoke(fn, message, ...)
  local ok, result = pcall(fn, ...)
  if not ok then fail(message) end
  return result
end

function M.new(options)
  return checked(function()
    if type(options) ~= "table" then fail("Invalid storage options") end
    local root, fs, uid = options.root, options.fs, options.uid
    if type(root) ~= "string" or root:sub(1, 1) ~= "/" or root == "/"
      or root:sub(-1) == "/" or root:find("//", 1, true) or root:find("\0", 1, true) then
      fail("Storage root must be a canonical absolute path")
    end
    for part in root:gmatch("[^/]+") do
      if part == "." or part == ".." then fail("Storage root must be a canonical absolute path") end
    end
    if type(uid) ~= "number" or uid < 0 or uid % 1 ~= 0 or uid > 9007199254740991 then
      fail("Invalid storage owner")
    end
    if type(fs) ~= "table" then fail("Missing filesystem adapter") end
    for _, name in ipairs({ "attributes", "mkdir", "chmod", "read", "write_exclusive", "rename", "remove" }) do
      if type(fs[name]) ~= "function" then fail("Incomplete filesystem adapter") end
    end
    for _, name in ipairs({ "encode", "decode", "validate", "token" }) do
      if type(options[name]) ~= "function" then fail("Missing storage dependency") end
    end
    local encode, decode, validate, token = options.encode, options.decode, options.validate, options.token
    local parent = root:match("^(.*)/[^/]+$")
    if parent == "" then parent = "/" end
    local state_dir, active_path = root .. "/state", root .. "/state/active.json"
    local store = {}

    local function attributes(path)
      local ok, attr, err = pcall(fs.attributes, path, false)
      if ok and attr == nil and err == "missing" then return nil end
      if not ok or type(attr) ~= "table" then fail("Cannot inspect storage path safely") end
      return attr
    end

    local function directory(attr)
      if not attr or attr.mode ~= "directory" then fail("Storage directory is missing or not a real directory") end
      if attr.uid ~= uid then fail("Storage directory owner mismatch") end
      if attr.permissions ~= "rwx------" then fail("Storage directory permissions must be 0700") end
      if attr.has_acl ~= false then fail("Storage directory ACL must be absent and verifiable") end
    end

    local function file(attr, limit)
      if not attr or attr.mode ~= "file" then fail("Storage file is missing or not a regular file") end
      if attr.uid ~= uid then fail("Storage file owner mismatch") end
      if attr.permissions ~= "rw-------" then fail("Storage file permissions must be 0600") end
      if attr.has_acl ~= false then fail("Storage file ACL must be absent and verifiable") end
      if attr.nlink ~= 1 then fail("Storage file must have exactly one hard link") end
      if type(attr.size) ~= "number" or attr.size < 0 or attr.size % 1 ~= 0 then
        fail("Invalid storage file size metadata")
      end
      if attr.size > limit then fail("Storage file exceeds size limit") end
    end

    local function check_parent()
      -- Reject symlinks anywhere in the supplied path, including a symlink HOME.
      local path = ""
      local attr = attributes("/")
      if not attr or attr.mode ~= "directory" then fail("Unsafe storage ancestor") end
      for part in parent:gmatch("[^/]+") do
        path = path .. "/" .. part
        attr = attributes(path)
        if not attr or attr.mode ~= "directory" then fail("Unsafe storage ancestor") end
      end
      local mode = attr.permissions
      if attr.uid ~= uid or type(mode) ~= "string" or #mode ~= 9
        or not mode:match("^rwx[r%-]%-[x%-][r%-]%-[x%-]$") then
        fail("Storage parent must be owned and not writable by others")
      end
      -- HOME commonly has a noninheritable deny-delete ACL; keep that valid,
      -- but never create children when inherited access cannot be ruled out.
      if type(attr.has_acl) ~= "boolean" or attr.inheritable_acl ~= false then
        fail("Storage parent must have no inheritable ACL and verifiable ACL metadata")
      end
    end

    local function check_directories(with_state)
      check_parent()
      local attr = attributes(root)
      if not attr then return false end
      directory(attr)
      if with_state then
        attr = attributes(state_dir)
        if not attr then return false end
        directory(attr)
      end
      return true
    end

    local function ensure_directory(path)
      local attr = attributes(path)
      if attr then directory(attr); return end
      if invoke(fs.mkdir, "Cannot create storage directory", path) ~= true then fail("Cannot create storage directory") end
      attr = attributes(path)
      if not attr or attr.mode ~= "directory" or attr.uid ~= uid then fail("Unsafe new storage directory") end
      -- Only newly created directories may be chmod'ed; never silently repair others.
      if invoke(fs.chmod, "Cannot secure storage directory", path, DIRECTORY_MODE) ~= true then
        fail("Cannot secure storage directory")
      end
      directory(attributes(path))
    end

    local function read_file(path, limit, with_state)
      local before = attributes(path)
      if not before then return nil end
      file(before, limit)
      local raw = invoke(fs.read, "Cannot read storage file", path, limit)
      if type(raw) ~= "string" then fail("Cannot read storage file") end
      if #raw > limit then fail("Storage file exceeds size limit") end
      if #raw ~= before.size then fail("Storage file changed or read was incomplete") end
      if not check_directories(with_state) then fail("Storage directory disappeared during read") end
      local after = attributes(path)
      file(after, limit)
      if after.size ~= before.size then fail("Storage file changed during read") end
      return raw
    end

    local function snapshot(value)
      local validated = invoke(validate, "Invalid state snapshot", value)
      if type(validated) ~= "table" then fail("Invalid state snapshot") end
      return validated
    end

    function store:initialize()
      return checked(function()
        check_parent()
        ensure_directory(root)
        ensure_directory(state_dir)
        return true
      end)
    end

    function store:config()
      return checked(function()
        -- Startup reads configuration before creating any directories.
        if not check_directories(false) then return nil end
        local raw = read_file(root .. "/config.json", CONFIG_LIMIT, false)
        if raw == nil then return nil end
        local ok, value = pcall(decode, raw)
        if not ok then fail("Invalid configuration JSON", "config_error") end
        return value -- Configuration policy validation belongs to the service.
      end)
    end

    function store:load()
      return checked(function()
        local raw
        if check_directories(true) then raw = read_file(active_path, SNAPSHOT_LIMIT, true) end
        -- Decode the literal so even an empty active collection stays a JSON array.
        if raw == nil then raw = '{"version":1,"revision":0,"active":[]}' end
        return snapshot(invoke(decode, "Invalid snapshot JSON", raw))
      end)
    end

    function store:save(state)
      return checked(function()
        local temp, owned = nil, false
        local ok, result = pcall(function()
          local raw = invoke(encode, "Cannot encode state snapshot", snapshot(state))
          if type(raw) ~= "string" or #raw == 0 then fail("Cannot encode state snapshot") end
          if #raw > SNAPSHOT_LIMIT then fail("State snapshot exceeds size limit") end
          self:initialize()
          local previous = attributes(active_path)
          if previous then file(previous, SNAPSHOT_LIMIT) end
          local nonce = invoke(token, "Cannot generate temporary filename")
          if type(nonce) ~= "string" or #nonce == 0 or #nonce > 128 or not nonce:match("^[A-Za-z0-9_-]+$") then
            fail("Invalid temporary filename token")
          end
          temp = state_dir .. "/.active-" .. nonce .. ".tmp"
          if attributes(temp) then fail("Temporary snapshot already exists") end
          -- A failed exclusive create might be a collision: only the adapter can
          -- know whether it created a partial file and therefore owns its cleanup.
          if invoke(fs.write_exclusive, "Cannot write temporary snapshot", temp, raw, FILE_MODE) ~= true then
            fail("Cannot write temporary snapshot")
          end
          owned = true
          if not check_directories(true) then fail("Storage directory disappeared during save") end
          local written = attributes(temp)
          file(written, SNAPSHOT_LIMIT)
          if written.size ~= #raw then fail("Temporary snapshot write was incomplete") end
          previous = attributes(active_path)
          if previous then file(previous, SNAPSHOT_LIMIT) end
          if invoke(fs.rename, "Cannot atomically replace state snapshot", temp, active_path) ~= true then
            fail("Cannot atomically replace state snapshot")
          end
          owned = false -- No fallible work after the atomic commit point.
          return true
        end)
        if not ok then
          if owned then
            local cleaned = pcall(function()
              -- Never follow a replaced/unsafe directory just to clean up a temp.
              if not check_directories(true) then fail("Unsafe temporary snapshot cleanup") end
              if attributes(temp) and fs.remove(temp) ~= true then fail("Cannot remove temporary snapshot") end
            end)
            if not cleaned then fail("Snapshot save failed; temporary file cleanup failed") end
          end
          error(result, 0)
        end
        return result
      end)
    end

    return store
  end)
end

return M
