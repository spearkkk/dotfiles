#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
helper="$root/home/.config/fish/functions/__prefer_homebrew_kubectl.fish"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/homebrew-kubectl.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/home/.local/libexec/homebrew-kubectl" "$tmpdir/rancher" "$tmpdir/mise"
for name in kubectl docker rdctl; do
    printf '#!/bin/sh\necho rancher-%s\n' "$name" >"$tmpdir/rancher/$name"
    chmod +x "$tmpdir/rancher/$name"
done
printf '#!/bin/sh\necho mise-node\n' >"$tmpdir/mise/node"
chmod +x "$tmpdir/mise/node"
printf '#!/bin/sh\nprintf "brew-kubectl:%%s\\n" "$*"\n' >"$tmpdir/home/.local/libexec/homebrew-kubectl/kubectl"
chmod +x "$tmpdir/home/.local/libexec/homebrew-kubectl/kubectl"
HOME="$tmpdir/home" fish --no-config -c '
    source $argv[1]; or exit 1
    # Model config.fish prepending Rancher after conf.d/mise initialization.
    set -gx PATH $argv[2]/rancher $argv[2]/mise $PATH
    set original_path $PATH
    __prefer_homebrew_kubectl; or exit 1
    test (command kubectl get pods) = "brew-kubectl:get pods"; or exit 1
    test (command docker) = rancher-docker; or exit 1
    test (command rdctl) = rancher-rdctl; or exit 1
    test (command node) = mise-node; or exit 1
    test (string join : -- $PATH[2..-1]) = (string join : -- $original_path); or exit 1
    set once $PATH
    __prefer_homebrew_kubectl; or exit 1
    test (string join : -- $PATH) = (string join : -- $once); or exit 1
' "$helper" "$tmpdir"
# Missing Homebrew override must not introduce a broken PATH entry.
HOME="$tmpdir/missing-home" fish --no-config -c '
    source $argv[1]; or exit 1
    set before $PATH
    __prefer_homebrew_kubectl
    test (string join : -- $PATH) = (string join : -- $before)
' "$helper"
# Base installation must remain compatible with Stow (absolute source links fail).
mkdir -p "$tmpdir/stow-home"
if ! stow --simulate --no-folding --target="$tmpdir/stow-home" --dir="$root/home" . >"$tmpdir/stow.log" 2>&1; then
    cat "$tmpdir/stow.log" >&2
    exit 1
fi
echo 'PASS: homebrew-kubectl selective PATH override'
