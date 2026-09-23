function ctx --description 'Show compact shell context'

    function _ctx_color --argument-names color fallback
        if test -n "$color"
            set_color $color 2>/dev/null; and return
        end

        if test -n "$fallback"
            set_color $fallback 2>/dev/null; and return
        end

        set_color normal
    end

    function _ctx_badge_color --argument-names color fallback
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

    function _ctx_hex_color --argument-names color fallback
        if test -n "$color"
            echo "#$color"
        else
            echo "$fallback"
        end
    end

    function _tag --argument-names label
        set -l reset (set_color normal)
        set -l badge_color (_ctx_badge_color "$__COLOR_SUCCESS" green)
        set -l text (printf ' %-4s ' (string lower -- (string sub -l 4 -- "$label")))

        printf "%s%s%s" "$badge_color" "$text" "$reset"
    end

    function _ctx_line --argument-names label val branch
        set -l prefix ''
        set -l reset (set_color normal)
        set -l value_color (_ctx_color "$__COLOR_FG" white)
        set -l branch_color (_ctx_badge_color "$__COLOR_SUCCESS" green)

        if test "$branch" = last
            set prefix "$branch_color  └──$reset"
        end

        printf "%s%s  %s%s%s\n" "$prefix" (_tag "$label") "$value_color" "$val" "$reset"
    end

    function _ctx_inner_box --argument-names title
        set -l rows $argv[2..-1]
        set -l reset (set_color normal)
        set -l border_color (_ctx_color "$__COLOR_SUCCESS" green)
        set -l label_bg (_ctx_badge_color "$__COLOR_SUCCESS" green)
        set -l value_color (_ctx_color "$__COLOR_FG" white)
        set -l plain_lines
        set -l styled_lines
        set -l max_len 0

        for row in $rows
            set -l parts (string split "|" -- "$row")
            set -l label (string lower -- "$parts[1]")
            set -l value "$parts[2]"
            set -l label_plain (printf ' %-7s ' (string sub -l 7 -- "$label"))
            set -l plain_line (printf "%s %s" "$label_plain" "$value")
            set -l styled_line (printf "%s%s%s %s%s%s" "$label_bg" "$label_plain" "$reset" "$value_color" "$value" "$reset")

            set -a plain_lines "$plain_line"
            set -a styled_lines "$styled_line"

            set -l len (string length --visible -- "$plain_line")
            if test $len -gt $max_len
                set max_len $len
            end
        end

        set -l inner_width (math "$max_len + 2")
        set -l title_plain (printf ' %s ' (string lower -- "$title"))
        set -l title_segment_plain "─$title_plain"
        set -l title_segment_len (string length --visible -- "$title_segment_plain")

        if test $inner_width -lt $title_segment_len
            set inner_width $title_segment_len
        end

        set -l title_segment "─$title_plain"
        printf "%s╭%s%s%s╮%s\n" \
            "$border_color" \
            "$title_segment" \
            "$border_color" \
            (string repeat -n (math "$inner_width - $title_segment_len") "─") \
            "$reset"

        for index in (seq (count $plain_lines))
            set -l plain_line "$plain_lines[$index]"
            set -l styled_line "$styled_lines[$index]"
            set -l len (string length --visible -- "$plain_line")

            printf "%s│%s %s%s %s│%s\n" \
                "$border_color" \
                "$reset" \
                "$styled_line" \
                (string repeat -n (math "$max_len - $len") " ") \
                "$border_color" \
                "$reset"
        end

        printf "%s╰%s╯%s\n" "$border_color" (string repeat -n $inner_width "─") "$reset"
    end

    function _ctx_outer_box --argument-names content
        set -l reset (set_color normal)
        set -l border_color (_ctx_color "$__COLOR_SUCCESS" green)
        set -l lines (string split \n -- "$content")
        set -l max_len 0

        for line in $lines
            set -l len (string length --visible -- "$line")
            if test $len -gt $max_len
                set max_len $len
            end
        end

        printf "%s╭%s╮%s\n" "$border_color" (string repeat -n (math "$max_len + 2") "─") "$reset"

        for line in $lines
            set -l len (string length --visible -- "$line")
            printf "%s│%s %s%s %s│%s\n" \
                "$border_color" \
                "$reset" \
                "$line" \
                (string repeat -n (math "$max_len - $len") " ") \
                "$border_color" \
                "$reset"
        end

        printf "%s╰%s╯%s\n" "$border_color" (string repeat -n (math "$max_len + 2") "─") "$reset"
    end

    function _ctx_capture --argument-names timeout_ms
        set -l tmp (mktemp)

        if test "$argv[2]" = command
            command $argv[3..-1] >$tmp 2>/dev/null &
        else
            $argv[2..-1] >$tmp 2>/dev/null &
        end
        set -l pid $last_pid

        sleep (math "$timeout_ms / 1000") &
        set -l timer_pid $last_pid
        wait -n $pid $timer_pid >/dev/null 2>&1

        if kill -0 $pid >/dev/null 2>&1
            kill $pid >/dev/null 2>&1
            rm -f $tmp
            return 124
        end

        kill $timer_pid >/dev/null 2>&1
        string collect <$tmp
        rm -f $tmp
    end

    function _ctx_tmux_option --argument-names option
        set -l value (tmux show-options -p -v -t "$TMUX_PANE" $option 2>/dev/null)
        if test -n "$value"
            echo $value
            return
        end

        tmux show-options -w -v -t "$TMUX_PANE" $option 2>/dev/null
    end

    function _ctx_emit
        ### Tmux ###
        if set -q TMUX_PANE; and type -q tmux
            set -l tmux_session (tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null)
            set -l tmux_window (tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null)
            set -l tmux_pane (tmux display-message -p -t "$TMUX_PANE" '#P' 2>/dev/null)
            set -l tmux_label

            if test -n "$tmux_session" -o -n "$tmux_window"
                set tmux_label "$tmux_session:$tmux_window.$tmux_pane"
            end

            set -l tmux_kube_ctx (_ctx_tmux_option @kube_context)

            if test -n "$tmux_label"; and test -n "$tmux_kube_ctx"
                _ctx_inner_box tmux "session|$tmux_label" "k8s|$tmux_kube_ctx"
            else if test -n "$tmux_label"
                _ctx_line tmux "$tmux_label"
            else if test -n "$tmux_kube_ctx"
                _ctx_line k8s $tmux_kube_ctx
            end
        end

        ### Git ###
        if test -d .git; or command git rev-parse --is-inside-work-tree >/dev/null 2>&1
            set branch (command git symbolic-ref --short HEAD 2>/dev/null)
            test -z "$branch"; and set branch (command git rev-parse --short HEAD 2>/dev/null)

            if test -n "$branch"
                _ctx_line git $branch
            end
        end

        ### Docker ###
        if type -q docker
            docker version >/dev/null 2>&1
            if test $status -eq 0
                set -l docker_ctx (docker context show 2>/dev/null)
                if test -n "$docker_ctx"
                    _ctx_line dckr $docker_ctx
                end
            end
        end

        ### Kubernetes ###
        if type -q kubectl
            set -l kube_ctx (_ctx_capture 500 command kubectl config current-context)
            if test -n "$kube_ctx"
                _ctx_line k8s $kube_ctx
            end
        end

        ### Mise ###
        if type -q mise
            set -l mise_output (mise current 2>/dev/null | string join ', ')
            if test -n "$mise_output"
                _ctx_line mise $mise_output
            end
        end

        ### AWS ###
        if type -q aws
            set -l profile (string replace -r 'profile ' '' (aws configure get profile 2>/dev/null || echo $AWS_PROFILE))
            set -l region (aws configure get region 2>/dev/null)

            if test -z "$profile"
                set profile default
            end

            if test -z "$region"; and test -f ~/.aws/config
                set region (string trim (grep region ~/.aws/config 2>/dev/null | head -n1 | string replace -r 'region\s*=\s*' ''))
            end

            if test -n "$profile" -o -n "$region"
                _ctx_line aws "$profile $region"
            end
        end
    end

    set -l ctx_output (_ctx_emit | string collect)

    if test -z "$ctx_output"
        return
    end

    if type -q gum
        # Draw the outer box manually instead of piping through gum style.
        # gum strips nested ANSI from stdin, but ctx uses colored inner labels.
        _ctx_outer_box "$ctx_output"
    else
        printf "%s" "$ctx_output"
    end
end
