function ctx --description 'Compact, styled context line'

    function _color_block --argument-names fg bg text
        set_color --background $bg $fg
        echo -n " $text "
        set_color normal
    end

    function _kv --argument-names key val
        set_color $COLOR_LINK
        echo -n "$key:"
        set_color $COLOR_FG
        echo -n "$val"
        set_color normal
    end

    set -l output ""

    ### Git ###
    if test -d .git; or command git rev-parse --is-inside-work-tree > /dev/null 2>&1
        set branch (command git symbolic-ref --short HEAD 2>/dev/null)
        test -z "$branch"; and set branch (command git rev-parse --short HEAD 2>/dev/null)
        set output "$output"(string trim --right " ")" "(_color_block $COLOR_HIGHLIGHT $COLOR_BG_ALT "git")" "(_kv branch $branch)
    end

    ### Docker ###
    if type -q docker
        docker version > /dev/null 2>&1
        if test $status -eq 0
            set -l docker_ctx (docker context show 2>/dev/null)
            if test -n "$docker_ctx"
                set output "$output"(string trim --right " ")" "(_color_block $COLOR_HIGHLIGHT $COLOR_BG_ALT "dckr")" "(_kv ctx $docker_ctx)
            end
        end
    end

    ### Kubernetes ###
    if type -q kubectl
        set -l kube_ctx (kubectl config current-context 2>/dev/null)
        if test -n "$kube_ctx"
            set output "$output"(string trim --right " ")" "(_color_block $COLOR_HIGHLIGHT $COLOR_BG_ALT "k8s")" "(_kv ctx $kube_ctx)
        end
    end

    ### Mise ###
    if type -q mise
        set -l mise_output (mise current --short 2>/dev/null | string join ', ')
        if test -n "$mise_output"
            set output "$output"(string trim --right " ")" "(_color_block $COLOR_HIGHLIGHT $COLOR_BG_ALT "mise")" "(_kv ver $mise_output)
        end
    end

    ### AWS ###
    if type -q aws
        set -l profile (string replace -r 'profile ' '' (aws configure get profile 2>/dev/null || echo $AWS_PROFILE))
        set -l region (aws configure get region 2>/dev/null)
        test -z "$profile"; and set profile default
        test -z "$region"; and set region (string trim (grep region ~/.aws/config | head -n1 | string replace -r 'region\s*=\s*' ''))
        if test -n "$profile" -o -n "$region"
            set output "$output"(string trim --right " ")" "(_color_block $COLOR_HIGHLIGHT $COLOR_BG_ALT "aws")" "(_kv $profile $region)
        end
    end

    echo (string trim "$output")
end