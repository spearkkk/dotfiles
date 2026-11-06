# Shared by login, interactive and noninteractive zsh (including agent commands).
# Homebrew supplies system tools; mise owns runtimes; Rancher supplies Docker.
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.local/share/mise/shims"
      /opt/homebrew/bin /opt/homebrew/sbin "$HOME/.rd/bin" $path)

# Shims alone do not export JAVA_HOME to external Java launchers or child sh.
if command -v mise >/dev/null 2>&1; then
    if _mise_env=$(command mise env --shell zsh); then
        eval "$_mise_env"
    fi
    unset _mise_env
fi
