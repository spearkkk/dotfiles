#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "Usage: bash setup/sync-simhae.sh <simhae-theme-checkout>" >&2
  exit 2
fi
source_root=$(cd "$1" && pwd -P)
consumer_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
node "$source_root/scripts/sync-palette.mjs" --source "$source_root" --target "$consumer_root" --kind dotfiles
