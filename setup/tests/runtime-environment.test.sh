#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fish_bin=$(command -v fish)
zsh_bin=$(command -v zsh)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/runtime-env.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.local/share/mise/shims" "$tmp/home/.rd/bin" "$tmp/home/.config/fish" "$tmp/home/jdk/bin"
for name in java javac node npm npx kubectl; do
    printf '#!/bin/sh\necho mise-%s\n' "$name" >"$tmp/home/.local/share/mise/shims/$name"
    chmod +x "$tmp/home/.local/share/mise/shims/$name"
done
for name in docker docker-compose docker-buildx kubectl; do
    printf '#!/bin/sh\necho rancher-%s\n' "$name" >"$tmp/home/.rd/bin/$name"
    chmod +x "$tmp/home/.rd/bin/$name"
done
# Model Docker delegating to the matching bundled plugins.
cat >"$tmp/home/.rd/bin/docker" <<'DOCKER'
#!/bin/sh
case "$*" in
  version) echo rancher-docker ;;
  'compose version') exec "$(dirname "$0")/docker-compose" version ;;
  'buildx version') exec "$(dirname "$0")/docker-buildx" version ;;
  *) exit 1 ;;
esac
DOCKER
# Model mise's environment output, including JAVA_HOME, without real project config.
cat >"$tmp/home/.local/share/mise/shims/mise" <<'MISE'
#!/bin/sh
case "$*" in
  'env --shell zsh') printf 'export JAVA_HOME="%s/jdk"\n' "$HOME" ;;
  'env --shell fish') printf 'set -gx JAVA_HOME "%s/jdk"\n' "$HOME" ;;
  *) echo 'Unexpected mise invocation' >&2; exit 1 ;;
esac
MISE
chmod +x "$tmp/home/.local/share/mise/shims/mise"
cp "$root/home/.zshenv" "$tmp/home/.zshenv"
cp "$root/home/.zprofile" "$tmp/home/.zprofile"
for mode in -c -lc; do
    HOME="$tmp/home" SHELL=/opt/homebrew/bin/fish MISE_SHELL=fish "$zsh_bin" "$mode" '
        for name in java javac node npm npx kubectl; do
            [[ $(command "$name") == "mise-$name" ]] || exit 1
        done
        [[ $JAVA_HOME == "$HOME/jdk" ]] || exit 1
        # Model the post-uninstall machine, regardless of the test host brew.
        path=(${path:#/opt/homebrew/bin})
        [[ $(command -v docker) == "$HOME/.rd/bin/docker" ]] || exit 1
        [[ $(command docker version) == rancher-docker ]] || exit 1
        [[ $(command docker compose version) == rancher-docker-compose ]] || exit 1
        [[ $(command docker buildx version) == rancher-docker-buildx ]] || exit 1
        /bin/sh -c '\''test "$JAVA_HOME" = "$HOME/jdk"'\'' || exit 1
    '
done
# In a noninteractive fish, source actual PATH and mise initialization, not prompts.
HOME="$tmp/home" "$fish_bin" --no-config -c '
    # Do not inherit the real user Rancher or mise paths into this fixture.
    set -gx PATH /opt/homebrew/bin /opt/homebrew/sbin /usr/bin /bin /usr/sbin /sbin
    source $argv[1]; or exit 1
    source $argv[2]; or exit 1
    for name in java javac node npm npx kubectl
        test (command $name) = "mise-$name"; or exit 1
    end
    test "$JAVA_HOME" = "$HOME/jdk"; or exit 1
    set -gx PATH (string match -v /opt/homebrew/bin $PATH)
    test (command -s docker) = "$HOME/.rd/bin/docker"; or exit 1
    test (command docker version) = rancher-docker; or exit 1
    test (command docker compose version) = rancher-docker-compose; or exit 1
    test (command docker buildx version) = rancher-docker-buildx; or exit 1
' "$root/home/.config/fish/conf.d/0001-local-bin.fish" "$root/home/.config/fish/conf.d/0100-mise.fish"
mkdir -p "$tmp/stow-home"
stow --simulate --no-folding --target="$tmp/stow-home" --dir="$root/home" .
echo 'PASS: runtime environment (zsh login/nonlogin, inherited sh, noninteractive fish, Stow)'
