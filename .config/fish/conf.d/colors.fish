#!/usr/bin/env fish

# Standard ANSI foreground colors
set -g COLOR_ANSI_BLACK        (set_color black)
set -g COLOR_ANSI_RED          (set_color red)
set -g COLOR_ANSI_GREEN        (set_color green)
set -g COLOR_ANSI_YELLOW       (set_color yellow)
set -g COLOR_ANSI_BLUE         (set_color blue)
set -g COLOR_ANSI_MAGENTA      (set_color magenta)
set -g COLOR_ANSI_CYAN         (set_color cyan)
set -g COLOR_ANSI_WHITE        (set_color white)

# Bright versions (foreground)
set -g COLOR_ANSI_BRIGHT_BLACK   (set_color --bold black)
set -g COLOR_ANSI_BRIGHT_RED     (set_color --bold red)
set -g COLOR_ANSI_BRIGHT_GREEN   (set_color --bold green)
set -g COLOR_ANSI_BRIGHT_YELLOW  (set_color --bold yellow)
set -g COLOR_ANSI_BRIGHT_BLUE    (set_color --bold blue)
set -g COLOR_ANSI_BRIGHT_MAGENTA (set_color --bold magenta)
set -g COLOR_ANSI_BRIGHT_CYAN    (set_color --bold cyan)
set -g COLOR_ANSI_BRIGHT_WHITE   (set_color --bold white)

# Background colors (use with echo -e + escape sequences if needed)
set -g COLOR_ANSI_BG_RED      (set_color --background red)
set -g COLOR_ANSI_BG_GREEN    (set_color --background green)
set -g COLOR_ANSI_BG_YELLOW   (set_color --background yellow)
set -g COLOR_ANSI_BG_BLUE     (set_color --background blue)
set -g COLOR_ANSI_BG_MAGENTA  (set_color --background magenta)
set -g COLOR_ANSI_BG_CYAN     (set_color --background cyan)
set -g COLOR_ANSI_BG_BLACK    (set_color --background black)
set -g COLOR_ANSI_BG_WHITE    (set_color --background white)

# Semantic aliases
set -g COLOR_ANSI_INFO        (set_color cyan)
set -g COLOR_ANSI_OK          (set_color green)
set -g COLOR_ANSI_WARN        (set_color yellow)
set -g COLOR_ANSI_ERR         (set_color red)
set -g COLOR_ANSI_RESET       (set_color normal)

# Deep Oceanic Next (Hex colors: no 0xFF prefix)
set -gx BASE00 001C1F
set -gx BASE01 002931
set -gx BASE02 003640
set -gx BASE03 004852
set -gx BASE04 0093A3
set -gx BASE05 D4E1E8
set -gx BASE06 E0E9EF
set -gx BASE07 F2F7F9
set -gx BASE08 D3464D
set -gx BASE09 E37552
set -gx BASE0A F3B863
set -gx BASE0B 63B784
set -gx BASE0C 4FB7AE
set -gx BASE0D 568CCF
set -gx BASE0E 8B66D6
set -gx BASE0F D0658E
set -gx BASE10 1F2628
set -gx BASE11 2A2F30
set -gx BASE12 FF6670
set -gx BASE13 FFE08A
set -gx BASE14 72E1A6
set -gx BASE15 4DE3E3
set -gx BASE16 5CAEFF
set -gx BASE17 B788FF

# 논리적 이름 (for UI/theming)
set -gx COLOR_BG        $BASE00
set -gx COLOR_BG_ALT    $BASE01
set -gx COLOR_FG        $BASE05
set -gx COLOR_ACCENT    $BASE04
set -gx COLOR_MUTED     $BASE03
set -gx COLOR_ERROR     $BASE08
set -gx COLOR_WARN      $BASE09
set -gx COLOR_SUCCESS   $BASE0B
set -gx COLOR_LINK      $BASE0D
set -gx COLOR_INFO      $BASE0C
set -gx COLOR_HIGHLIGHT $BASE0A