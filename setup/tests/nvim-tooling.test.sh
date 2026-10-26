#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
state_home=$(mktemp -d "${TMPDIR:-/tmp}/nvim-tooling-state.XXXXXX")
trap 'rm -rf "$state_home"' EXIT

XDG_STATE_HOME="$state_home" REPO_ROOT="$repo_root" nvim --clean --headless \
  -l "$repo_root/setup/tests/nvim-tooling.test.lua"
