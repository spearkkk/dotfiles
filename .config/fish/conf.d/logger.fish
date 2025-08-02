#!/usr/bin/env fish

# Load color definitions
if not functions -q __dotfiles_colors_loaded
    source ~/.config/fish/conf.d/colors.fish
    function __dotfiles_colors_loaded; end
end

# ANSI 로그용 색상 (fallback, 이미 colors.fish에 있음)
set -g COLOR_ANSI_INFO   (set_color $COLOR_INFO)
set -g COLOR_ANSI_OK     (set_color $COLOR_SUCCESS)
set -g COLOR_ANSI_WARN   (set_color $COLOR_WARN)
set -g COLOR_ANSI_ERR    (set_color $COLOR_ERROR)
set -g COLOR_ANSI_RESET  (set_color normal)

# 로그 함수들
function log_info
    echo -s $COLOR_ANSI_INFO"[INFO ] "$COLOR_ANSI_RESET $argv
end

function log_success
    echo -s $COLOR_ANSI_OK"[ OK  ] "$COLOR_ANSI_RESET $argv
end

function log_warn
    echo -s $COLOR_ANSI_WARN"[WARN ] "$COLOR_ANSI_RESET $argv
end

function log_error
    echo -s $COLOR_ANSI_ERR"[ERROR] "$COLOR_ANSI_RESET $argv
end