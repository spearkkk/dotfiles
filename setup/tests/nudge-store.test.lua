-- Run from the repository root: lua setup/tests/nudge-store.test.lua
-- Real macOS files, shell-backed metadata/creation (LuaFileSystem is not required).
local module_path = "home/.hammerspoon/nudge/store.lua"
local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok - " .. name)
  else
    failed = failed + 1
    io.stderr:write("not ok - " .. name .. ": " .. tostring(err) .. "\n")
  end
end
local Store
test("store exposes the agreed constructor", function()
  local ok, result = pcall(dofile, module_path)
  assert(ok and type(result) == "table" and type(result.new) == "function",
    "store module is not implemented")
  Store = result
end)
if not Store then os.exit(1) end

local function quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end
local function run(command)
  return os.execute("/bin/bash -c " .. quote(command) .. " >/dev/null 2>&1") == true
end
local function capture(command)
  local pipe = assert(io.popen("/bin/bash -c " .. quote(command) .. " 2>/dev/null", "r"))
  local data = pipe:read("*a")
  local ok = pipe:close()
  return ok and data or nil
end
local uid = assert(tonumber(capture("/usr/bin/id -u")))
local function filesystem()
  local fs = {}
  function fs.attributes(path, follow)
    assert(follow == false, "store must explicitly request no-follow metadata")
    local data = capture("/usr/bin/stat -f '%HT|%u|%Sp|%z|%l' " .. quote(path))
    if not data then
      if not run("test -e " .. quote(path) .. " || test -L " .. quote(path)) then
        return nil, "missing"
      end
      error("stat failed: fixture-private")
    end
    local acl = assert(capture("LC_ALL=C /bin/ls -lde " .. quote(path)), "ACL lookup failed")
    local has_acl, inheritable_acl = false, false
    for line in acl:gmatch("[^\n]+") do
      if line:match("^%s*%d+:") then
        has_acl = true
        if line:find("file_inherit", 1, true) or line:find("directory_inherit", 1, true) then inheritable_acl = true end
      end
    end
    local kind, owner, mode, size, links = data:match("([^|]+)|(%d+)|([^|]+)|(%d+)|(%d+)")
    return {
      mode = ({ Directory = "directory", ["Regular File"] = "file", ["Symbolic Link"] = "link" })[kind] or "other",
      uid = tonumber(owner), permissions = mode:sub(2), size = tonumber(size), nlink = tonumber(links),
      has_acl = has_acl, inheritable_acl = inheritable_acl,
    }
  end
  function fs.mkdir(path)
    return run("umask 077; /bin/mkdir " .. quote(path))
  end
  function fs.chmod(path, mode)
    return run("/bin/chmod " .. string.format("%o", mode) .. " " .. quote(path))
  end
  function fs.read(path, max_bytes)
    local file, err = io.open(path, "rb")
    if not file then return nil, err end
    local data, read_err = file:read(max_bytes + 1)
    if data == nil and read_err == nil then data = "" end -- clean EOF, including empty files
    local ok = file:close()
    if not ok or not data or #data > max_bytes then return nil, "read failed" end
    return data
  end
  function fs.write_exclusive(path, data, mode)
    assert(mode == 384, "exclusive snapshot files must be created with mode 0600")
    if not run("umask 077; set -o noclobber; : > " .. quote(path)) then return nil, "exists" end
    local file, err = io.open(path, "wb")
    if not file then os.remove(path); return nil, err end
    local ok, write_err = file:write(data)
    local closed, close_err = file:close()
    if not ok or not closed then os.remove(path); return nil, write_err or close_err end
    return true
  end
  fs.rename = os.rename
  fs.remove = os.remove
  return fs
end

package.path = "home/.hammerspoon/?.lua;home/.hammerspoon/?/init.lua;" .. package.path
local contract = require("nudge.contract")
local core = require("nudge.core")
local dependencies = { encode = contract.encode, decode = contract.decode, validate = core.validate }
local function fixture(fn)
  local base = assert(capture("/usr/bin/mktemp -d /private/tmp/nudge-store.XXXXXXXX")):gsub("\n$", "")
  assert(base:match("^/private/tmp/nudge%-store%.[%w]+$"))
  local fs = filesystem()
  local root = base .. "/.nudge"
  local serial = 0
  local function new(overrides)
    local options = {
      root = root, fs = fs, uid = uid,
      encode = dependencies.encode, decode = dependencies.decode, validate = dependencies.validate,
      token = function() serial = serial + 1; return "token-" .. serial end,
    }
    for key, value in pairs(overrides or {}) do options[key] = value end
    return Store.new(options)
  end
  local ok, err = pcall(fn, { base = base, root = root, fs = fs, new = new })
  assert(run("/bin/rm -rf " .. quote(base)), "could not clean temporary test directory")
  if not ok then error(err, 0) end
