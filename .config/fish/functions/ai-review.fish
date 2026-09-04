function __ai_review_usage
    echo "Usage:"
    echo "  ai-review [--all] [agent[:model] ...] [--worktree PATH] [--target SESSION:WINDOW] [--wait|--no-wait]"
    echo "  ai-review collect [GROUP_OR_RUN_ID]"
    echo "  ai-review list"
    echo "  ai-review kill [GROUP_ID]"
    echo
    echo "Examples:"
    echo "  ai-review --all"
    echo "  ai-review claude codex"
    echo "  ai-review codex:<model> claude:<model>"
    echo "  ai-review --all --worktree /path/to/repo"
    echo "  ai-review --all --target wk:ai --no-wait"
    echo
    echo "Default reviewers:"
    for reviewer in (__ai_review_default_reviewers)
        echo "  $reviewer"
    end
end

function __ai_review_default_reviewers
    if set -q AI_REVIEW_REVIEWERS[1]
        for value in $AI_REVIEW_REVIEWERS
            for reviewer in (string split ' ' -- $value)
                switch $reviewer
                    case '' gemini 'gemini:*'
                        continue
                    case '*'
                        printf '%s\n' $reviewer
                end
            end
        end
        return
    end

    echo codex
    echo claude
end

function __ai_review_agent_command --argument-names agent model
    switch $agent
        case codex
            test -n "$model"; and echo "codex --model "(string escape -- $model); or echo "codex"
        case claude
            test -n "$model"; and echo "claude --model "(string escape -- $model); or echo "claude"
        case '*'
            echo "unknown reviewer: $agent" >&2
            return 1
    end
end

function __ai_review_write_state --argument-names run_dir run_id group_id agent model origin_pane review_pane target worktree run_status
    begin
        printf 'set -g __ai_review_run_id %s\n' (string escape -- $run_id)
        printf 'set -g __ai_review_group_id %s\n' (string escape -- $group_id)
        printf 'set -g __ai_review_dir %s\n' (string escape -- $run_dir)
        printf 'set -g __ai_review_agent %s\n' (string escape -- $agent)
        printf 'set -g __ai_review_model %s\n' (string escape -- $model)
        printf 'set -g __ai_review_origin_pane %s\n' (string escape -- $origin_pane)
        printf 'set -g __ai_review_review_pane %s\n' (string escape -- $review_pane)
        printf 'set -g __ai_review_target %s\n' (string escape -- $target)
        printf 'set -g __ai_review_worktree %s\n' (string escape -- $worktree)
        printf 'set -g __ai_review_status %s\n' (string escape -- $run_status)
    end >$run_dir/state.fish
end

function __ai_review_build_request --argument-names request_file agent model origin_pane current_command worktree
    begin
        echo "# AI Review Request"
        echo
        echo "Review the work from another AI agent."
        echo
        echo "- Reviewer: $agent"
        test -n "$model"; and echo "- Model: $model"
        echo "- Source pane: $origin_pane"
        echo "- Source command: $current_command"
        echo "- Worktree: $worktree"
        echo
        echo "Focus on bugs, behavioral regressions, unsafe assumptions, and missing tests."
        echo "Do not edit files. Write findings first with file/line references where possible."
        echo "Return only the final review as markdown."
        echo

        if command git -C $worktree rev-parse --is-inside-work-tree >/dev/null 2>&1
            echo "## Git Status"
            echo
            echo '```text'
            command git -C $worktree status --short
            echo '```'
            echo
            echo "## Diff Stat"
            echo
            echo '```text'
            command git -C $worktree diff --stat
            command git -C $worktree diff --cached --stat
            echo '```'
            echo
            echo "## Unstaged Diff"
            echo
            echo '```diff'
            command git -C $worktree diff --no-ext-diff
            echo '```'
            echo
            echo "## Staged Diff"
            echo
            echo '```diff'
            command git -C $worktree diff --cached --no-ext-diff
            echo '```'
        else
            echo "Not a git worktree. Inspect the directory directly: $worktree"
        end
    end >$request_file
end

