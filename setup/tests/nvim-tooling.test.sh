#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
test_home=$(mktemp -d "${TMPDIR:-/tmp}/nvim-tooling.XXXXXX")
trap 'rm -rf "$test_home"' EXIT

export HOME="$test_home/home"
export XDG_CONFIG_HOME="$test_home/config"
export XDG_DATA_HOME="$test_home/data"
export XDG_CACHE_HOME="$test_home/cache"
export XDG_STATE_HOME="$test_home/state"
export REPO_ROOT="$repo_root"
export NVIM_TEST_ROOT="$test_home"

nvim --clean --headless -l "$repo_root/setup/tests/nvim-tooling.test.lua"
nvim --clean --headless -l "$repo_root/setup/tests/nvim-initialization.test.lua"
