function ctx --description 'Compact, styled context line using __dot_style'

    function _tag --argument-names label
        echo (__dot_style --color black --background green --styles=bold " $label ")
    end

    function _kv --argument-names key val
        printf "%s%s\n" \
            (__dot_style --color green --styles=bold (string pad -w 8 -- "$key:")) \
            (__dot_style --color white --styles=italic "$val")
    end

    function _ctx_line --argument-names label key val
        printf "%s  %s %s\n" \
            (_tag $label) \
            (__dot_style --color green --styles=bold (string pad -w 6 -- "$key:")) \
            (__dot_style --color white --styles=italic "$val")
    end

    function _ctx_capture --argument-names timeout_ms
        set -l tmp (mktemp)

        $argv[2..-1] >$tmp 2>/dev/null &
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

    ### Git ###
    if test -d .git; or command git rev-parse --is-inside-work-tree > /dev/null 2>&1
        set branch (command git symbolic-ref --short HEAD 2>/dev/null)
        test -z "$branch"; and set branch (command git rev-parse --short HEAD 2>/dev/null)
        _ctx_line " git" "branch" $branch
    end

    ### Docker ###
    if type -q docker
        docker version > /dev/null 2>&1
        if test $status -eq 0
            set -l docker_ctx (docker context show 2>/dev/null)
            if test -n "$docker_ctx"
                _ctx_line "dckr" "   ctx" $docker_ctx
            end
        end
    end

    ### Kubernetes ###
    if type -q kubectl
        set -l kube_ctx (_ctx_capture 500 kubectl config current-context)
        if test -n "$kube_ctx"
            _ctx_line " k8s" "   ctx" $kube_ctx
        end
    end

    ### Mise ###
    if type -q mise
        set -l mise_output (mise current 2>/dev/null | string join ', ')
        if test -n "$mise_output"
            _ctx_line "mise" "   ver" $mise_output
        end
    end

    ### AWS ###
    if type -q aws
        set -l profile (string replace -r 'profile ' '' (aws configure get profile 2>/dev/null || echo $AWS_PROFILE))
        set -l region (aws configure get region 2>/dev/null)
        test -z "$profile"; and set profile default
        test -z "$region"; and set region (string trim (grep region ~/.aws/config | head -n1 | string replace -r 'region\s*=\s*' ''))
        if test -n "$profile" -o -n "$region"
            _ctx_line " aws" $profile $region
        end
    end
end
