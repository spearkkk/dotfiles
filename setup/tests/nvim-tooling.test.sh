#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

REPO_ROOT="$repo_root" nvim --clean --headless \
  -l "$repo_root/setup/tests/nvim-tooling.test.lua"
