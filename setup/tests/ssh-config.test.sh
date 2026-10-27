#!/usr/bin/env bash

set -eu

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/ssh-config.XXXXXX")

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

sed \
  -e "s|Include ~/.ssh/config.local|Include $tmpdir/missing-config.local|" \
  -e "s|Include ~/.ssh/config.d/\\*.conf|Include $repo_root/profiles/work/home/.ssh/config.d/0200-work.conf|" \
  "$repo_root/home/.ssh/config" >"$tmpdir/config"

resolved=$(ssh -G -F "$tmpdir/config" git.linecorp.com 2>/dev/null)

assert_option() {
  option=$1
  expected=$2
  actual=$(printf '%s\n' "$resolved" | awk -v option="$option" '$1 == option { print $2; exit }')
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: ssh-config: expected %s=%s, got %s\n' "$option" "$expected" "${actual:-<unset>}" >&2
    exit 1
  fi
}

assert_option user git
assert_option identitiesonly yes
assert_option addkeystoagent true

identity=$(printf '%s\n' "$resolved" | awk '$1 == "identityfile" { print $2; exit }')
case $identity in
  */.ssh/id_ed25519) ;;
  *)
    printf 'FAIL: ssh-config: work identity was not selected\n' >&2
    exit 1
    ;;
esac

printf 'PASS: ssh-config\n'
