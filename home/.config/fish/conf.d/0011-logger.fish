#!/usr/bin/env fish

# Load theme color definitions when this file is sourced manually.
if not set -q __COLOR_INFO
    set -l theme_colors "$HOME/.config/fish/conf.d/0010-theme-colors.fish"
    if test -f "$theme_colors"
        source "$theme_colors"
    end
end

function __log_color --argument-names color fallback
    if test -n "$color"
        set_color $color 2>/dev/null; and return
    end

    if test -n "$fallback"
        set_color $fallback 2>/dev/null; and return
    end

    set_color normal
end

function __log_badge_color --argument-names color fallback
    set -l bg $__COLOR_BG
    if test -z "$bg"
        set bg black
    end

    if test -n "$color"
        set_color --background $color $bg 2>/dev/null; and return
    end

    if test -n "$fallback"
        set_color --background $fallback $bg 2>/dev/null; and return
    end

    set_color --reverse
end

function __log_line --argument-names stream icon label color fallback
    set -l message
    if test (count $argv) -ge 6
        set message "$argv[6]"
        for part in $argv[7..-1]
            set message "$message $part"
        end
    end

    set -l reset (set_color normal)
    set -l badge_color (__log_badge_color "$color" "$fallback")
    set -l label_color (__log_color "$color" "$fallback")
    set -l message_color (__log_color "$__COLOR_FG" "normal")
    set -l label_text (printf "%-6s" "$label")
    set -l lines (string split \n -- "$message")
    set -l indent (string repeat -n 11 " ")

    if test (count $lines) -eq 0
        set lines ""
    end

    if test "$stream" = stderr
        printf "%s %s %s %s%s%s %s%s%s\n" "$badge_color" "$icon" "$reset" "$label_color" "$label_text" "$reset" "$message_color" "$lines[1]" "$reset" >&2

        for line in $lines[2..-1]
            printf "%s%s%s%s\n" "$indent" "$message_color" "$line" "$reset" >&2
        end
    else
        printf "%s %s %s %s%s%s %s%s%s\n" "$badge_color" "$icon" "$reset" "$label_color" "$label_text" "$reset" "$message_color" "$lines[1]" "$reset"

        for line in $lines[2..-1]
            printf "%s%s%s%s\n" "$indent" "$message_color" "$line" "$reset"
        end
    end
end

function log_section
    set -l message (string join " " $argv)
    set -l reset (set_color normal)
    set -l section_color (__log_color "$__COLOR_ACCENT" "cyan")

    printf "\n%s◆ %s%s\n" "$section_color" "$message" "$reset"
end

function log_step
    __log_line stdout "→" "STEP" "$__COLOR_ACCENT" "cyan" $argv
end

function log_item
    __log_line stdout "•" "ITEM" "$__COLOR_MUTED" "brblack" $argv
end

function log_info
    __log_line stdout "i" "INFO" "$__COLOR_INFO" "cyan" $argv
end

function log_success
    __log_line stdout "✓" "OK" "$__COLOR_SUCCESS" "green" $argv
end

function log_done
    __log_line stdout "✓" "DONE" "$__COLOR_SUCCESS" "green" $argv
end

function log_warn
    __log_line stdout "!" "WARN" "$__COLOR_WARN" "yellow" $argv
end

function log_error
    __log_line stderr "×" "ERR" "$__COLOR_ERROR" "red" $argv
end
