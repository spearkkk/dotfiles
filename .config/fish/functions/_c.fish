function _c --description "Echo with foreground, optional background, and style"
    if test (count $argv) -lt 2
        echo "Usage: _c <fg> [bg] [--bold|--underline|--italic] <text...>"
        return 1
    end

    # 파라미터 파싱
    set -l fg $argv[1]
    set -l bg ''
    set -l style ''
    set -l idx 2

    set -l valid_colors black red green yellow blue magenta cyan white \
        brblack brred brgreen bryellow \
        brblue brmagenta brcyan brwhite

    if contains $argv[2] $valid_colors
        set bg $argv[2]
        set idx 3
    end

    if contains -- $argv[$idx] --bold --underline --italic
        set style $argv[$idx]
        set idx (math $idx + 1)
    end

    # ANSI 시작 시퀀스 구성
    set -l sequence (set_color $fg)
    if test -n "$bg"
        set sequence "$sequence"(set_color --background $bg)
    end
    switch $style
        case --bold
            set sequence "$sequence"(set_color --bold)
        case --underline
            set sequence "$sequence"(set_color --underline)
        case --italic
            set sequence "$sequence"(set_color --italic)
    end

    # 출력
    echo -en "$sequence"
    for i in (seq $idx (count $argv))
        echo -n "$argv[$i] "
    end
    echo -e (set_color normal)
end