function _c --description "Styled echo: _c --color <fg> [--background <bg>] [--styles=bold,italic,underline] <text...>"
    set -l fg ''
    set -l bg ''
    set -l styles
    set -l args
    set -l i 1

    set -l valid_colors black red green yellow blue magenta cyan white \
        brblack brred brgreen bryellow brblue brmagenta brcyan brwhite

    while test $i -le (count $argv)
        set -l arg $argv[$i]

        if test $arg = "--color"
            set fg $argv[(math $i + 1)]
            set i (math $i + 2)
            continue
        end

        if test $arg = "--background"
            set bg $argv[(math $i + 1)]
            set i (math $i + 2)
            continue
        end

        if string match -rq '^--styles=' -- $arg
            set -l style_string (string split "=" -- $arg)[2]
            set styles (string split "," -- $style_string)
            set i (math $i + 1)
            continue
        end

        # 첫 번째 옵션 아닌 인자부터는 텍스트
        break
    end

    # 남은 인자들을 출력 텍스트로 간주
    if test $i -le (count $argv)
        set args $argv[$i..-1]
    end

    if test -z "$fg"
        echo "Usage: _c --color <fg> [--background <bg>] [--styles=bold,underline,italic] <text...>"
        return 1
    end

    if not contains -- $fg $valid_colors
        echo "Invalid foreground color: $fg"
        return 1
    end

    if test -n "$bg"; and not contains -- $bg $valid_colors
        echo "Invalid background color: $bg"
        return 1
    end

    set -l sequence (set_color $fg)

    if test -n "$bg"
        set sequence "$sequence"(set_color --background $bg)
    end

    for style in $styles
        switch $style
            case bold
                set sequence "$sequence\e[1m"
            case underline
                set sequence "$sequence\e[4m"
            case italic
                set sequence "$sequence\e[3m"
        end
    end

    echo -en "$sequence"
    for word in $args
        echo -n "$word "
    end
    echo -e "\e[0m"
end