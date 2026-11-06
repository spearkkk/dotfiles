# macOS path_helper runs after .zshenv in login shells.
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv zsh)"
fi

[[ ! -r "$HOME/.zprofile.local" ]] || source "$HOME/.zprofile.local"
path=("$HOME/.local/bin" "$HOME/.local/share/mise/shims" $path)
