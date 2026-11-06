#!/usr/bin/env bash
# Preserve an unmanaged login profile before bootstrap lets Stow own its path.
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
managed="$script_dir/../home/.zprofile"
profile="$HOME/.zprofile"
local_profile="$HOME/.zprofile.local"

fail() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

if [[ -L "$profile" ]]; then
  [[ "$profile" -ef "$managed" ]] && exit 0
  fail "$profile is a foreign or broken symlink; review it before retrying bootstrap."
fi
[[ -e "$profile" ]] || exit 0
[[ -f "$profile" ]] || fail "$profile is not a regular file."

migrate=yes
# Only omit known whole-file boilerplate. Do not rewrite arbitrary shell code.
if [[ ! -s "$profile" ]] || cmp -s "$profile" "$managed"; then
  migrate=no
else
  contents="$(cat "$profile")"
  case "$contents" in
    'eval "$(/opt/homebrew/bin/brew shellenv)"'|'eval "$(/usr/local/bin/brew shellenv)"')
      migrate=no ;;
  esac
fi

if [[ "$migrate" == yes ]]; then
  if [[ -e "$local_profile" || -L "$local_profile" ]]; then
    fail "Both $profile and $local_profile contain local state. Back up and merge them manually, then move the old .zprofile aside and retry. Neither file was changed."
  fi
  # Moving a loader into the file it sources would create recursive startup.
  if grep -Fq '.zprofile.local' "$profile"; then
    fail "$profile already references .zprofile.local; manually separate local settings before retrying. No files were changed."
  fi
fi

backup_root="$HOME/.local/state/dotfiles/backups"
mkdir -p "$backup_root"
backup_dir="$(mktemp -d "$backup_root/zprofile.XXXXXX")"

if [[ "$migrate" == yes ]]; then
  # noclobber also prevents following a local symlink introduced meanwhile.
  (set -C; cat "$profile" > "$local_profile")
  printf '[INFO] Preserved local settings in %s; review any duplicate Homebrew initialization.\n' "$local_profile"
fi

mv "$profile" "$backup_dir/.zprofile"
printf '[INFO] Backed up original profile to %s/.zprofile\n' "$backup_dir"
