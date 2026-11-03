-- Run from the repository root: lua setup/tests/nudge-core.test.lua
-- No Hammerspoon globals, filesystem state, or external Lua dependencies.
package.path = "home/.hammerspoon/?.lua;home/.hammerspoon/?/init.lua;" .. package.path
assert(hs == nil, "tests must run without Hammerspoon")
local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1
  else failed = failed + 1; io.stderr:write("FAIL ", name, ": ", tostring(err), "\n") end
end
local function eq(actual, expected)
  assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function rejects(fn, secret)
  local ok, err = pcall(fn)
  assert(not ok, "expected rejection")
  assert(type(err) == "string", "errors must be safe strings")
  if secret then assert(not err:find(secret, 1, true), "diagnostic leaked input") end
end
local loaded, c = pcall(require, "nudge.contract")
test("pure Lua contract module is available", function() assert(loaded, "contract module is not implemented") end)
if loaded then
  test("JSON preserves empty containers and null at every position", function()
    local value = c.decode('{"array":[],"object":{},"nil":null,"nested":[null,{},[]]}')
    eq(value["nil"], c.null)
    eq(c.encode(value), '{"array":[],"nested":[null,{},[]],"nil":null,"object":{}}')
    eq(c.encode(c.null), "null")
    eq(c.encode(c.array{}), "[]")
    eq(c.encode(c.object{}), "{}")
    eq(c.encode({}), "{}")
    eq(c.encode({1, false, c.null}), "[1,false,null]")
  end)
  test("JSON escapes control bytes and preserves UTF8", function()
    local text = '\0\b\f\n\r\t\\"/ 한글 😀'
    eq(c.decode(c.encode(text)), text)
    eq(c.decode('"\\u0000\\b\\f\\n\\r\\t\\\\\\\"\\/"'), '\0\b\f\n\r\t\\"/')
    eq(c.decode('"\\uD83D\\uDE00\\ud55c\\uae00"'), "😀한글")
    eq(c.decode('"\\u007f\\u0080\\u07ff\\u0800\\uffff"'), "\127\194\128\223\191\224\160\128\239\191\191")
    eq(c.decode('"\\udbff\\udfff"'), "\244\143\191\191")
  end)
  test("JSON accepts legal scalars and whitespace", function()
    eq(c.decode(" \t\r\ntrue \n"), true)
    eq(c.decode("false"), false)
    eq(c.decode("null"), c.null)
    eq(c.decode("-0"), 0)
    eq(c.decode("-12.5E+2"), -1250)
    eq(c.decode("1e-3"), 0.001)
    eq(c.decode("9007199254740991"), 9007199254740991)
    for _, n in ipairs({0, -1, 1.2345678901234567, 1e100, 1e-100}) do eq(c.decode(c.encode(n)), n) end
  end)
  for i, raw in ipairs({
    "", " ", "{}[]", "null true", "undefined", "TRUE", "NaN", "Infinity", "-Infinity",
    "+1", "01", "-01", ".1", "1.", "1e", "1e+", "--1", "1e9999",
    "[1,]", "[,1]", "[1 2]", "{\"a\":1,}", "{'a':1}", '{a:1}', '{"a" 1}',
    '{"a":1,"a":2}', '{"a":1,"\\u0061":2}', '{"a":null,"a":2}',
    '"\\x00"', '"\\u12"', '"\\uXXXX"', '"\\ud800"', '"\\udfff"',
    '"\\ud800\\u0041"', '"\\ud800x"', '"unclosed', '"line\nbreak"', '"\0"',
    "\239\187\191{}", "\11{}", "\12{}", "[", "{", '"trailing\\',
  }) do
    test("strict JSON rejects malformed case " .. i, function() rejects(function() c.decode(raw) end) end)
  end
  for i, bytes in ipairs({
    "\128", "\192\128", "\193\191", "\194", "\194x", "\224\128\128",
    "\237\160\128", "\240\128\128\128", "\244\144\128\128", "\245\128\128\128",
    "\255", "\226\130", "\240\159\152",
  }) do
    test("invalid UTF8 rejected at all codec boundaries " .. i, function()
      rejects(function() c.decode('"' .. bytes .. '"') end)
      rejects(function() c.encode(bytes) end)
      rejects(function() c.encode({[bytes] = true}) end)
    end)
  end
  test("codec diagnostics do not expose input", function()
    rejects(function() c.decode('{"PRIVATE_TITLE": secret}') end, "PRIVATE_TITLE")
    rejects(function() c.encode({PRIVATE_TITLE = function() end}) end, "PRIVATE_TITLE")
  end)
  test("encoder rejects invalid Lua representations", function()
    for _, value in ipairs({math.huge, -math.huge, 0/0, function() end, coroutine.create(function() end)}) do
      rejects(function() c.encode(value) end)
    end
    rejects(function() c.encode(nil) end)
    rejects(function() c.encode({[1] = "a", name = "b"}) end)
    rejects(function() c.encode(c.array{[2] = "hole"}) end)
    rejects(function() c.encode(c.array{[-1] = true}) end)
    rejects(function() c.encode(c.object{[1] = "numeric key"}) end)
    rejects(function() c.encode({[true] = "boolean key"}) end)
    local cyclic = {}; cyclic.self = cyclic
    rejects(function() c.encode(cyclic) end)
  end)
  test("codec accepts repeated references but rejects excessive nesting safely", function()
    local shared = c.array{}
    eq(c.encode({a=shared,b=shared}), '{"a":[],"b":[]}')
    rejects(function() c.decode(string.rep("[", 10000) .. "0" .. string.rep("]", 10000)) end)
    local nested = {}; local cursor = nested
    for _ = 1, 10000 do cursor.child = {}; cursor = cursor.child end
    rejects(function() c.encode(nested) end)
  end)
  test("codec is not limited to request size for persisted snapshots", function()
    local value = string.rep("x", 70000)
    eq(c.decode(c.encode(value)), value)
  end)
  test("copy and equality preserve JSON type and isolate containers", function()
    local value = c.decode('{"a":[],"b":{},"c":null,"d":[false,null]}')
    local copy = c.copy(value)
    assert(copy ~= value and copy.a ~= value.a)
    eq(copy.c, c.null)
    assert(c.deepEqual(copy, value))
    assert(not c.deepEqual(c.array{}, c.object{}))
    assert(not c.deepEqual(c.null, c.object{}))
    assert(not c.deepEqual({x=false}, {}))
    assert(c.deepEqual({a=1,b=2}, {b=2,a=1}))
    copy.d[1] = true
    eq(value.d[1], false)
  end)
  test("JSON equality compares numeric values, not encoded number spelling", function()
    assert(c.deepEqual(0, -0.0))
    assert(c.deepEqual(c.decode('1000000000000000000'),c.decode('1e18')))
    assert(c.deepEqual({x={-0.0,1e18}},{x={0,c.decode('1000000000000000000')}}))
    assert(not c.deepEqual(1,"1"))
    assert(not c.deepEqual({a=1},{b=1}))
  end)
