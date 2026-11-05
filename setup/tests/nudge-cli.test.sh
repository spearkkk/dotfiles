#!/bin/bash
# External boundaries are faked; never contact or launch Hammerspoon.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd -P)
cli="$root/home/.local/bin/nudge"
ipc="$root/home/.local/libexec/nudge-dispatch-request.lua"
jq_bin=$(command -v jq)
lua_bin=${LUA_BIN:-$(command -v lua)}
case "$lua_bin" in
  */mise/shims/*)
    # An inactive mise shim can fall through to another Lua on the original PATH.
    # Resolve it before changing HOME (and thus mise's trust/config directories).
    if ! lua_bin=$(mise which lua 2>/dev/null); then
      while IFS= read -r candidate; do
        case "$candidate" in */mise/shims/*) continue ;; esac
        lua_bin=$candidate
        break
      done < <(type -ap lua)
    fi
    ;;
esac
[ -n "$lua_bin" ] && [ -x "$lua_bin" ] || { echo 'A Lua runtime is required (or set LUA_BIN).' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/scratch"
export HOME="$tmp/home" TMPDIR="$tmp/scratch"
export NUDGE_TEST_DIR="$tmp"
export NUDGE_TEST_LUA="$lua_bin" NUDGE_TEST_ROOT="$root"
export PATH="$tmp/bin:/usr/bin:/bin"
ln -s "$jq_bin" "$tmp/bin/jq"
cat > "$tmp/bin/pgrep" <<'FAKE'
#!/bin/bash
printf '%s\n' "$@" > "$NUDGE_TEST_DIR/pgrep.args"
case ${NUDGE_TEST_PROCESS:-running} in
  running) exit 0 ;;
  stopped) exit 1 ;;
  slow) sleep 1.2; exit 0 ;;
  hung) exec sleep 20 ;;
esac
exit 2
FAKE
cat > "$tmp/bin/hs" <<'FAKE'
#!/bin/bash
printf 'call\n' >> "$NUDGE_TEST_DIR/calls"
printf '%s\n' "$@" > "$NUDGE_TEST_DIR/hs.args"
printf '%s' "${6-}" > "$NUDGE_TEST_DIR/envelope"
# Fail if the real CLI changes its fixed-file invocation or leaves stdin open.
[ "$#" = 6 ] && [ "$1" = -q ] && [ "$2" = -n ] && [ "$3" = -t ] && [ "$4" = 2 ] || exit 90
[ -r "$5" ] && [ "$5" = "$NUDGE_TEST_IPC" ] || exit 91
if IFS= read -r -t 0.1 line; then exit 92; fi
case ${NUDGE_TEST_MODE:-reply} in
  hung)
    trap '' TERM
    echo "$$" > "$NUDGE_TEST_DIR/hs.pid"
    sleep 20 &
    echo "$!" > "$NUDGE_TEST_DIR/child.pid"
    wait
    ;;
  split) sleep 1.2; sleep 1.2 ;;
  delayed) sleep 1.2 ;;
  failure) echo 'private transport error' >&2; exit 17 ;;
  reply) ;;
esac
if [ "${NUDGE_TEST_VALIDATE:-0}" = 1 ]; then
  exec "$NUDGE_TEST_LUA" "$NUDGE_TEST_DIR/validate.lua"
fi
cat "$NUDGE_TEST_DIR/reply"
FAKE
cat > "$tmp/validate.lua" <<'LUA'
local root=assert(os.getenv('NUDGE_TEST_ROOT'))
package.path=root..'/home/.hammerspoon/?.lua;'..package.path
local c=require('nudge.contract')
local file=assert(io.open(os.getenv('NUDGE_TEST_DIR')..'/envelope','rb'))
local raw=file:read('*a');file:close()
local ok,value=pcall(function() return c.request(c.decode(raw)) end)
print(c.encode({ok=ok,exit_code=ok and 0 or 2,normalized=ok and value or nil}))
LUA
chmod +x "$tmp/bin/hs" "$tmp/bin/pgrep"
export NUDGE_TEST_IPC="$ipc"
export NUDGE_TEST_MODE=reply NUDGE_TEST_PROCESS=running
printf '%s\n' '{"ok":true,"exit_code":0,"stored":true,"render":{"status":"ok","renderer":"debug","presented":false}}' > "$tmp/reply"
passed=0
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { passed=$((passed + 1)); printf 'ok %s - %s\n' "$passed" "$*"; }
run() {
  local want=$1 status=0
  shift
  : > "$tmp/calls"
  : > "$tmp/envelope"
  "$cli" "$@" > "$tmp/out" 2> "$tmp/err" || status=$?
  [ "$status" = "$want" ] || fail "expected exit $want, got $status: $* ($(cat "$tmp/err"))"
  "$jq_bin" -se --argjson code "$want" 'length == 1 and (.[0] | type == "object" and .exit_code == $code and (.ok == ($code == 0)))' "$tmp/out" > /dev/null || fail "expected one response object: $*"
}
envelope() { "$jq_bin" -e "$1" "$tmp/envelope" > /dev/null || fail "wrong envelope: $1"; }
no_call() { [ ! -s "$tmp/calls" ] || fail 'unexpected IPC call'; }
reject() { run 2 "$@"; no_call; }

[ -x "$cli" ] || fail 'nudge CLI must exist and be executable'
[ -r "$ipc" ] || fail 'fixed IPC entry must exist'

"$cli" --help > "$tmp/help"
grep -q 'send' "$tmp/help" || fail 'help must explain commands'
grep -qi 'plaintext' "$tmp/help" && grep -qi 'secrets' "$tmp/help" || fail 'help must warn about plaintext and secrets'
pass 'help works without Hammerspoon'
run 0 send
 envelope '. == {operation:"send",request:{}}'
[ "$(cat "$tmp/pgrep.args")" = $'-x\nHammerspoon' ] || fail 'preflight must check the running application'
[ "$(wc -l < "$tmp/calls" | tr -d ' ')" = 1 ] || fail 'exactly one IPC call'
pass 'worktree invocation uses fixed file, separate envelope, and no business defaults'

run 0 send --version 1 --source cli --event finished --key key --severity success --title 'Finished' --subtitle 'Sub' --body 'Body' --context-json '{"empty":{},"array":[],"null":null}' --preset task-completed --ttl-seconds 0 --dedupe-seconds 0 --dry-run
envelope '. == {operation:"send",dry_run:true,request:{source:"cli",event:"finished",key:"key",severity:"success",content:{title:"Finished",subtitle:"Sub",body:"Body"},policy:{preset:"task-completed"}},raw_fields:{version:"1",context:"{\"empty\":{},\"array\":[],\"null\":null}","policy.ttl_seconds":"0","policy.dedupe_seconds":"0"}}'
pass 'all send flags preserve nesting, JSON types, and explicit zero'

run 0 send --title Sound --sound Glass
envelope '.request.sound == {name:"Glass"}'
run 0 send --title Sound --sound-file '/tmp/chime with spaces.wav'
envelope '.request.sound == {file:"/tmp/chime with spaces.wav"}'
run 0 send --title Sound --silent
envelope '.request.sound == false'
reject send --sound Glass --sound-file /tmp/a.wav
reject send --silent --sound Glass
reject send --sound-file /tmp/a.wav --silent
reject send --silent --silent
reject send --sound Glass --sound Ping
reject send --sound
reject send --sound-file
reject send --json - --silent
pass 'sound flags preserve types and are mutually exclusive'

payload='"; os.execute("touch SHOULD_NOT_EXIST"); -- $(touch SHOULD_NOT_EXIST) `touch SHOULD_NOT_EXIST`'
payload="$payload"$'\nUnicode: 한글 \\ end'
(cd "$tmp"; run 0 send --title "$payload" --body "$payload" --source "$payload" --context-json '{"lua":"]; os.execute(\"bad\"); --"}')
"$jq_bin" -e --arg payload "$payload" '.request.content.title == $payload and .request.content.body == $payload and .request.source == $payload' "$tmp/envelope" > /dev/null || fail 'injection text must round trip'
[ ! -e "$tmp/SHOULD_NOT_EXIST" ] || fail 'shell injection executed'
pass 'shell and Lua injection strings remain data'

printf '%s\n' '{"content":{"title":"JSON"},"policy":{"ttl_seconds":0},"context":{"a":[]}}' > "$tmp/input with spaces.json"
run 0 send --json "$tmp/input with spaces.json" --dry-run
envelope '.operation=="send" and .dry_run and (has("request")|not)'
"$jq_bin" -rj '.request_json' "$tmp/envelope" > "$tmp/roundtrip"
cmp "$tmp/roundtrip" "$tmp/input with spaces.json" || fail 'original JSON bytes changed'
run 0 send --json - < "$tmp/input with spaces.json"
envelope '(.request_json|fromjson|.content.title)=="JSON" and (has("dry_run")|not)'
# The transport must not consume caller stdin as Lua or as a launch answer.
run 0 doctor < "$tmp/input with spaces.json"
pass 'JSON file/stdin and closed hs stdin'

for op in doctor capabilities list; do
  run 0 "$op"; envelope ". == {operation:\"$op\"}"
done
run 0 list --source worker; envelope '. == {operation:"list",source:"worker"}'
for op in inspect dismiss; do
  run 0 "$op" record-id; envelope ". == {operation:\"$op\",id:\"record-id\"}"
  run 0 "$op" --id record-id; envelope ". == {operation:\"$op\",id:\"record-id\"}"
  run 0 "$op" --source worker --key task; envelope ". == {operation:\"$op\",source:\"worker\",key:\"task\"}"
done
pass 'operation envelopes and both selector forms'

reject
reject unknown
reject send --unknown
reject send --title
reject send --title a --title b
reject send --dry-run --dry-run
reject send --json "$tmp/input with spaces.json" --title bad
reject send --source a --json "$tmp/input with spaces.json"
reject send --json "$tmp/input with spaces.json" --json -
reject send positional
reject list --key task
reject doctor --source a
reject capabilities extra
for op in inspect dismiss; do
  reject "$op"
  reject "$op" --source a
  reject "$op" --key b
  reject "$op" --id id --source a --key b
  reject "$op" id extra
  reject "$op" --dry-run
 done
pass 'argument errors never invoke hs'

for raw in '' 'null' '[]' '"text"' '{broken' '{} {}'; do
  printf '%s' "$raw" > "$tmp/input.json"
  NUDGE_TEST_VALIDATE=1 run 2 send --json "$tmp/input.json"
done
reject send --json "$tmp/missing"
printf '{"content":{"title":"\377"}}' > "$tmp/input.json"
reject send --json "$tmp/input.json"
"$jq_bin" -nc '{content:{title:("x" * 65536)}}' > "$tmp/input.json"
reject send --json "$tmp/input.json"
reject send --title "$(printf '%65537s' x)"
pass 'invalid, non-object, non-UTF8, and oversized input rejected'

# Domain policy belongs to Lua: do not inject defaults or filter unknown fields.
printf '%s' '{"unknown":null,"content":{"title":""},"policy":{"ttl_seconds":-1}}' > "$tmp/input.json"
run 0 send --json "$tmp/input.json"
envelope '(.request_json|fromjson)=={unknown:null,content:{title:""},policy:{ttl_seconds:-1}}'
run 0 send --severity custom --ttl-seconds -1
envelope '.request=={severity:"custom"} and .raw_fields["policy.ttl_seconds"]=="-1"'
pass 'business validation remains in the service'

# Run original bytes through the real Lua contract, not jq's permissive parser.
for raw in '{"content":{"title":"x"},"policy":{"ttl_seconds":01}}' \
  '{"content":{"title":"\udfff"}}' \
  '{"content":{"title":"x"},"context":{"a":NaN}}' \
  '{"content":{"title":"x"},"context":{"a":1,"a":2}}'; do
  printf '%s' "$raw" > "$tmp/input.json"
  NUDGE_TEST_VALIDATE=1 run 2 send --json "$tmp/input.json"
  "$jq_bin" -rj '.request_json' "$tmp/envelope" > "$tmp/roundtrip"
  cmp "$tmp/roundtrip" "$tmp/input.json" || fail 'invalid JSON was repaired before Lua'
done
for raw in 'NaN' 'Infinity' '01' '"1"' '$(touch SHOULD_NOT_EXIST)'; do
  NUDGE_TEST_VALIDATE=1 run 2 send --title x --ttl-seconds "$raw"
done
for raw in '{"a":NaN}' '{"a":1,"a":2}' '{"a":"\udfff"}' '{broken'; do
  NUDGE_TEST_VALIDATE=1 run 2 send --title x --context-json "$raw"
done
NUDGE_TEST_VALIDATE=1 run 0 send --title flags --ttl-seconds 0 --context-json '{"a":[],"n":null}'
"$jq_bin" -e '.normalized.request.policy.ttl_seconds==0 and .normalized.request.context=={a:[],n:null}' "$tmp/out" >/dev/null || fail 'raw flags normalization'
# Escaping transport strings must not reduce the original 64KiB JSON budget.
"$jq_bin" -nc '{content:{title:("\""*20000)}}' > "$tmp/input.json"
NUDGE_TEST_VALIDATE=1 run 0 send --json "$tmp/input.json" --dry-run
[ "$(wc -c < "$tmp/envelope")" -gt 65536 ] || fail 'fixture must exercise expanded envelope'
pass 'strict Lua validation receives unchanged raw JSON and numeric/context flags'


for code in 0 2 3 4 5; do
  "$jq_bin" -nc --argjson code "$code" '{ok:($code==0),exit_code:$code,stored:($code==5),render:{status:"test",renderer:"debug",presented:false}}' > "$tmp/reply"
  run "$code" doctor
  "$jq_bin" -se '.[0] == .[1]' "$tmp/reply" "$tmp/out" > /dev/null || fail 'service reply changed'
done
# Valid JSON integers may retain a decimal spelling; Bash exit needs a canonical integer.
printf '%s' '{"ok":true,"exit_code":0.0}' > "$tmp/reply"
run 0 doctor
[ ! -s "$tmp/err" ] || fail 'decimal success code produced shell diagnostics'
printf '%s' '{"ok":false,"exit_code":2.0}' > "$tmp/reply"
run 2 doctor
[ ! -s "$tmp/err" ] || fail 'decimal error code produced shell diagnostics'
pass 'service exit codes and reply fields preserved'

for raw in '{"ok":true,"exit_code":0,"n":NaN}' '{"ok":true,"exit_code":0,"n":Infinity}' '{"ok":true,"exit_code":00}' '{"ok":true,"exit_code":0,"text":"\udfff"}' '' garbage null '[]' '42' '{}' '{"ok":true}' '{"ok":true,"exit_code":"0"}' '{"ok":true,"exit_code":1}' '{"ok":false,"exit_code":0}' '{"ok":true,"exit_code":4}' '{"ok":false,"exit_code":2.5}' '{"ok":true,"exit_code":0} {}'; do
  printf '%s' "$raw" > "$tmp/reply"
  run 3 doctor
done
printf '{"ok":true,"exit_code":0,"text":"\377"}' > "$tmp/reply"
run 3 doctor
pass 'invalid responses become transport failures'
printf '%s' '{"ok":true,"exit_code":0}' > "$tmp/reply"
NUDGE_TEST_MODE=failure run 3 doctor
! grep -q private "$tmp/out" "$tmp/err" || fail 'transport stderr leaked'
NUDGE_TEST_PROCESS=stopped run 3 doctor
no_call
pass 'failed transport and stopped app never launch or leak diagnostics'

mv "$tmp/bin/hs" "$tmp/bin/hs.off"
run 3 doctor
mv "$tmp/bin/hs.off" "$tmp/bin/hs"
mkdir "$tmp/no-jq"
ln -s /bin/cat "$tmp/no-jq/cat"
PATH="$tmp/no-jq" run 4 doctor
PATH="$tmp/no-jq" "$cli" --help > /dev/null
pass 'missing dependencies return structured failures; help is standalone'

# Exercise both stow's file symlink and folded-directory layouts, including spaces.
mkdir -p "$tmp/stow home/.local/bin" "$tmp/stow home/.local/libexec"
ln -s "$cli" "$tmp/stow home/.local/bin/nudge"
ln -s "$ipc" "$tmp/stow home/.local/libexec/nudge-dispatch-request.lua"
saved_cli=$cli
cli="$tmp/stow home/.local/bin/nudge"; run 0 doctor
mkdir -p "$tmp/folded/.local"
ln -s "$root/home/.local/bin" "$tmp/folded/.local/bin"
cli="$tmp/folded/.local/bin/nudge"; run 0 doctor
# Relative symlinks must be resolved relative to the link, not the caller's cwd.
ln -s 'stow home/.local/bin/nudge' "$tmp/relative"
cli="$tmp/relative"; run 0 doctor
cli=$saved_cli
pass 'stow file, folded directory, and relative symlink invocation'

# Lua executes the actual fixed entry, with no Hammerspoon or state store.
NUDGE_TEST_LUA_ENTRY="$ipc" "$lua_bin" - <<'LUA'
local path = assert(os.getenv('NUDGE_TEST_LUA_ENTRY'))
local raw = [[{"content":{"title":"\"]; error('injected'); --"}}]]
local reply = '{"ok":true,"exit_code":0}'
local service = {}
service.handle_json = function(self, value)
  assert(self == service, 'handle_json must receive its service receiver')
  assert(value == raw, 'args[2] must arrive unchanged')
  return reply
end
_G.nudge = service
_cli = {args = {path, raw}}
assert(dofile(path) == reply)
for _, unavailable in ipairs({false, {}, {handle_json = false}}) do
  _G.nudge = unavailable
  local result = dofile(path)
  assert(type(result) == 'string' and result:find('"exit_code":4', 1, true))
end
_G.nudge = {handle_json = function() error('private request data') end}
local result = dofile(path)
assert(result:find('"exit_code":4', 1, true) and not result:find('private', 1, true))
_G.nudge = service
_cli = {args = {path}}
assert(dofile(path):find('"exit_code":2', 1, true))
_cli = nil
assert(dofile(path):find('"exit_code":2', 1, true))
LUA
pass 'fixed Lua entry passes data, handles absent service, and suppresses internal errors'

# Perl is a macOS test-only clock; production remains Bash 3.2 + jq + system tools.
now() { /usr/bin/perl -MTime::HiRes=time -e 'printf "%.6f", time'; }
for scenario in hung split preflight; do
  started=$(now)
  case $scenario in
    hung) NUDGE_TEST_MODE=hung run 3 send --title Timeout ;;
    split) NUDGE_TEST_MODE=split run 3 doctor ;;
    preflight) NUDGE_TEST_PROCESS=slow NUDGE_TEST_MODE=delayed run 3 doctor ;;
  esac
  ended=$(now)
  /usr/bin/perl -e '$d=$ARGV[1]-$ARGV[0]; die "deadline: $d seconds\n" unless $d >= 1.8 && $d < 2.6' "$started" "$ended"
  "$jq_bin" -e '.result == "unknown"' "$tmp/out" > /dev/null || fail 'timeout must warn outcome unknown'
  [ "$(wc -l < "$tmp/calls" | tr -d ' ')" = 1 ] || fail 'timeout must not retry'
done
for pidfile in "$tmp/hs.pid" "$tmp/child.pid"; do
  ! kill -0 "$(cat "$pidfile")" 2>/dev/null || fail 'watchdog left a transport process running'
done
NUDGE_TEST_PROCESS=hung run 3 doctor
no_call
[ -z "$(ls -A "$tmp/scratch")" ] || fail 'temporary IPC files leaked'
[ ! -e "$HOME/.nudge" ] || fail 'CLI touched service state'
pass 'two-second total deadline includes preflight, kills transport tree, and never retries'
printf 'PASS: nudge CLI (%s groups)\n' "$passed"
