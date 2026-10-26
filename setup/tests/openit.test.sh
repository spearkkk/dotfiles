#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
openit="$repo_root/home/.local/bin/openit"
tmpdir=$(mktemp -d)
tmpdir=$(cd "$tmpdir" && pwd -P)
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
log_file="$tmpdir/calls.log"
mkdir -p "$fake_bin" "$tmpdir/artifacts"

for command in tmux nvim open; do
  cat >"$fake_bin/$command" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s' "$(basename "$0")" >>"$OPENIT_TEST_LOG"
printf '\t%s' "$@" >>"$OPENIT_TEST_LOG"
printf '\n' >>"$OPENIT_TEST_LOG"
SCRIPT
  chmod +x "$fake_bin/$command"
done

touch "$tmpdir/artifacts/notes.md"
touch "$tmpdir/artifacts/report.html"
touch "$tmpdir/artifacts/screenshot.png"

assert_line() {
  local expected=$1
  if ! grep -Fqx "$expected" "$log_file"; then
    echo "FAIL: expected call not found" >&2
    echo "  $expected" >&2
    echo "Actual calls:" >&2
    cat "$log_file" >&2
    exit 1
  fi
}

: >"$log_file"
env PATH="$fake_bin:/usr/bin:/bin" OPENIT_TEST_LOG="$log_file" TMUX="test-session" \
  "$openit" "$tmpdir/artifacts/notes.md"
assert_line $'tmux\tnew-window\t-n\tview:notes.md\t-c\t'"$tmpdir/artifacts"$'\tnvim\t--\t'"$tmpdir/artifacts/notes.md"

: >"$log_file"
env -u TMUX PATH="$fake_bin:/usr/bin:/bin" OPENIT_TEST_LOG="$log_file" \
  "$openit" "$tmpdir/artifacts/notes.md"
assert_line $'open\t-na\tGhostty\t--args\t-e\tnvim\t--\t'"$tmpdir/artifacts/notes.md"

for artifact in report.html screenshot.png; do
  : >"$log_file"
  env PATH="$fake_bin:/usr/bin:/bin" OPENIT_TEST_LOG="$log_file" TMUX="test-session" \
    "$openit" "$tmpdir/artifacts/$artifact"
  assert_line $'open\t-na\tGoogle Chrome\t--args\t--new-window\t'"$tmpdir/artifacts/$artifact"
done

: >"$log_file"
env PATH="$fake_bin:/usr/bin:/bin" OPENIT_TEST_LOG="$log_file" \
  "$openit" "https://localhost:3000/preview"
assert_line $'open\t-na\tGoogle Chrome\t--args\t--new-window\thttps://localhost:3000/preview'

if env PATH="$fake_bin:/usr/bin:/bin" OPENIT_TEST_LOG="$log_file" "$openit" "$tmpdir/missing.pdf" 2>/dev/null; then
  echo "FAIL: missing artifacts must be rejected" >&2
  exit 1
fi

echo "PASS: openit"