end
if loaded then
  local function send(raw, config) return c.send(c.decode(raw), config or c.config(nil)) end
  test("send applies builtins without inventing a title or context", function()
    local r = send('{"content":{"title":"Hello"}}')
    eq(c.encode(r), '{"content":{"title":"Hello"},"event":"generic","policy":{"dedupe_seconds":10,"ttl_seconds":86400},"severity":"info","source":"manual","version":1}')
    rejects(function() send('{}') end)
    rejects(function() send('{"content":{}}') end)
  end)
  test("builtin presets select severity and preserve explicit zero policy", function()
    for preset, severity in pairs({['task-completed']='success',['attention-required']='warning',['timer-ended']='info'}) do
      local r = c.send({content={title='done'},policy={preset=preset,ttl_seconds=0,dedupe_seconds=0}}, c.config(nil))
      eq(r.severity, severity); eq(r.policy.preset, preset)
      eq(r.policy.ttl_seconds, 0); eq(r.policy.dedupe_seconds, 0)
    end
  end)
  test("merge precedence is builtin then defaults then preset then request, fieldwise", function()
    local config = c.config(c.decode([[{"defaults":{"severity":"error","content":{"title":"default","subtitle":"default sub","body":"default body"},"policy":{"ttl_seconds":300,"dedupe_seconds":7}},"presets":{"custom":{"severity":"warning","content":{"title":"preset","body":"preset body"},"policy":{"ttl_seconds":20}}}}]]))
    local input = c.decode('{"content":{"title":"request"},"policy":{"preset":"custom","dedupe_seconds":0}}')
    local before, config_before = c.encode(input), c.encode(config)
    local r = c.send(input, config)
    eq(r.content.title, "request"); eq(r.content.subtitle, "default sub"); eq(r.content.body, "preset body")
    eq(r.severity, "warning"); eq(r.policy.ttl_seconds, 20); eq(r.policy.dedupe_seconds, 0)
    eq(c.encode(input), before); eq(c.encode(config), config_before)
    r.content.body = "changed"; eq(c.encode(config), config_before)
    eq(c.send({policy={preset="custom"}}, config).content.title, "preset")
  end)
  test("a user preset replaces the builtin instead of inheriting its fields", function()
    local config = c.config({defaults={severity="error"},presets={['task-completed']={content={title="custom"}}}})
    eq(c.send({policy={preset="task-completed"}}, config).severity, "error")
    eq(c.send({content={title="default"},policy={preset="task-completed"}}, c.config(nil)).severity, "success")
  end)
  test("context is an arbitrary JSON object, preserving nested null/array/object", function()
    local r = send('{"content":{"title":"<b>literal</b>","subtitle":"","body":"\\nplain"},"context":{"x":null,"a":[],"o":{},"deep":[null,true,1,"x"]}}')
    eq(c.encode(r.context), '{"a":[],"deep":[null,true,1,"x"],"o":{},"x":null}')
    eq(r.content.title, "<b>literal</b>"); eq(r.content.body, "\nplain")
    eq(c.encode(send('{"content":{"title":"ok"},"context":{}}').context), "{}")
  end)
  for i, raw in ipairs({
    'null', '[]', 'false', '"object"',
    '{"version":null}', '{"version":2}', '{"version":"1"}', '{"source":""}', '{"source":false}',
    '{"source":null}', '{"event":""}', '{"event":0}', '{"event":null}', '{"key":""}', '{"key":null}',
    '{"severity":"debug"}', '{"severity":null}', '{"severity":1}', '{"content":null}', '{"content":[]}',
    '{"content":{"title":null}}', '{"content":{"title":1}}', '{"content":{"title":""}}',
    '{"content":{"title":" \\t\\r\\n"}}', '{"content":{"title":" 　"}}',
    '{"content":{"title":"ok","subtitle":null}}', '{"content":{"title":"ok","body":false}}',
    '{"content":{"title":"ok","PRIVATE_FIELD":true}}', '{"context":[]}', '{"context":null}', '{"context":"x"}',
    '{"policy":null}', '{"policy":[]}', '{"policy":{"preset":null}}', '{"policy":{"preset":""}}',
    '{"policy":{"preset":"unknown"}}', '{"policy":{"ttl_seconds":-1}}', '{"policy":{"ttl_seconds":1.5}}',
    '{"policy":{"ttl_seconds":"0"}}', '{"policy":{"ttl_seconds":null}}', '{"policy":{"ttl_seconds":9007199254740992}}',
    '{"policy":{"dedupe_seconds":-1}}', '{"policy":{"dedupe_seconds":false}}',
    '{"policy":{"dedupe_seconds":0.5}}', '{"policy":{"dedupe_seconds":9007199254740992}}',
    '{"policy":{"PRIVATE_FIELD":1}}', '{"PRIVATE_FIELD":"secret"}',
  }) do
    test("request rejects invalid schema case " .. i, function()
      local value = c.decode(raw)
      if type(value) == "table" and value ~= c.null and value.content == nil then value.content = {title="ok"} end
      rejects(function() c.send(value, c.config(nil)) end, "PRIVATE_FIELD")
    end)
  end
  for i, raw in ipairs({
    'null', '[]', 'false', '{"version":2}', '{"version":null}', '{"PRIVATE_FIELD":1}',
    '{"defaults":null}', '{"defaults":[]}', '{"defaults":{"source":"x"}}', '{"defaults":{"severity":false}}',
    '{"defaults":{"context":{}}}', '{"defaults":{"content":{"body":null}}}',
    '{"defaults":{"policy":{"preset":"task-completed"}}}', '{"defaults":{"policy":{"ttl_seconds":-1}}}',
    '{"presets":[]}', '{"presets":null}', '{"presets":{"":{}}}', '{"presets":{"x":null}}',
    '{"presets":{"x":[]}}', '{"presets":{"x":{"event":"bad"}}}',
    '{"presets":{"x":{"policy":{"preset":"x"}}}}', '{"presets":{"x":{"severity":"bad"}}}',
  }) do
    test("config rejects invalid schema case " .. i, function() rejects(function() c.config(c.decode(raw)) end, "PRIVATE_FIELD") end)
  end
  test("normalization does not confuse canonical JSON size with input wire size", function()
    local raw='{"operation":"send","request":{"content":{"title":"ok","body":"' .. string.rep('\\n',11000) .. '"}}}'
    assert(#raw<65536)
    local r=c.request(c.decode(raw),c.config(nil))
    eq(#r.request.content.body,11000)
    -- Transport and store enforce the cap on original bytes; Lua values have no wire representation.
    assert(c.config({defaults={content={body=string.rep('x',70000)}}}))
    eq(#c.send({content={title=string.rep('x',70000)}},c.config(nil)).content.title,70000)
  end)
  test("accepted context depth leaves headroom for snapshot and response wrappers", function()
    local raw='{"operation":"send","request":{"content":{"title":"ok"},"context":{"a":' .. string.rep('[',125) .. '0' .. string.rep(']',125) .. '}}}'
    local normalized=c.request(c.decode(raw),c.config(nil)).request
    local snapshot=c.object{version=1,revision=1,active=c.array{normalized}}
    local restored=c.decode(c.encode(snapshot))
    assert(c.deepEqual(restored.active[1],normalized))
  end)
  test("safe integer boundary is allowed in input policy", function()
    local r = send('{"content":{"title":"ok"},"policy":{"ttl_seconds":9007199254740991,"dedupe_seconds":9007199254740991}}')
    eq(r.policy.ttl_seconds, 9007199254740991)
    eq(r.policy.dedupe_seconds, 9007199254740991)
  end)
  test("envelope normalizes send and allows supported query selectors", function()
    local config = c.config({defaults={content={title="default"}}})
    local r = c.request({operation="send",request={},dry_run=true}, config)
    eq(r.operation, "send"); eq(r.request.content.title, "default"); eq(r.dry_run, true)
    for _, value in ipairs({{operation="list"},{operation="list",source="manual"},
      {operation="inspect",id="id"},{operation="inspect",source="manual",key="k"},
      {operation="dismiss",id="id"},{operation="dismiss",source="manual",key="k"},
      {operation="doctor"},{operation="capabilities"}}) do
      eq(c.encode(c.request(value, config)), c.encode(value))
    end
  end)
  for i, value in ipairs({
    c.null, c.array{}, {}, {operation="expire"}, {operation="SEND"}, {operation="doctor",PRIVATE_FIELD=true},
    {operation="capabilities",request={}}, {operation="list",key="k"}, {operation="list",source=""},
    {operation="list",source=c.null}, {operation="list",dry_run=true}, {operation="send"},
    {operation="send",request=c.null}, {operation="send",request={},dry_run="true"},
    {operation="send",request={},dry_run=c.null}, {operation="send",request={},source="x"},
    {operation="inspect"}, {operation="inspect",id=""}, {operation="inspect",id=c.null},
    {operation="inspect",source="x"}, {operation="inspect",key="k"},
    {operation="inspect",id="id",source="x",key="k"}, {operation="dismiss",id="id",source="x"},
    {operation="dismiss",source="x",key=""}, {operation="dismiss",source="x",key=c.null},
  }) do
    test("envelope rejects invalid schema case " .. i, function()
      rejects(function() c.request(value, c.config({defaults={content={title="ok"}}})) end, "PRIVATE_FIELD")
    end)
  end
end
local core_loaded, core = pcall(require, "nudge.core")
test("pure Lua core module is available", function() assert(core_loaded, "core module is not implemented") end)
if loaded and core_loaded then
  local function envelope(input, dry_run)
    return c.request({operation="send",request=input or {content={title="hello"}},dry_run=dry_run}, c.config(nil))
  end
  local function keyed(title, policy, source, key)
    return envelope({source=source or "manual",key=key or "job",content={title=title or "hello"},policy=policy})
  end
  local ids = 0
  local function new_id() ids = ids + 1; return "id-" .. ids end
  local function no_id() error("ID generator must not be called") end
  local function rejection(fn, message)
    local ok, err = pcall(fn)
    assert(not ok, "expected core rejection")
    assert(type(err)=="table" and err.code=="validation_error" and type(err.message)=="string", "expected tagged core validation error")
    assert(not err.message:find("PRIVATE", 1, true), "core diagnostic exposed input")
    if message then eq(err.message, message) end
  end
  local function snapshot()
    return {version=1,revision=1,active=c.array{{version=1,source="manual",event="generic",key="job",severity="info",
      content={title="PRIVATE_TITLE"},policy={ttl_seconds=10,dedupe_seconds=10},
      context=c.object{secret="PRIVATE_CONTEXT"},id="id-a",created_at=1000,updated_at=2000,expires_at=12000}}}
  end
  test("empty snapshot has version, revision and a JSON array", function()
    local s = core.empty()
    eq(c.encode(s), '{"active":[],"revision":0,"version":1}')
    eq(core.validate(s), s)
    eq(core.validate(c.decode(c.encode(s))).revision, 0)
    s.active[1] = {}; eq(#core.empty().active, 0)
  end)
  test("create derives epoch milliseconds and never mutates or aliases input", function()
    local old, req = core.empty(), keyed()
    local before, request_before = c.encode(old), c.encode(req)
    local next_state, response, events = core.transition(old, req, 100000, function() return "new-id" end)
    eq(c.encode(old), before); eq(c.encode(req), request_before)
    eq(next_state.revision, 1); eq(response.ok, true); eq(response.operation, "send")
    eq(response.result, "created"); eq(response.id, "new-id"); eq(response.revision, 1)
    local r = next_state.active[1]
    eq(r.created_at, 100000); eq(r.updated_at, 100000); eq(r.expires_at, 86500000)
    eq(#events, 1); eq(events[1].kind, "upsert"); eq(events[1].record.id, "new-id")
    eq(core.validate(next_state), next_state)
    req.request.content.title = "mutated"; eq(r.content.title, "hello")
    events[1].record.content.title = "renderer mutation"; eq(r.content.title, "hello")
  end)
  test("ttl zero has no expiration and remains visible", function()
    local s = core.transition(core.empty(), keyed("hello",{ttl_seconds=0}), 1000, new_id)
    eq(s.active[1].expires_at, nil); eq(#core.visible(s,9007199254740991),1)
    eq(core.validate(c.decode(c.encode(s))).active[1].expires_at, nil)
  end)
  test("unkeyed sends never dedupe", function()
    local s, r = core.transition(core.empty(), envelope(), 1000, new_id)
    local s2, r2 = core.transition(s, envelope(), 1000, new_id)
    eq(#s2.active, 2); assert(r.id~=r2.id); eq(r2.result,"created")
  end)
  test("dedupe is strict at boundary and does not slide or refresh TTL", function()
    local s = core.transition(core.empty(), keyed(), 1000, new_id)
    local before = c.encode(s)
    for _, now in ipairs({1000,5000,10999}) do
      local n, r, events = core.transition(s, keyed(), now, no_id)
      eq(r.result, "suppressed"); eq(r.id, s.active[1].id); eq(n.revision,1)
      eq(c.encode(n),before); eq(#events,0)
    end
    local n, r, events = core.transition(s, keyed(), 11000, no_id)
    eq(r.result,"updated"); eq(n.revision,2); eq(n.active[1].created_at,1000)
    eq(n.active[1].updated_at,11000); eq(n.active[1].expires_at,86411000); eq(#events,1)
  end)
  test("dedupe zero disables suppression", function()
    local s = core.transition(core.empty(), keyed("x",{dedupe_seconds=0}),1000,new_id)
    local n,r = core.transition(s,keyed("x",{dedupe_seconds=0}),1001,no_id)
    eq(r.result,"updated"); eq(n.revision,2)
  end)
  test("same-millisecond identical update does not invent a state change", function()
    local s = core.transition(core.empty(),keyed("x",{dedupe_seconds=0}),1000,new_id)
    local n,r,events = core.transition(s,keyed("x",{dedupe_seconds=0}),1000,no_id)
    eq(r.result,"updated"); eq(n.revision,1); eq(#events,0)
  end)
  test("full replacement preserves identity but removes omitted optional fields", function()
    local first = envelope({source="manual",key="job",event="build",severity="error",
      content={title="old",subtitle="sub",body="body"},context={a=1},policy={ttl_seconds=0}})
    local s = core.transition(core.empty(), first, 1000, new_id)
    local before = c.encode(s)
    local n,r = core.transition(s,keyed("new"),1001,no_id)
    eq(r.result,"updated"); eq(n.active[1].id,s.active[1].id); eq(n.active[1].created_at,1000)
    eq(n.active[1].content.subtitle,nil); eq(n.active[1].content.body,nil); eq(n.active[1].context,nil)
    eq(n.active[1].event,"generic"); eq(n.active[1].severity,"info"); eq(n.active[1].expires_at,86401001)
    eq(c.encode(s),before)
  end)
  test("key identity includes source without delimiter collisions", function()
    local s = core.empty()
    for _, pair in ipairs({{"a","b:c"},{"a:b","c"},{"a\0b","c"},{"a","b\0c"},{"other","b:c"}}) do
      s = core.transition(s,keyed("x",nil,pair[1],pair[2]),1000,new_id)
    end
    eq(#s.active,5)
    local n,r = core.transition(s,keyed("x",nil,"a","b:c"),1001,no_id)
    eq(#n.active,5); eq(r.result,"suppressed"); eq(core.validate(n),n)
  end)
  test("dedupe ignores preset name and object member order but respects JSON types", function()
    local config = c.config({presets={a={severity="info"},b={severity="info"}}})
    local function request(preset, context)
      return c.request({operation="send",request={key="job",content={title="x"},policy={preset=preset},context=context}},config)
    end
    local s = core.transition(core.empty(),request("a",{x=1,y=c.array{}}),1000,new_id)
    local n,r = core.transition(s,request("b",{y=c.array{},x=1}),1001,no_id)
    eq(r.result,"suppressed"); eq(n.active[1].policy.preset,"a")
    n,r = core.transition(s,request("b",{x=1,y=c.object{}}),1001,no_id)
    eq(r.result,"updated"); eq(n.active[1].policy.preset,"b")
    eq(core.validate(n),n) -- persisted custom presets survive config removal.
  end)
  test("every semantic request field participates in dedupe", function()
    local s = core.transition(core.empty(),keyed(),1000,new_id)
    for _, mutate in ipairs({
      function(r) r.event="build" end, function(r) r.severity="warning" end,
      function(r) r.content.title="different" end, function(r) r.content.subtitle="" end,
      function(r) r.content.body="" end, function(r) r.context=c.object{} end,
      function(r) r.policy.ttl_seconds=20 end, function(r) r.policy.dedupe_seconds=20 end,
    }) do
      local request=keyed(); mutate(request.request)
      local n,r=core.transition(s,request,1001,no_id)
      eq(r.result,"updated"); eq(n.revision,2)
    end
  end)
  test("expiry at <= now runs before send and increments revision only once", function()
    local s = core.transition(core.empty(),keyed("old",{ttl_seconds=1}),1000,new_id)
    local n,r,events=core.transition(s,keyed("old",{ttl_seconds=1}),2000,new_id)
    eq(n.revision,2); eq(#n.active,1); eq(r.result,"created"); assert(r.id~=s.active[1].id)
    eq(#events,2); eq(events[1].kind,"remove"); eq(events[1].reason,"expired"); eq(events[1].id,s.active[1].id)
    eq(events[2].kind,"upsert")
  end)
  test("internal expire cleans all expired records but is a no-op otherwise", function()
    local s = core.transition(core.empty(),keyed("short",{ttl_seconds=1}),1000,new_id)
    s = core.transition(s,keyed("forever",{ttl_seconds=0},"other"),1000,new_id)
    local n,r,events=core.transition(s,{operation="expire"},2000,no_id)
    eq(n.revision,3); eq(#n.active,1); eq(n.active[1].content.title,"forever"); eq(#events,1); eq(r.operation,"expire")
    local n2,_,events2=core.transition(n,{operation="expire"},3000,no_id)
    eq(n2.revision,3); eq(#events2,0); eq(n2,n) -- no-op timer must not clone or revalidate payloads
  end)
  test("visible and list sort newest then id, filter source, and hide expired without mutation", function()
    local s=core.empty()
    for _, row in ipairs({{"z",1000,"one",0},{"b",1001,"two",0},{"a",1001,"one",0},{"expired",1001,"one",1}}) do
      s=core.transition(s,keyed(row[1],{ttl_seconds=row[4]},row[3],row[1]),row[2],function() return row[1] end)
    end
    local before=c.encode(s)
    local v=core.visible(s,2001)
    eq(#v,3); eq(v[1].id,"a"); eq(v[2].id,"b"); eq(v[3].id,"z"); eq(c.encode(s),before)
    v[1].content.title="changed"; eq(c.encode(s),before)
    local n,r,events=core.transition(s,{operation="list",source="one"},2001,no_id)
    eq(#r.active,2); eq(r.active[1].id,"a"); eq(r.active[2].id,"z"); eq(n.revision,5); eq(#events,1)
    r.active[1].content.title="changed"; eq(n.active[3].content.title,"a")
    local _,empty=core.transition(n,{operation="list",source="missing"},2001,no_id)
    eq(c.encode(empty.active),"[]")
  end)
  test("inspect and dismiss support id or source+key and never return expired records", function()
    local s,r=core.transition(core.empty(),keyed(),1000,new_id)
    for _, selector in ipairs({{id=r.id},{source="manual",key="job"}}) do
      selector.operation="inspect"
      local n,read,events=core.transition(s,selector,1001,no_id)
      eq(read.record.id,r.id); eq(n.revision,1); eq(#events,0)
      read.record.content.title="changed"; eq(n.active[1].content.title,"hello")
      selector.operation="dismiss"
      local gone,dismissed,removed=core.transition(s,selector,1001,no_id)
      eq(dismissed.result,"dismissed"); eq(dismissed.id,r.id); eq(gone.revision,2); eq(#gone.active,0)
      eq(removed[1].kind,"remove"); eq(removed[1].reason,"dismissed"); eq(removed[1].id,r.id)
      local unchanged,again,none=core.transition(gone,selector,1002,no_id)
      eq(again.result,"not_found"); eq(unchanged.revision,2); eq(#none,0)
    end
    local expired,missing,events=core.transition(s,{operation="inspect",id=r.id},86401000,no_id)
    eq(missing.result,"not_found"); eq(missing.record,nil); eq(expired.revision,2); eq(#events,1)
    local _,wrong=core.transition(s,{operation="inspect",source="other",key="job"},1001,no_id)
    eq(wrong.result,"not_found")
  end)
  test("dry run returns normalized request without IDs, expiry, revision, or alias changes", function()
    local s=core.transition(core.empty(),keyed("expired",{ttl_seconds=1}),1000,new_id)
    local before=c.encode(s); local req=keyed("preview"); req.dry_run=true
    local n,r,events=core.transition(s,req,5000,no_id)
    eq(c.encode(n),before); eq(c.encode(s),before); eq(r.result,"dry_run"); eq(r.revision,1)
    eq(r.id,nil); eq(r.request.content.title,"preview"); eq(r.request.policy.ttl_seconds,86400); eq(#events,0)
    r.request.content.title="changed"; eq(req.request.content.title,"preview")
  end)
  local function full_state()
    local s=core.empty()
    for i=1,1000 do
      s.active[i]={id="id-"..i,created_at=1000,updated_at=1000,version=1,source="manual",event="generic",key=tostring(i),
        severity="info",content={title="hello"},policy={ttl_seconds=0,dedupe_seconds=10}}
    end
    return s
  end
  test("active cap rejects only new live records; updates and expiry can free slots", function()
    local s=full_state(); local before=c.encode(s)
    eq(core.validate(s),s)
    rejection(function() core.transition(s,keyed(),1000,no_id) end, "active record limit reached")
    eq(c.encode(s),before)
    local updated,r=core.transition(s,keyed("updated",{ttl_seconds=0},"manual","1"),1001,no_id)
    eq(#updated.active,1000); eq(r.result,"updated")
    local _,dry=core.transition(s,envelope({content={title="preview"}},true),1000,no_id)
    eq(dry.result,"dry_run")
    s.active[1].policy.ttl_seconds=1; s.active[1].expires_at=2000
    local next_state,created,events=core.transition(s,keyed(),2000,function() return "new-after-cap" end)
    eq(#next_state.active,1000); eq(created.result,"created"); eq(#events,2); eq(next_state.revision,1)
  end)
  test("safe arithmetic rejects timestamp/revision overflow before exposing a candidate", function()
    for _, now in ipairs({-1,0.5,math.huge,0/0,9007199254740992,"1000"}) do
      rejection(function() core.transition(core.empty(),keyed(),now,new_id) end)
    end
    rejection(function() core.transition(core.empty(),keyed("x",{ttl_seconds=9007199254740991}),1000,new_id) end)
    local s=core.empty(); s.revision=9007199254740991
    local same=core.transition(s,{operation="list"},1000,no_id); eq(same.revision,s.revision)
    rejection(function() core.transition(s,keyed(),1000,new_id) end)
    local n=core.transition(core.empty(),keyed("x",{ttl_seconds=0}),9007199254740991,new_id)
    eq(n.active[1].updated_at,9007199254740991)
  end)
  test("unexpected ID generator exceptions propagate for internal classification", function()
    local marker={message="PRIVATE_RUNTIME"}
    local ok,err=pcall(core.transition,core.empty(),keyed(),1000,function() error(marker) end)
    eq(ok,false); eq(err,marker); eq(err.code,nil)
    local s=core.transition(core.empty(),keyed(),1000,function() return "duplicate" end)
    rejection(function() core.transition(s,envelope(),1001,function() return "duplicate" end) end)
    rejection(function() core.transition(core.empty(),keyed(),1000,function() return "" end) end)
  end)
  test("snapshot roundtrip accepts fully normalized records including custom presets", function()
    local s=snapshot(); s.active[1].policy.preset="removed-custom-preset"
    eq(core.validate(s),s)
    local decoded=c.decode(c.encode(s)); eq(core.validate(decoded),decoded)
  end)
  test("merged records can exceed the input cap and restore independently of config", function()
    local config=c.config({defaults={content={body=string.rep("b",40000)}}})
    local request=c.request({operation="send",request={content={title=string.rep("t",40000)}}},config)
    local s=core.transition(core.empty(),request,1000,function() return "UPPERCASE-ID" end)
    assert(#c.encode(s.active[1])>65536)
    eq(core.validate(s),s)
    local restored=c.decode(c.encode(s)); eq(core.validate(restored),restored)
    eq(#restored.active[1].content.title,40000); eq(#restored.active[1].content.body,40000)
  end)
  for name, mutate in pairs({
    version=function(s) s.version=2 end, missing_version=function(s) s.version=nil end,
    revision=function(s) s.revision=-1 end, fractional_revision=function(s) s.revision=0.1 end,
    unsafe_revision=function(s) s.revision=9007199254740992 end, null_revision=function(s) s.revision=c.null end,
    unknown_state_field=function(s) s.PRIVATE_FIELD=true end, object_active=function(s) s.active=c.object{} end,
    missing_active=function(s) s.active=nil end, null_active=function(s) s.active=c.null end,
    hole=function(s) s.active[3]=c.copy(s.active[1]); s.active[3].id="different" end,
    duplicate_id=function(s) s.active[2]=c.copy(s.active[1]); s.active[2].key="different" end,
    duplicate_key=function(s) s.active[2]=c.copy(s.active[1]); s.active[2].id="different" end,
    unknown_record_field=function(s) s.active[1].PRIVATE_FIELD=true end,
    null_record=function(s) s.active[1]=c.null end, array_record=function(s) s.active[1]=c.array{} end,
    missing_id=function(s) s.active[1].id=nil end, empty_id=function(s) s.active[1].id="" end,
    invalid_utf8_id=function(s) s.active[1].id="\255" end,
    missing_source=function(s) s.active[1].source=nil end, empty_source=function(s) s.active[1].source="" end,
    missing_event=function(s) s.active[1].event=nil end, empty_event=function(s) s.active[1].event="" end,
    missing_record_version=function(s) s.active[1].version=nil end,
    invalid_severity=function(s) s.active[1].severity="debug" end,
    blank_title=function(s) s.active[1].content.title=" " end,
    invalid_body=function(s) s.active[1].content.body=c.null end,
    array_context=function(s) s.active[1].context=c.array{} end,
    null_context=function(s) s.active[1].context=c.null end,
    missing_policy=function(s) s.active[1].policy=nil end,
    missing_ttl=function(s) s.active[1].policy.ttl_seconds=nil end,
    missing_dedupe=function(s) s.active[1].policy.dedupe_seconds=nil end,
    negative_dedupe=function(s) s.active[1].policy.dedupe_seconds=-1 end,
    null_preset=function(s) s.active[1].policy.preset=c.null end,
    empty_preset=function(s) s.active[1].policy.preset="" end,
    missing_created=function(s) s.active[1].created_at=nil end,
    negative_created=function(s) s.active[1].created_at=-1 end,
    fractional_updated=function(s) s.active[1].updated_at=2000.5 end,
    backwards_updated=function(s) s.active[1].updated_at=999 end,
    unsafe_updated=function(s) s.active[1].updated_at=9007199254740992 end,
    missing_expires=function(s) s.active[1].expires_at=nil end,
    wrong_expires=function(s) s.active[1].expires_at=12001 end,
    null_expires=function(s) s.active[1].expires_at=c.null end,
    zero_ttl_expiry=function(s) s.active[1].policy.ttl_seconds=0 end,
  }) do
    test("snapshot rejects corruption: "..name,function()
      local s=snapshot(); mutate(s)
      rejection(function() core.validate(s) end)
    end)
  end
  test("snapshot rejects nonobjects, unsupported data, and excess records safely", function()
    for _, s in ipairs({c.null,c.array{},true,"PRIVATE_STATE"}) do rejection(function() core.validate(s) end) end
    local s=full_state(); s.active[1001]=c.copy(s.active[1]); s.active[1001].id="extra"; s.active[1001].key="extra"
    rejection(function() core.validate(s) end)
    s=core.empty(); s.active[1]=s; rejection(function() core.validate(s) end)
  end)
end

-- Raw transport values must reach the same strict decoder as direct requests.
test("raw JSON transport preserves strict syntax and original byte budget", function()
  local base='{"content":{"title":"raw"}}'
  local r=c.request({operation="send",request_json=base..string.rep(" ",65536-#base)})
  eq(r.request.content.title,"raw"); eq(r.request.source,"manual")
  rejects(function() c.request({operation="send",request_json=base..string.rep(" ",65537-#base)}) end)
  for _,raw in ipairs({
    '{"content":{"title":"x"},"policy":{"ttl_seconds":01}}',
    '{"content":{"title":"\\udfff"}}',
    '{"content":{"title":"x"},"context":{"a":1,"a":2}}',
    '{"content":{"title":"x"},"context":{"a":NaN}}',
    '[]','null','true','',
  }) do rejects(function() c.request({operation="send",request_json=raw}) end) end
  for _,value in ipairs({false,c.null,1,c.array{}}) do
    rejects(function() c.request({operation="send",request_json=value}) end)
  end
  rejects(function() c.request({operation="send",request_json=base,request={}}) end)
  rejects(function() c.request({operation="send",request_json=base,raw_fields={}}) end)
end)
test("raw numeric and context flags are decoded without jq normalization", function()
  local e={operation="send",request={content={title="flags"}},raw_fields={
    version="1",context='{"nested":[null,{},[]]}',["policy.ttl_seconds"]="0",["policy.dedupe_seconds"]="0"}}
  local before=c.encode(e)
  local r=c.request(e)
  eq(r.request.policy.ttl_seconds,0); eq(r.request.policy.dedupe_seconds,0)
  eq(c.encode(r.request.context),'{"nested":[null,{},[]]}'); eq(c.encode(e),before)
  for _,raw in ipairs({'01','NaN','Infinity','"1"','null','true','-1','1.5'}) do
    rejects(function() c.request({operation="send",request={content={title="x"}},raw_fields={["policy.ttl_seconds"]=raw}}) end)
  end
  for _,raw in ipairs({'{"a":NaN}','{"a":1,"a":2}','{"a":"\\udfff"}','[]','null'}) do
    rejects(function() c.request({operation="send",request={content={title="x"}},raw_fields={context=raw}}) end)
  end
  for _,fields in ipairs({{source='"x"'},{context=1},{["policy.preset"]='"task-completed"'},c.null,c.array{}}) do
    rejects(function() c.request({operation="send",request={content={title="x"}},raw_fields=fields}) end)
  end
  rejects(function() c.request({operation="send",request={content={title="x"},policy={ttl_seconds=1}},raw_fields={["policy.ttl_seconds"]="2"}}) end)
  rejects(function() c.request({operation="send",request={content={title="x"},policy=false},raw_fields={["policy.ttl_seconds"]="2"}}) end)
  rejects(function() c.request({operation="send",raw_fields={context="{}"}}) end)
end)

print(string.format("nudge-core: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
