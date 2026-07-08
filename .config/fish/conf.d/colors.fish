#!/usr/bin/env fish

set -l generated_candidates \
    "$HOME/.config/fish/conf.d/colors_generated.fish" \
    "$HOME/.dotfiles/.config/fish/conf.d/colors_generated.fish"

for generated_colors in $generated_candidates
    if test -f "$generated_colors"
        source "$generated_colors"
        break
    end
end

if not set -q BASE00
    set -gx BASE00 0A1F2E
    set -gx BASE01 142C3E
    set -gx BASE02 1C3A50
    set -gx BASE03 24425C
    set -gx BASE04 4A6E86
    set -gx BASE05 C6D8E4
    set -gx BASE06 D6E2E8
    set -gx BASE07 ECF0F4
    set -gx BASE08 C47A72
    set -gx BASE09 C8945A
    set -gx BASE0A C8AE6A
    set -gx BASE0B 68BE92
    set -gx BASE0C 50C4C0
    set -gx BASE0D 7896CC
    set -gx BASE0E 9A7EC8
    set -gx BASE0F 8C6040
    set -gx BASE10 071420
    set -gx BASE11 D08880
    set -gx BASE12 D4A870
    set -gx BASE13 D4BE82
    set -gx BASE14 80CCAA
    set -gx BASE15 68D4D0
    set -gx BASE16 90AED8
    set -gx BASE17 AE96D4
end

if not set -q COLOR_BG
    set -gx COLOR_BG        $BASE00
    set -gx COLOR_BG_ALT    $BASE01
    set -gx COLOR_FG        $BASE05
    set -gx COLOR_ACCENT    $BASE0C
    set -gx COLOR_MUTED     $BASE04
    set -gx COLOR_ERROR     $BASE08
    set -gx COLOR_WARN      $BASE0A
    set -gx COLOR_SUCCESS   $BASE0B
    set -gx COLOR_LINK      $BASE0D
    set -gx COLOR_INFO      $BASE0C
    set -gx COLOR_HIGHLIGHT $BASE09
end

set -g COLOR_ANSI_BLACK        (set_color black)
set -g COLOR_ANSI_RED          (set_color red)
set -g COLOR_ANSI_GREEN        (set_color green)
set -g COLOR_ANSI_YELLOW       (set_color yellow)
set -g COLOR_ANSI_BLUE         (set_color blue)
set -g COLOR_ANSI_MAGENTA      (set_color magenta)
set -g COLOR_ANSI_CYAN         (set_color cyan)
set -g COLOR_ANSI_WHITE        (set_color white)

set -g COLOR_ANSI_BRIGHT_BLACK   (set_color --bold black)
set -g COLOR_ANSI_BRIGHT_RED     (set_color --bold red)
set -g COLOR_ANSI_BRIGHT_GREEN   (set_color --bold green)
set -g COLOR_ANSI_BRIGHT_YELLOW  (set_color --bold yellow)
set -g COLOR_ANSI_BRIGHT_BLUE    (set_color --bold blue)
set -g COLOR_ANSI_BRIGHT_MAGENTA (set_color --bold magenta)
set -g COLOR_ANSI_BRIGHT_CYAN    (set_color --bold cyan)
set -g COLOR_ANSI_BRIGHT_WHITE   (set_color --bold white)

set -g COLOR_ANSI_BG_RED      (set_color --background red)
set -g COLOR_ANSI_BG_GREEN    (set_color --background green)
set -g COLOR_ANSI_BG_YELLOW   (set_color --background yellow)
set -g COLOR_ANSI_BG_BLUE     (set_color --background blue)
set -g COLOR_ANSI_BG_MAGENTA  (set_color --background magenta)
set -g COLOR_ANSI_BG_CYAN     (set_color --background cyan)
set -g COLOR_ANSI_BG_BLACK    (set_color --background black)
set -g COLOR_ANSI_BG_WHITE    (set_color --background white)

set -g COLOR_ANSI_INFO        (set_color $COLOR_INFO)
set -g COLOR_ANSI_OK          (set_color $COLOR_SUCCESS)
set -g COLOR_ANSI_WARN        (set_color $COLOR_WARN)
set -g COLOR_ANSI_ERR         (set_color $COLOR_ERROR)
set -g COLOR_ANSI_RESET       (set_color normal)
