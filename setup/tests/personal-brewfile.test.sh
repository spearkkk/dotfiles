#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
bootstrap="$repo_root/profiles/personal/setup/bootstrap.fish"
brewfile="$repo_root/profiles/personal/setup/Brewfile"

test -f "$brewfile"
grep -Fq 'brew bundle install --file "$profile_brewfile"' "$bootstrap"

echo "PASS: personal-brewfile"
