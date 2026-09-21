#!/usr/bin/env fish

if status is-interactive
    # Enable colors for macOS/BSD ls-compatible tools.
    set -gx CLICOLOR 1

    # Let bat use the terminal palette so it follows the active Ghostty theme.
    if type -q bat
        set -gx BAT_THEME ansi

        # Expand typed `cat` to colored `bat` without changing scripts/functions.
        abbr --add cat 'bat --paging=never --style=plain'
    end
end
