#!/usr/bin/env bash
# Tabler Icons webfont 3.51.0, MIT: https://github.com/tabler/tabler-icons/blob/main/LICENSE
set -euo pipefail
version=3.51.0
font_dir="$HOME/Library/Fonts"
font_name=tabler-icons-300.ttf
regular_name=tabler-icons.ttf
regular_sha=050228e487993da1a1f2a5320ed20dc52c3f26eb8eecace4285ade89c1e21ec6
thin_sha=c19e294c29f3fe6e495c3ec5908c219eceff9e558f0f0589d5f9ac3bbde2b18e
tmp=$(mktemp -d "${TMPDIR:-/tmp}/tabler-fonts.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@$version/dist/fonts/$font_name" -o "$tmp/$font_name"
printf '%s  %s\n' "$thin_sha" "$tmp/$font_name" | shasum -a 256 -c - >/dev/null
if [[ -e "$font_dir/$font_name" ]] && ! cmp -s "$tmp/$font_name" "$font_dir/$font_name"; then
  echo "Font already exists and differs; refusing to overwrite: $font_dir/$font_name" >&2
  exit 1
fi
if [[ -e "$font_dir/$regular_name" ]]; then
  actual=$(shasum -a 256 "$font_dir/$regular_name")
  if [[ "${actual%% *}" != "$regular_sha" ]]; then
    echo "Existing Tabler font is not the version managed by this installer: $font_dir/$regular_name" >&2
    exit 1
  fi
  # Both official TTFs have the same internal font name. Preserve the regular
  # font outside Library/Fonts so Core Text can select the thin font reliably.
  backup_root="$HOME/Library/Application Support/SketchyBar/font-backups"
  mkdir -p "$backup_root"
  backup=$(mktemp -d "$backup_root/tabler-regular.XXXXXX")
  mv "$font_dir/$regular_name" "$backup/$regular_name"
  printf 'Backed up regular font to %s\n' "$backup/$regular_name"
fi
mkdir -p "$font_dir"
if [[ ! -e "$font_dir/$font_name" ]]; then
  install -m 644 "$tmp/$font_name" "$font_dir/$font_name"
fi
printf 'Installed Tabler Icons %s 1.5px font in %s\n' "$version" "$font_dir"