end
local function rejects(fn, code)
  local ok, err = pcall(fn)
  assert(not ok, "unsafe operation unexpectedly succeeded")
  assert(type(err) == "table" and err.code == (code or "storage_error"), "wrong error classification")
  local message = err.message
  assert(type(message) == "string" and #message > 0, "missing safe diagnostic")
  assert(not message:find("fixture-private", 1, true), "error exposed dependency details")
  assert(not message:find("/private/tmp", 1, true), "error exposed a filesystem path")
end
local function attrs(f, path) return f.fs.attributes(path, false) end
local function write(f, path, data, mode)
  local file = assert(io.open(path, "wb"))
  assert(file:write(data)); assert(file:close())
  assert(f.fs.chmod(path, mode or 384))
end

test("initialize creates only private root and state directories", function()
  fixture(function(f)
    assert(f.new():initialize())
    assert(attrs(f, f.root).permissions == "rwx------")
    assert(attrs(f, f.root .. "/state").permissions == "rwx------")
    assert(attrs(f, f.root).uid == uid)
    assert(attrs(f, f.root .. "/state/active.json") == nil)
    assert(attrs(f, f.root .. "/config.json") == nil)
    assert(f.new():initialize())
  end)
end)

test("config before initialize returns nil without creating directories", function()
  fixture(function(f)
    assert(f.new():config() == nil)
    assert(attrs(f, f.root) == nil)
  end)
end)

for _, relative in ipairs({ "", "/state" }) do
  test("initialize refuses preexisting permissive directory " .. relative, function()
    fixture(function(f)
      assert(f.fs.mkdir(f.root))
      if relative ~= "" then assert(f.fs.mkdir(f.root .. relative)) end
      assert(f.fs.chmod(f.root .. relative, 493)) -- 0755
      rejects(function() f.new():initialize() end)
      assert(attrs(f, f.root .. relative).permissions == "rwxr-xr-x", "must not repair existing permissions")
    end)
  end)
end

for _, relative in ipairs({ "", "/state" }) do
  test("initialize refuses symlink directory " .. relative, function()
    fixture(function(f)
      local target = f.base .. "/target"
      assert(f.fs.mkdir(target))
      if relative ~= "" then assert(f.fs.mkdir(f.root)) end
      assert(run("/bin/ln -s " .. quote(target) .. " " .. quote(f.root .. relative)))
      rejects(function() f.new():initialize() end)
      assert(attrs(f, target .. "/state") == nil)
    end)
  end)
end

test("initialize rejects a foreign owner", function()
  fixture(function(f)
    assert(f.fs.mkdir(f.root))
    local original = f.fs.attributes
    f.fs.attributes = function(path, follow)
      local metadata, err = original(path, follow)
      if path == f.root and metadata then metadata.uid = uid + 1 end
      return metadata, err
    end
    rejects(function() f.new():initialize() end)
    assert(attrs(f, f.root .. "/state") == nil)
  end)
end)

test("metadata failures are not treated as absent files", function()
  fixture(function(f)
    local original = f.fs.attributes
    f.fs.attributes = function(path, follow)
      if path == f.root then return nil, "fixture-private" end
      return original(path, follow)
    end
    rejects(function() f.new():config() end)
    rejects(function() f.new():initialize() end)
  end)
end)

test("failed chmod stops before creating child directories", function()
  fixture(function(f)
    f.fs.chmod = function() return nil, "fixture-private" end
    rejects(function() f.new():initialize() end)
    assert(attrs(f, f.root .. "/state") == nil)
  end)
end)

test("unsafe HOME permissions and symlinks are rejected", function()
  fixture(function(f)
    assert(f.fs.chmod(f.base, 511)) -- 0777
    rejects(function() f.new():initialize() end)
    assert(attrs(f, f.root) == nil)
    assert(f.fs.chmod(f.base, 448))
    local home = f.base .. "/home"
    assert(run("/bin/ln -s " .. quote(f.base) .. " " .. quote(home)))
    rejects(function() f.new({ root = home .. "/.nudge" }):initialize() end)
  end)
end)

test("invalid paths and missing security dependencies fail closed", function()
  fixture(function(f)
    for _, root in ipairs({ "relative", "/", f.base .. "/../escape", f.root .. "/./x", f.root .. "\0x" }) do
      rejects(function() f.new({ root = root }):initialize() end)
    end
    rejects(function() f.new({ uid = -1 }):initialize() end)
    local broken = filesystem(); broken.attributes = nil
    rejects(function() f.new({ fs = broken }):initialize() end)
  end)
end)


local function read(f, path) return assert(f.fs.read(path, 9 * 1024 * 1024)) end
local function entries(f)
  return assert(capture("/usr/bin/find " .. quote(f.root .. "/state") .. " -mindepth 1 -maxdepth 1 -print"))
end
local function no_temps(f)
  assert(entries(f) == f.root .. "/state/active.json\n", "unexpected temporary file left behind")
end
local function snapshot()
  -- Literal normalized records, not expectations generated by the implementation.
  return contract.decode([[{"version":1,"revision":7,"active":[
    {"version":1,"source":"manual","event":"generic","key":"job","severity":"info",
     "content":{"title":"fixture-private","body":"plain <text> 한글"},
     "context":{"empty_object":{},"empty_array":[],"nested":[null,false,{}]},
     "policy":{"ttl_seconds":0,"dedupe_seconds":10},"id":"first","created_at":1000,"updated_at":2000},
    {"version":1,"source":"timer","event":"generic","severity":"success",
     "content":{"title":"Second"},"policy":{"ttl_seconds":5,"dedupe_seconds":0,"preset":"custom-old"},
     "id":"second","created_at":1000,"updated_at":3000,"expires_at":8000}
  ]}]])
end
local function seeded(f)
  local store = f.new()
  assert(store:initialize())
  local value = snapshot()
  assert(store:save(value))
  return store, value, read(f, f.root .. "/state/active.json")
end

test("config reads JSON before initialization without creating state", function()
  fixture(function(f)
    assert(f.fs.mkdir(f.root))
    write(f, f.root .. "/config.json", '{"version":1,"defaults":{"content":{"title":"fixture-private"}},"presets":{}}')
    local config = f.new():config()
    assert(config.defaults.content.title == "fixture-private")
    assert(contract.encode(config.presets) == "{}")
    assert(attrs(f, f.root .. "/state") == nil)
  end)
end)

test("malformed config is a configuration error and is never reset", function()
  fixture(function(f)
    assert(f.fs.mkdir(f.root))
    local path = f.root .. "/config.json"
    for _, raw in ipairs({"", '{"fixture-private":'}) do
      write(f, path, raw)
      rejects(function() f.new():config() end, "config_error")
      assert(read(f, path) == raw)
    end
    assert(attrs(f, f.root .. "/state") == nil)
  end)
end)

test("config byte limit includes exact 64KiB boundary", function()
  fixture(function(f)
    assert(f.fs.mkdir(f.root))
    local path = f.root .. "/config.json"
    write(f, path, "{}" .. string.rep(" ", 65534))
    assert(contract.encode(f.new():config()) == "{}")
    write(f, path, "{}" .. string.rep(" ", 65535))
    rejects(function() f.new():config() end)
  end)
end)

test("absent snapshot returns a fresh correctly marked empty state", function()
  fixture(function(f)
    local store = f.new()
    assert(store:initialize())
    local state = store:load()
    assert(state.version == 1 and state.revision == 0 and #state.active == 0)
    assert(contract.encode(state.active) == "[]")
    state.revision = 42
    assert(store:load().revision == 0)
    assert(attrs(f, f.root .. "/state/active.json") == nil)
  end)
end)

test("save and new instance restore preserve actual snapshot JSON types", function()
  fixture(function(f)
    local store, state = seeded(f)
    local path = f.root .. "/state/active.json"
    assert(attrs(f, path).permissions == "rw-------" and attrs(f, path).nlink == 1)
    state.active[1].content.title = "memory-only change"
    local restored = f.new():load()
    assert(restored.revision == 7 and #restored.active == 2)
    assert(restored.active[1].content.title == "fixture-private")
    assert(restored.active[1].content.body == "plain <text> 한글")
    assert(restored.active[1].expires_at == nil and restored.active[2].expires_at == 8000)
    local context = restored.active[1].context
    assert(contract.encode(context.empty_object) == "{}" and contract.encode(context.empty_array) == "[]")
    assert(context.nested[1] == contract.null and context.nested[2] == false)
    assert(core.validate(restored) == restored)
    assert(store:load().active[1].content.title == "fixture-private")
    no_temps(f)
  end)
end)

test("save uses an exclusive 0600 same-directory temp before atomic replacement", function()
  fixture(function(f)
    local store, state, old = seeded(f)
    state.revision = 8
    local rename = f.fs.rename
    local renamed = false
    f.fs.rename = function(src, dst)
      assert(src:match("^(.*)/[^/]+$") == f.root .. "/state")
      assert(dst == f.root .. "/state/active.json" and src ~= dst)
      assert(read(f, dst) == old, "old snapshot changed before rename")
      assert(attrs(f, src).permissions == "rw-------")
      assert(contract.decode(read(f, src)).revision == 8)
      renamed = true
      return rename(src, dst)
    end
    assert(store:save(state)); assert(renamed)
    assert(f.new():load().revision == 8)
    no_temps(f)
  end)
end)

for _, raw in ipairs({
  '{"fixture-private":', '{"version":2,"revision":0,"active":[]}',
  '{"version":1,"revision":0,"active":{}}', '{"version":1,"revision":-1,"active":[]}',
  'null', '[]', '{"version":1,"revision":0,"active":[],"unknown":"fixture-private"}',
}) do
  test("invalid snapshot fails closed instead of resetting: " .. raw:sub(1, 25), function()
    fixture(function(f)
      assert(f.new():initialize())
      local path = f.root .. "/state/active.json"
      write(f, path, raw)
      rejects(function() f.new():load() end)
      assert(read(f, path) == raw)
      no_temps(f)
    end)
  end)
end

for label, mutate in pairs({
  duplicate_id = function(s) s.active[2].id = s.active[1].id end,
  duplicate_key = function(s) s.active[2].source = "manual"; s.active[2].key = "job" end,
  invalid_time = function(s) s.active[2].updated_at = 999 end,
  invalid_expiry = function(s) s.active[2].expires_at = 8001 end,
  unknown_field = function(s) s.active[1].secret = "fixture-private" end,
}) do
  test("real snapshot validator rejects " .. label .. " on load and save", function()
    fixture(function(f)
      local store, state, old = seeded(f)
      mutate(state)
      rejects(function() store:save(state) end)
      assert(read(f, f.root .. "/state/active.json") == old)
      local invalid = contract.encode(state)
      write(f, f.root .. "/state/active.json", invalid)
      rejects(function() store:load() end)
      assert(read(f, f.root .. "/state/active.json") == invalid)
      no_temps(f)
    end)
  end)
end

for _, file in ipairs({ "config.json", "state/active.json" }) do
  for _, hazard in ipairs({ "mode", "owner", "hardlink", "symlink", "directory", "fifo", "missing_links", "missing_acl" }) do
    test(file .. " rejects unsafe " .. hazard .. " without reading", function()
      fixture(function(f)
        assert(f.new():initialize())
        local path, target = f.root .. "/" .. file, f.base .. "/target"
        if hazard == "directory" then assert(f.fs.mkdir(path))
        elseif hazard == "fifo" then assert(run("/usr/bin/mkfifo " .. quote(path)))
        elseif hazard == "symlink" then
          write(f, target, "fixture-private")
          assert(run("/bin/ln -s " .. quote(target) .. " " .. quote(path)))
        else
          write(f, path, file == "config.json" and "{}" or contract.encode(snapshot()))
          if hazard == "mode" then assert(f.fs.chmod(path, 420)) -- 0644
          elseif hazard == "hardlink" then assert(run("/bin/ln " .. quote(path) .. " " .. quote(target))) end
        end
        local original = f.fs.attributes
        f.fs.attributes = function(name, follow)
          local metadata, err = original(name, follow)
          if name == path and metadata then
            if hazard == "owner" then metadata.uid = uid + 1 end
            if hazard == "missing_links" then metadata.nlink = nil end
            if hazard == "missing_acl" then metadata.has_acl = nil end
          end
          return metadata, err
        end
        local reads = 0
        f.fs.read = function() reads = reads + 1; error("fixture-private") end
        rejects(function()
          if file == "config.json" then f.new():config() else f.new():load() end
        end)
        assert(reads == 0, "unsafe file must not be opened")
        if file ~= "config.json" then rejects(function() f.new():save(snapshot()) end) end
        if hazard == "symlink" then
          local handle = assert(io.open(target, "rb")); assert(handle:read("*a") == "fixture-private"); handle:close()
        end
      end)
    end)
  end
end

test("all operations recheck directory security after initialization", function()
  fixture(function(f)
    local store = seeded(f)
    assert(f.fs.chmod(f.root, 493))
    rejects(function() store:config() end)
    rejects(function() store:load() end)
    rejects(function() store:save(snapshot()) end)
    assert(attrs(f, f.root).permissions == "rwxr-xr-x")
  end)
end)

for _, operation in ipairs({ "read", "write_exclusive", "rename" }) do
  for _, behavior in ipairs({ "return", "throw" }) do
    test(operation .. " " .. behavior .. " failure preserves previous snapshot and removes owned temps", function()
      fixture(function(f)
        local store, state, old = seeded(f)
        state.revision = 8
        local original = f.fs[operation]
        f.fs[operation] = function()
          if behavior == "throw" then error({code="storage_error",message="fixture-private"}) end
          return nil, "fixture-private"
        end
        if operation == "read" then rejects(function() store:load() end)
        else rejects(function() store:save(state) end) end
        f.fs[operation] = original
        assert(read(f, f.root .. "/state/active.json") == old)
        assert(f.new():load().revision == 7)
        no_temps(f)
      end)
    end)
  end
end

test("partial write failure owned by adapter preserves old snapshot", function()
  fixture(function(f)
    local store, state, old = seeded(f)
    local original = f.fs.write_exclusive
    f.fs.write_exclusive = function(path, data, mode)
      assert(original(path, data:sub(1, 20), mode))
      assert(os.remove(path)) -- adapter owns partial write cleanup, not store.
      return nil, "fixture-private"
    end
    rejects(function() store:save(state) end)
    assert(read(f, f.root .. "/state/active.json") == old)
    no_temps(f)
  end)
end)

test("temp token collision never truncates or removes the existing file", function()
  fixture(function(f)
    local store, state, old = seeded(f)
    local exclusive = f.fs.write_exclusive
    local collided
    -- A file appears after lstat but before exclusive creation.
    f.fs.write_exclusive = function(path, data, mode)
      collided = path
      write(f, path, "do not touch")
      return exclusive(path, data, mode)
    end
    rejects(function() store:save(state) end)
    assert(read(f, collided) == "do not touch")
    assert(read(f, f.root .. "/state/active.json") == old)
  end)
end)

test("invalid token cannot escape the private state directory", function()
  fixture(function(f)
    local _, state, old = seeded(f)
    for _, token in ipairs({ "../escape", "/absolute", "", "bad\0token", "a/b", string.rep("a", 129) }) do
      rejects(function() f.new({token = function() return token end}):save(state) end)
    end
    assert(read(f, f.root .. "/state/active.json") == old)
    assert(attrs(f, f.base .. "/escape") == nil)
    no_temps(f)
  end)
end)

for _, hazard in ipairs({ "mode", "truncated", "destination_mode" }) do
  test("post-write " .. hazard .. " validation prevents unsafe rename", function()
    fixture(function(f)
      local store, state, old = seeded(f)
      local original = f.fs.write_exclusive
      f.fs.write_exclusive = function(path, data, mode)
        assert(original(path, hazard == "truncated" and data:sub(1, -2) or data, mode))
        if hazard == "mode" then assert(f.fs.chmod(path, 420)) end
        if hazard == "destination_mode" then assert(f.fs.chmod(f.root .. "/state/active.json", 420)) end
        return true
      end
      rejects(function() store:save(state) end)
      assert(read(f, f.root .. "/state/active.json") == old)
      no_temps(f)
    end)
  end)
end

test("metadata size mismatch and read overflow are rejected", function()
  fixture(function(f)
    local store = seeded(f)
    local original = f.fs.read
    f.fs.read = function(path, limit) return original(path, limit):sub(1, -2) end
    rejects(function() store:load() end)
    f.fs.read = function() return string.rep(" ", 8 * 1024 * 1024 + 1) end
    rejects(function() store:load() end)
  end)
end)

test("valid snapshots honor the exact 8MiB load and save boundary", function()
  fixture(function(f)
    local store, _, old = seeded(f)
    local state = core.empty(); state.revision = 8
    for i = 1, 141 do
      state.active[i] = {
        version=1, source="manual", event="generic", severity="info", id="bulk-" .. i,
        content={title="bulk",body=string.rep("x",59000)}, policy={ttl_seconds=0,dedupe_seconds=0},
        created_at=1000, updated_at=1000,
      }
    end
    local remaining = 8 * 1024 * 1024 - #contract.encode(state)
    assert(remaining > 0 and remaining < 141000)
    for _, record in ipairs(state.active) do
      local add = math.min(1000, remaining)
      record.content.body = record.content.body .. string.rep("x", add)
      remaining = remaining - add
    end
    assert(remaining == 0 and #contract.encode(state) == 8 * 1024 * 1024)
    assert(core.validate(state) == state, "boundary fixture must be a valid real snapshot")
    assert(store:save(state))
    local loaded = f.new():load()
    assert(loaded.revision == 8 and #loaded.active == 141)
    assert(#contract.encode(loaded) == 8 * 1024 * 1024)
    state.active[1].content.body = state.active[1].content.body .. "x"
    assert(core.validate(state) == state)
    rejects(function() store:save(state) end)
    assert(attrs(f, f.root .. "/state/active.json").size == 8 * 1024 * 1024)
    write(f, f.root .. "/state/active.json", contract.encode(state))
    rejects(function() store:load() end)
    assert(attrs(f, f.root .. "/state/active.json").size == 8 * 1024 * 1024 + 1)
    no_temps(f)
  end)
end)


local function acl(f, path, inherited)
  local entry = "everyone allow read,readattr,readextattr,readsecurity"
  if attrs(f, path).mode == "directory" then entry = entry .. ",search" end
  if inherited then entry = entry .. ",file_inherit,directory_inherit" end
  assert(run("/bin/chmod +a " .. quote(entry) .. " " .. quote(path)), "real macOS ACL setup failed")
  assert(attrs(f, path).has_acl == true)
end

for _, target in ipairs({ "root", "state", "config", "active" }) do
  test("private POSIX modes do not bypass a real granting ACL on " .. target, function()
    fixture(function(f)
      local store = seeded(f)
      local path = ({root=f.root,state=f.root .. "/state",config=f.root .. "/config.json",active=f.root .. "/state/active.json"})[target]
      if target == "config" then write(f, path, "{}") end
      acl(f, path, target == "root" or target == "state")
      assert(attrs(f, path).permissions == ((target == "root" or target == "state") and "rwx------" or "rw-------"))
      if target == "config" then rejects(function() store:config() end)
      else
        rejects(function() store:load() end)
        rejects(function() store:save(snapshot()) end)
      end
      assert(attrs(f, path).has_acl == true, "must not strip ACLs from preexisting paths")
    end)
  end)
end

test("inheritable parent ACL is refused before any storage directory is created", function()
  fixture(function(f)
    assert(f.fs.chmod(f.base, 457)) -- 0711, still not writable by others.
    acl(f, f.base, true)
    assert(attrs(f, f.base).inheritable_acl)
    rejects(function() f.new():initialize() end)
    assert(attrs(f, f.root) == nil, "must reject before creating an inheriting root")
    rejects(function() f.new():config() end)
  end)
end)

test("noninheritable parent ACL does not create ACLs on private children", function()
  fixture(function(f)
    acl(f, f.base, false)
    assert(attrs(f, f.base).inheritable_acl == false)
    assert(f.new():initialize())
    assert(attrs(f, f.root).has_acl == false and attrs(f, f.root .. "/state").has_acl == false)
  end)
end)

for _, target in ipairs({ "root", "state", "parent" }) do
  test("unknown ACL metadata fails closed on " .. target, function()
    fixture(function(f)
      assert(f.new():initialize())
      local original = f.fs.attributes
      local path = ({root=f.root,state=f.root .. "/state",parent=f.base})[target]
      f.fs.attributes = function(name, follow)
        local metadata, err = original(name, follow)
        if name == path and metadata then
          if target == "parent" then metadata.inheritable_acl = nil else metadata.has_acl = nil end
        end
        return metadata, err
      end
      rejects(function() f.new():initialize() end)
    end)
  end)
end

test("post-write ACL prevents rename and cleans up only the owned temp", function()
  fixture(function(f)
    local store, state, old = seeded(f)
    local original = f.fs.write_exclusive
    f.fs.write_exclusive = function(path, data, mode)
      assert(original(path, data, mode))
      acl(f, path, false)
      return true
    end
    rejects(function() store:save(state) end)
    assert(read(f, f.root .. "/state/active.json") == old)
    no_temps(f)
  end)
end)

print(string.format("nudge-store: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
