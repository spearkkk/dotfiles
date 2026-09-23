#!/usr/bin/env fish

# Fish syntax highlighting colors derived from the active dotfiles theme.
#
# Keep these as global variables instead of universal variables so the repo
# remains the source of truth and fish_variables does not need manual theme
# state.
#
# Note: fish exposes one fish_color_command category for any valid command
# token, including builtins, external commands, and user-defined functions.
# It does not expose a separate highlight category for "custom function typed
# as a command", so l/cd/etc. cannot be colored differently at prompt-edit
# time without a custom highlighter.

if not set -q __COLOR_SYNTAX_FUNCTION
    set -l theme_colors "$HOME/.config/fish/conf.d/0010-theme-colors.fish"

    if test -f "$theme_colors"
        source "$theme_colors"
    end
end

function __fish_theme_color --argument-names color fallback
    if test -n "$color"
        echo "$color"
    else
        echo "$fallback"
    end
end

# Core command-line syntax.
set -g fish_color_normal       (__fish_theme_color "$__COLOR_FG" normal)
set -g fish_color_command      (__fish_theme_color "$__COLOR_SYNTAX_FUNCTION" blue)
set -g fish_color_keyword      (__fish_theme_color "$__COLOR_SYNTAX_KEYWORD" magenta)
set -g fish_color_param        (__fish_theme_color "$__COLOR_FG" normal)
set -g fish_color_option       (__fish_theme_color "$__COLOR_SYNTAX_PROPERTY" brblue)
set -g fish_color_quote        (__fish_theme_color "$__COLOR_SYNTAX_STRING" green)
set -g fish_color_redirection  (__fish_theme_color "$__COLOR_SYNTAX_OPERATOR" cyan)
set -g fish_color_operator     (__fish_theme_color "$__COLOR_SYNTAX_OPERATOR" cyan)
set -g fish_color_end          (__fish_theme_color "$__COLOR_SYNTAX_KEYWORD" magenta)
set -g fish_color_escape       (__fish_theme_color "$__COLOR_SYNTAX_CONSTANT" brmagenta)
set -g fish_color_comment      (__fish_theme_color "$__COLOR_SYNTAX_COMMENT" brblack)
set -g fish_color_error        (__fish_theme_color "$__COLOR_ERROR" red)

# Paths, history, autosuggestions, and selection.
set -g fish_color_valid_path        --underline (__fish_theme_color "$__COLOR_LINK" blue)
set -g fish_color_autosuggestion    (__fish_theme_color "$__COLOR_FG_MUTED" brblack)
set -g fish_color_history_current   --bold (__fish_theme_color "$__COLOR_PRIMARY" blue)
set -g fish_color_search_match      --background=(__fish_theme_color "$__COLOR_SEARCH_BG" yellow) (__fish_theme_color "$__COLOR_SEARCH_FG" black)
set -g fish_color_selection         --background=(__fish_theme_color "$__COLOR_SELECTION_BG" brblack) (__fish_theme_color "$__COLOR_SELECTION_FG" white)
set -g fish_color_cancel            (__fish_theme_color "$__COLOR_ERROR" red)

# Completion pager.
set -g fish_pager_color_progress      (__fish_theme_color "$__COLOR_FG_MUTED" brblack)
set -g fish_pager_color_prefix        --bold (__fish_theme_color "$__COLOR_MATCH" yellow)
set -g fish_pager_color_completion    (__fish_theme_color "$__COLOR_FG" normal)
set -g fish_pager_color_description   (__fish_theme_color "$__COLOR_FG_MUTED" brblack)
set -g fish_pager_color_selected_prefix      --background=(__fish_theme_color "$__COLOR_SELECTION_BG" brblack) --bold (__fish_theme_color "$__COLOR_MATCH" yellow)
set -g fish_pager_color_selected_completion  --background=(__fish_theme_color "$__COLOR_SELECTION_BG" brblack) (__fish_theme_color "$__COLOR_SELECTION_FG" white)
set -g fish_pager_color_selected_description --background=(__fish_theme_color "$__COLOR_SELECTION_BG" brblack) (__fish_theme_color "$__COLOR_FG_MUTED" brblack)

functions -e __fish_theme_color
