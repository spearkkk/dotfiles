#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/codext-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/mktemp" <<'EOF'
#!/bin/sh
mkdir -p "$CODEXT_TEST_WORKSPACE"
printf '%s\n' "$CODEXT_TEST_WORKSPACE"
EOF
cat >"$tmp/bin/codex" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$CODEXT_TEST_LOG"
EOF
chmod +x "$tmp/bin/mktemp" "$tmp/bin/codex"

workspace="$tmp/workspace"
log="$tmp/codex.log"
env PATH="$tmp/bin:$PATH" \
  CODEXT_TEST_WORKSPACE="$workspace" \
  CODEXT_TEST_LOG="$log" \
  fish --no-config --command \
    "source '$repo_root/home/.config/fish/functions/codext.fish'; codext 'review notes' --search"

expected=$(printf '%s\n' -C "$workspace" 'review notes' --search)
actual=$(cat "$log")
[ "$actual" = "$expected" ] || {
  printf 'FAIL: unexpected codex arguments:\n%s\n' "$actual" >&2
  exit 1
}

printf 'PASS: codext\n'
