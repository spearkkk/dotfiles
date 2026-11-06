#!/usr/bin/env bash

set -eu

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/ssh-config.XXXXXX")

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

sed \
  -e "s|Include ~/.ssh/config.local|Include \"$tmpdir/config.local\"|" \
  -e "s|Include ~/.ssh/config.d/\\*.conf|Include \"$tmpdir/config.d/*.conf\"|" \
  "$repo_root/home/.ssh/config" >"$tmpdir/config"

assert_option() {
  option=$1
  expected=$2
  actual=$(printf '%s\n' "$resolved" | awk -v option="$option" '$1 == option { sub(/^[^[:space:]]+[[:space:]]+/, ""); print; exit }')
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: ssh-config: expected %s=%s, got %s\n' "$option" "$expected" "${actual:-<unset>}" >&2
    exit 1
  fi
}

# ssh -G only resolves configuration; it never connects or needs a real key.
# -F and rewritten Include paths keep the user's SSH files out of every case.
resolved=$(ssh -G -T -F "$tmpdir/config" github.com)
assert_option hostname github.com
assert_option user git
assert_option identitiesonly yes
assert_option addkeystoagent true
assert_option identityfile '~/.ssh/id_ed25519_github'

mkdir -p "$tmpdir/config.d"
cat >"$tmpdir/config.d/0200-fixture.conf" <<EOF
Host dotfiles-test.invalid
    User fixture-profile
    IdentityFile "$tmpdir/id_ed25519_fixture"
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF
resolved=$(ssh -G -T -F "$tmpdir/config" dotfiles-test.invalid)
assert_option user fixture-profile
assert_option identityfile "$tmpdir/id_ed25519_fixture"
assert_option identitiesonly yes
assert_option addkeystoagent true

# OpenSSH uses the first value: local settings must precede profile overlays.
cat >"$tmpdir/config.local" <<'EOF'
Host dotfiles-test.invalid
    User fixture-local
EOF
resolved=$(ssh -G -T -F "$tmpdir/config" dotfiles-test.invalid)
assert_option user fixture-local
assert_option identityfile "$tmpdir/id_ed25519_fixture"

printf 'PASS: ssh-config (base defaults, fixture overlay, local precedence)\n'