function __ai_review_write_runner --argument-names run_file agent model request_file result_file stdout_file stderr_file exit_file worktree
    begin
        echo "#!/usr/bin/env fish"
        printf 'cd %s\n' (string escape -- $worktree)
        echo "clear"
        echo "echo '# AI Review Request'"
        echo "echo"
        printf 'cat %s\n' (string escape -- $request_file)
        echo "echo"
        echo "echo '# Reviewer output'"
        echo "echo"

        switch $agent
            case codex
                printf 'codex exec --skip-git-repo-check'
                test -n "$model"; and printf ' --model %s' (string escape -- $model)
                printf ' --output-last-message %s - < %s > %s 2>| tee %s\n' \
                    (string escape -- $result_file) \
                    (string escape -- $request_file) \
                    (string escape -- $stdout_file) \
                    (string escape -- $stderr_file)
            case claude
                printf 'claude'
                test -n "$model"; and printf ' --model %s' (string escape -- $model)
                printf ' -p < %s 2> %s | tee %s\n' \
                    (string escape -- $request_file) \
                    (string escape -- $stderr_file) \
                    (string escape -- $result_file)
        end

        echo "set -l command_status \$pipestatus[1]"
        printf 'echo $command_status > %s\n' (string escape -- $exit_file)
        echo "if test \$command_status -ne 0"
        echo "    echo"
        echo "    echo '# Reviewer failed'"
        printf '    test -s %s; and cat %s\n' (string escape -- $stderr_file) (string escape -- $stderr_file)
        echo "end"
        echo "if test \$command_status -eq 0; and test -s "(string escape -- $result_file)"; and set -q TMUX_PANE"
        echo "    sleep 1"
        echo "    tmux kill-pane -t \$TMUX_PANE"
        echo "end"
    end >$run_file

    chmod 700 $run_file
end

function __ai_review_collect_run --argument-names run_dir
    if not test -f $run_dir/state.fish
        echo missing
        return 1
    end

    source $run_dir/state.fish

    set -l result_file $run_dir/result.md
    set -l stderr_file $run_dir/stderr.txt
    set -l exit_file $run_dir/exit-code.txt

    if test -s $result_file; and test -f $exit_file; and test (string trim <$exit_file) -eq 0
        __ai_review_write_state $__ai_review_dir $__ai_review_run_id $__ai_review_group_id $__ai_review_agent $__ai_review_model $__ai_review_origin_pane $__ai_review_review_pane $__ai_review_target $__ai_review_worktree done
        if tmux list-panes -a -F '#{pane_id}' | string match -q -- $__ai_review_review_pane
            tmux kill-pane -t $__ai_review_review_pane
        end
        echo done
    else if test -f $exit_file
        __ai_review_write_state $__ai_review_dir $__ai_review_run_id $__ai_review_group_id $__ai_review_agent $__ai_review_model $__ai_review_origin_pane $__ai_review_review_pane $__ai_review_target $__ai_review_worktree failed
        echo failed
    else if tmux list-panes -a -F '#{pane_id}' | string match -q -- $__ai_review_review_pane
        echo running
    else
        __ai_review_write_state $__ai_review_dir $__ai_review_run_id $__ai_review_group_id $__ai_review_agent $__ai_review_model $__ai_review_origin_pane $__ai_review_review_pane $__ai_review_target $__ai_review_worktree lost
        echo lost
    end
end

function __ai_review_group_file --argument-names state_root id
    if test -z "$id"; and test -f $state_root/latest
        set id (cat $state_root/latest)
    end

    if test -f $state_root/groups/$id/group.fish
        echo $state_root/groups/$id/group.fish
        return
    end

    if test -f $state_root/runs/$id/state.fish
        source $state_root/runs/$id/state.fish
        echo $state_root/groups/$__ai_review_group_id/group.fish
        return
    end

    echo "No ai-review group/run found: $id" >&2
    return 1
end

function __ai_review_build_summary --argument-names group_file paste
    source $group_file

    set -l group_dir (dirname $group_file)
    set -l result_file $group_dir/reviews.md
    set -l prompt_file $group_dir/summary-prompt.md

    begin
        echo "# AI Review Results"
        echo
        for run_id in $__ai_review_run_ids
            set -l run_dir $__ai_review_state_root/runs/$run_id
            source $run_dir/state.fish

            if test -n "$__ai_review_model"
                echo "## $__ai_review_agent $__ai_review_model"
            else
                echo "## $__ai_review_agent"
            end
            echo

            if test "$__ai_review_status" = failed
                echo "_Reviewer failed. See `$run_dir/stderr.txt` and `$run_dir/stdout.txt`._"
            else if test -s $run_dir/result.md
                cat $run_dir/result.md
            else
                echo "_No completed result._"
            end
            echo
        end
    end >$result_file

    begin
        echo "다음은 여러 AI reviewer가 같은 worktree diff를 리뷰한 결과입니다."
        echo
        echo "공통으로 지적된 문제, reviewer 간 의견 충돌, 실제로 반영해야 할 수정사항, 무시해도 되는 피드백을 구분해서 종합해줘."
        echo "필요하면 우선순위를 나누고, 파일/라인 근거가 있는 항목을 먼저 다뤄줘."
        echo
        cat $result_file
    end >$prompt_file

    if test "$paste" = paste; and tmux list-panes -a -F '#{pane_id}' | string match -q -- $__ai_review_origin_pane
        tmux load-buffer -b ai-review-summary-$__ai_review_group_id $prompt_file
        tmux paste-buffer -b ai-review-summary-$__ai_review_group_id -t $__ai_review_origin_pane
        tmux send-keys -t $__ai_review_origin_pane C-m
        echo "Pasted aggregate review prompt into $__ai_review_origin_pane."
    else
        echo "Review summary prompt: $prompt_file"
    end
