function ctx --description 'Compact, styled context line using __dot_style'

    function _tag --argument-names label
        set -l text (printf ' %-4s ' (string sub -l 4 -- "$label"))
        echo (__dot_style --color black --background green --styles=bold "$text")
    end

    function _ctx_line --argument-names label val branch
        set -l prefix ''

        if test "$branch" = last
            set prefix (__dot_style --color black --background green --styles=bold '  └──')
        end

        printf "%s%s  %s\n" \
            "$prefix" \
            (_tag $label) \
            (__dot_style --color white --styles=italic "$val")
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

    ### Tmux ###
    if set -q TMUX_PANE
        set -l tmux_session (tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null)
        set -l tmux_window (tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null)
        set -l tmux_pane (tmux display-message -p -t "$TMUX_PANE" '#P' 2>/dev/null)

        if test -n "$tmux_session" -o -n "$tmux_window"
            _ctx_line tmux "$tmux_session:$tmux_window.$tmux_pane"
        end

        set -l tmux_kube_ctx (_ctx_tmux_option @kube_context)

        if test -n "$tmux_kube_ctx"
            _ctx_line k8s $tmux_kube_ctx last
        end
    end

    ### Git ###
    if test -d .git; or command git rev-parse --is-inside-work-tree > /dev/null 2>&1
        set branch (command git symbolic-ref --short HEAD 2>/dev/null)
        test -z "$branch"; and set branch (command git rev-parse --short HEAD 2>/dev/null)
        _ctx_line git $branch
    end

    ### Docker ###
    if type -q docker
        docker version > /dev/null 2>&1
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
        test -z "$profile"; and set profile default
        test -z "$region"; and set region (string trim (grep region ~/.aws/config | head -n1 | string replace -r 'region\s*=\s*' ''))
        if test -n "$profile" -o -n "$region"
            _ctx_line aws "$profile $region"
        end
    end
end
