#!/usr/bin/env fish

if not status is-interactive
    return
end

function __dot_welcome_time_and_date
    set_color cyan
    set -l kst_date (date "+%Y-%m-%d (%A) %H:%M")
    echo "🇰🇷 $kst_date"

    set -l italy_time (TZ=Europe/Rome date "+%Y-%m-%d (%A) %H:%M")
    echo "🇮🇹 $italy_time"
    set_color normal
end

function __dot_welcome_list_custom_functions
    set_color yellow
    echo "🛠️  Custom Fish Functions:"
    set_color normal

    for fn in (functions -n)
        # _로 시작하는 함수 제외
        if string match -rq '^_' $fn
            continue
        end

        # 정의된 함수 경로 확인
        set -l fn_path (functions -D $fn 2> /dev/null)
        if string match -q "$HOME/.config/fish/functions/*" $fn_path
            set_color blue
            echo -n "• "
            set_color brgreen
            echo -n $fn
            set_color normal

            echo ""
        end
    end
end

function __dot_welcome_show
    set_color green
    echo "────────────────────────────────────────────────────────"
    echo "🌊 Welcome back, $USER — Ready to dive in with Fish"
    echo "────────────────────────────────────────────────────────"
    set_color normal

    __dot_welcome_time_and_date
    #    echo ""
    #__dot_welcome_list_custom_functions
    echo ""
end

__dot_welcome_show
functions -e __dot_welcome_time_and_date
functions -e __dot_welcome_list_custom_functions
functions -e __dot_welcome_show