end

function ai-review --description 'Orchestrate AI CLI reviewers in tmux panes'
    set -l state_root /tmp/ai-review
    set -l action run
    set -l reviewers
    set -l target
    set -l worktree
    set -l wait 1
    set -l paste paste
    set -l timeout 1800
    set -l id
    set -l expect

    for arg in $argv
        if test -n "$expect"
            switch $expect
                case target
                    set target $arg
                case worktree
                    set worktree $arg
                case timeout
                    set timeout $arg
            end
            set expect
            continue
        end

        switch $arg
            case -h --help
                __ai_review_usage
                return
            case start run request
                set action run
            case collect return done summarize
                set action collect
            case list ls
                set action list
            case kill --kill
                set action kill
            case --all
                set reviewers (__ai_review_default_reviewers)
            case --target -t
                set expect target
            case --worktree -C
                set expect worktree
            case --wait
                set wait 1
            case --no-wait
                set wait 0
            case --no-paste
                set paste no-paste
            case --timeout
                set expect timeout
            case codex claude 'codex:*' 'claude:*'
                set -a reviewers $arg
            case '*'
                if test "$action" = collect; or test "$action" = kill
                    set id $arg
                else
                    set -a reviewers $arg
                end
        end
    end

    mkdir -p $state_root/runs $state_root/groups

    if test "$action" = list
        for state in $state_root/runs/*/state.fish
            test -f $state; or continue
            source $state
            set -l reviewer $__ai_review_agent
            test -n "$__ai_review_model"; and set reviewer "$reviewer:$__ai_review_model"
            printf '%s  %-28s  %-7s  %-6s  %s\n' $__ai_review_run_id $reviewer $__ai_review_status $__ai_review_review_pane $__ai_review_worktree
        end
        return
    end

    if test "$action" = collect
        set -l group_file (__ai_review_group_file $state_root $id)
        or return 1
        source $group_file

        set -l all_done 1
        for run_id in $__ai_review_run_ids
            set -l run_status (__ai_review_collect_run $__ai_review_state_root/runs/$run_id)
            if test "$run_status" != done
                set all_done 0
            end
        end

        if test $all_done -eq 1
            __ai_review_build_summary $group_file $paste
        else
            echo "Some reviewers are still running. Run ai-review collect $__ai_review_group_id later."
        end
        return
    end

    if test "$action" = kill
        set -l group_file (__ai_review_group_file $state_root $id)
        or return 1
        source $group_file

        for run_id in $__ai_review_run_ids
            set -l run_dir $__ai_review_state_root/runs/$run_id
            source $run_dir/state.fish
            if tmux list-panes -a -F '#{pane_id}' | string match -q -- $__ai_review_review_pane
                tmux kill-pane -t $__ai_review_review_pane
            end
        end
        return
    end

    if not set -q TMUX_PANE
        echo "ai-review must be started from inside tmux."
        return 1
    end

    set -l origin_pane $TMUX_PANE
    if test -z "$worktree"
        set worktree (tmux display-message -p -t $origin_pane '#{pane_current_path}')
    end
    if not test -d "$worktree"
        echo "worktree not found: $worktree"
        return 1
    end
    set worktree (cd $worktree; and pwd -P)
    set -l current_command (tmux display-message -p -t $origin_pane '#{pane_current_command}')

    if test -z "$target"
        set target (tmux display-message -p -t $origin_pane '#S:#W')
    end

    if not tmux list-windows -a -F '#S:#W' | string match -q -- $target
        echo "tmux target not found: $target"
        return 1
    end

    if test (count $reviewers) -eq 0
        switch $current_command
            case 'codex*'
                set reviewers claude
            case 'claude*'
                set reviewers codex
            case '*'
                set reviewers claude
        end
    end

    for reviewer in $reviewers
        set -l parts (string split -m1 ':' -- $reviewer)
        set -l agent $parts[1]
        if not contains -- $agent codex claude
            echo "unknown reviewer: $reviewer"
            return 2
        end
        if not command -q $agent
            echo "reviewer CLI not found: $agent"
            return 1
        end
    end

    set -l state_key (string replace -a '%' '' -- "$origin_pane")
    set -l group_id (date +%Y%m%d-%H%M%S)-$state_key
    set -l group_dir $state_root/groups/$group_id
    mkdir -p $group_dir

    set -l run_ids
    for reviewer in $reviewers
        set -l parts (string split -m1 ':' -- $reviewer)
        set -l agent $parts[1]
        set -l model ''
        test (count $parts) -gt 1; and set model $parts[2]

        set -l run_id $group_id-$agent-(random)
        set -l run_dir $state_root/runs/$run_id
        mkdir -p $run_dir

        set -l request_file $run_dir/request.md
        set -l result_file $run_dir/result.md
        set -l stdout_file $run_dir/stdout.txt
        set -l stderr_file $run_dir/stderr.txt
        set -l exit_file $run_dir/exit-code.txt
        set -l run_file $run_dir/run.fish
        __ai_review_build_request $request_file $agent $model $origin_pane $current_command $worktree

        set -l review_pane (tmux split-window -P -F '#{pane_id}' -t $target -h -c $worktree)
        if test -n "$model"
            tmux send-keys -t $review_pane "function fish_title; echo review-$agent-$model; end" C-m
        else
            tmux send-keys -t $review_pane "function fish_title; echo review-$agent; end" C-m
        end

        __ai_review_write_runner $run_file $agent $model $request_file $result_file $stdout_file $stderr_file $exit_file $worktree
        __ai_review_write_state $run_dir $run_id $group_id $agent $model $origin_pane $review_pane $target $worktree running
        tmux send-keys -t $review_pane "fish "(string escape -- $run_file) C-m
        set -a run_ids $run_id
    end

    tmux select-layout -t $target even-horizontal >/dev/null 2>&1

    begin
        printf 'set -g __ai_review_group_id %s\n' (string escape -- $group_id)
        printf 'set -g __ai_review_state_root %s\n' (string escape -- $state_root)
        printf 'set -g __ai_review_origin_pane %s\n' (string escape -- $origin_pane)
        printf 'set -g __ai_review_target %s\n' (string escape -- $target)
        printf 'set -g __ai_review_run_ids'
        for run_id in $run_ids
            printf ' %s' (string escape -- $run_id)
        end
        printf '\n'
    end >$group_dir/group.fish

    echo $group_id >$state_root/latest

    echo "AI review group: $group_id"
    for run_id in $run_ids
        source $state_root/runs/$run_id/state.fish
        set -l label $__ai_review_agent
        test -n "$__ai_review_model"; and set label "$label:$__ai_review_model"
        echo "  $label -> $__ai_review_review_pane"
    end

    if test $wait -eq 0
        echo "Run ai-review collect $group_id after reviewer result files are written."
        return
    end

    set -l started (date +%s)
    while true
        set -l done_count 0
        set -l total_count (count $run_ids)

        for run_id in $run_ids
            set -l run_status (__ai_review_collect_run $state_root/runs/$run_id)
            if test "$run_status" = done
                set done_count (math $done_count + 1)
            end
        end

        if test $done_count -eq $total_count
            __ai_review_build_summary $group_dir/group.fish $paste
            return
        end

        set -l now (date +%s)
        if test (math $now - $started) -ge $timeout
            for run_id in $run_ids
                set -l run_dir $state_root/runs/$run_id
                set -l run_status (__ai_review_collect_run $run_dir)
                if test "$run_status" != done; and test "$run_status" != failed
                    source $run_dir/state.fish
                    __ai_review_write_state $__ai_review_dir $__ai_review_run_id $__ai_review_group_id $__ai_review_agent $__ai_review_model $__ai_review_origin_pane $__ai_review_review_pane $__ai_review_target $__ai_review_worktree timed_out
                end
            end
            echo "Timed out waiting for reviewers. Completed $done_count/$total_count."
            echo "Run ai-review collect $group_id later."
            return 124
        end

        sleep 5
    end
end
