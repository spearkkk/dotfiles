function __ai_review_usage
    echo "Usage:"
    echo "  ai-review [--all|--deep] [agent[:model] ...] [--worktree PATH] [--staged-only] [--path PATH ...] [--kind KIND] [--focus TEXT] [--target SESSION:WINDOW] [--headless] [--wait|--no-wait] [--paste]"
    echo "  ai-review collect [GROUP_OR_RUN_ID]"
    echo "  ai-review list [--worktree PATH]"
    echo "  ai-review clean"
    echo "  ai-review kill [GROUP_ID]"
    echo
    echo "Examples:"
    echo "  ai-review --all"
    echo "  ai-review claude codex"
    echo "  ai-review codex:<model> claude:<model>"
    echo "  ai-review --deep --staged-only"
    echo "  ai-review --all --worktree /path/to/repo"
    echo "  ai-review --all --headless --worktree /path/to/repo --no-wait"
    echo "  ai-review --all --staged-only"
    echo "  ai-review --all --path .config/fish/functions/ai-review.fish --path .codex/skills/reviewers/SKILL.md"
    echo "  ai-review --all --worktree /path/to/repo --kind spec"
    echo "  ai-review --all --worktree /path/to/repo --kind architecture --focus 'dependency direction and failure modes'"
    echo "  ai-review --all --target wk:ai --no-wait"
    echo
    echo "Default reviewers:"
    for reviewer in (__ai_review_default_reviewers)
        echo "  $reviewer"
    end
end

function __ai_review_default_reviewers
    set -l selected

    if set -q AI_REVIEW_REVIEWERS[1]
        for value in $AI_REVIEW_REVIEWERS
            for reviewer in (string split ' ' -- $value)
                test -n "$reviewer"; or continue

                set -l parts (string split -m1 ':' -- $reviewer)
                set -l agent $parts[1]
                contains -- $agent codex claude; or continue

                set -a selected $reviewer
            end
        end
    end

    if test (count $selected) -gt 0
        printf '%s\n' $selected
        return
    end

    echo codex
    echo claude
end


function __ai_review_deep_reviewers
    set -l selected

    if set -q AI_REVIEW_DEEP_REVIEWERS[1]
        for value in $AI_REVIEW_DEEP_REVIEWERS
            for reviewer in (string split ' ' -- $value)
                test -n "$reviewer"; or continue

                set -l parts (string split -m1 ':' -- $reviewer)
                set -l agent $parts[1]
                contains -- $agent codex claude; or continue

                set -a selected $reviewer
            end
        end
    end

    if test (count $selected) -gt 0
        printf '%s\n' $selected
        return
    end

    __ai_review_default_reviewers
end

function __ai_review_valid_kind --argument-names kind
    contains -- $kind auto code spec architecture plan docs synthesis mixed
end

function __ai_review_classify_path --argument-names path
    set -l lower (string lower -- $path)

    switch $lower
        case '*architecture*' '*design*' '*adr*'
            echo architecture
        case '*spec.md' '*/spec.md' '*specs/*' '*requirements*' '*acceptance*'
            echo spec
        case '*plan*' '*migration*'
            echo plan
        case 'readme.md' '*/readme.md' '*runbook*' '*docs/*' '*.md'
            echo docs
        case '*.fish' '*.sh' '*.py' '*.js' '*.ts' '*.tsx' '*.jsx' '*.java' '*.kt' '*.go' '*.rs' '*.rb' '*.lua' '*.vim'
            echo code
        case '*'
            echo docs
    end
end

function __ai_review_detect_kind_from_paths
    if test (count $argv) -eq 0
        echo mixed
        return
    end

    set -l kinds
    for path in $argv
        set -a kinds (__ai_review_classify_path $path)
    end

    set -l unique
    for kind in $kinds
        contains -- $kind $unique; or set -a unique $kind
    end

    if test (count $unique) -eq 1
        echo $unique[1]
    else
        echo mixed
    end
end

function __ai_review_render_output_contract
    echo "## Output Contract"
    echo
    echo "Return only the final review as markdown using this shape:"
    echo
    echo "## Review Target"
    echo "[Code / Spec / Architecture / Plan / Docs / Review Synthesis / Mixed]"
    echo
    echo "## Verdict"
    echo "[Accept / Request changes / Block / Insufficient evidence]"
    echo
    echo "## Main Risks"
    echo "- ..."
    echo
    echo "## Findings"
    echo "- [severity] [anchor] Finding, evidence, impact"
    echo
    echo "## Evidence Gaps"
    echo "- ..."
    echo
    echo "## Recommended Next Actions"
    echo "- ..."
    echo
    echo "Anchors are file:line for code; section, requirement, heading, or quoted claim for specs/docs; decision, boundary, dependency, data flow, or failure mode for architecture; step number for plans; reviewer name plus claim for synthesis."
end

function __ai_review_render_kind_guidance --argument-names kind
    echo "## Review Focus"
    echo

    switch $kind
        case code
            echo "- Requirements fit"
            echo "- Behavior changes and regressions"
            echo "- Error handling, security, and compatibility"
            echo "- Missing or weak tests"
        case spec
            echo "- Problem clarity, scope, and acceptance criteria"
            echo "- Ambiguity, edge cases, and contradictions"
            echo "- whether the doc is understandable without opening tickets"
        case architecture
            echo "- Boundaries and dependency direction"
            echo "- Data flow and coupling"
            echo "- Failure modes, operability, and migration path"
        case plan
            echo "- Sequence and hidden dependencies"
            echo "- Testability and rollback"
            echo "- Risk and whether steps prove completion"
        case docs
            echo "- Reader context and durable explanation"
            echo "- Stale ticket dependency"
            echo "- Missing assumptions and unsafe or ambiguous guidance"
            echo "- Consistency with repository behavior"
        case synthesis
            echo "- Evidence quality"
            echo "- Conflicting claims and duplicate findings"
            echo "- Hallucinated files or lines"
            echo "- Actionable next steps"
        case mixed '*'
            echo "- Review the highest-risk layer first"
            echo "- Architecture/spec before plan"
            echo "- Plan before code details"
            echo "- Blocking correctness before style"
    end
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

function __ai_review_build_request --argument-names request_file agent model origin_pane current_command worktree review_kind focus branch head_sha generated_at staged_only scope_file
    begin
        echo "# AI Review Request"
        echo
        echo "Review the work from another AI agent. This request is self-contained; do not assume you have loaded the reviewers skill."
        echo
        echo "## Metadata"
        echo
        echo "- Reviewer: $agent"
        test -n "$model"; and echo "- Model: $model"
        echo "- Source pane: $origin_pane"
        echo "- Source command: $current_command"
        echo "- Worktree: $worktree"
        echo "- Branch: $branch"
        echo "- HEAD: $head_sha"
        echo "- Review Kind: $review_kind"
        if test "$staged_only" -eq 1
            echo "- Diff Scope: staged only"
        else
            echo "- Diff Scope: unstaged and staged"
        end
        if test -s "$scope_file"
            echo "- Path Scope:"
            for path in (cat $scope_file)
                echo "  - $path"
            end
        else
            echo "- Path Scope: all changed paths"
        end
        if test -n "$focus"
            echo "- Focus: $focus"
        else
            echo "- Focus: -"
        end
        echo "- Generated At: $generated_at"
        echo
        echo "## Reviewer Role"
        echo
        echo "Review only. Do not edit files."
        echo "Do not run expensive, credential-heavy, deployment, staging, production, or state-changing commands."
        echo "Treat claimed tests, reviewer agreement, and AI confidence as claims, not evidence."
        echo "Prefer Insufficient evidence over forced approval when source material or proof is missing."
        echo "Report blocking correctness issues before style or preference."
        echo
        __ai_review_render_kind_guidance $review_kind
        echo
        __ai_review_render_output_contract
        echo

        if command git -C $worktree rev-parse --is-inside-work-tree >/dev/null 2>&1
            set -l scoped_paths
            if test -s "$scope_file"
                set scoped_paths (cat $scope_file)
            end

            echo "## Git Status"
            echo
            echo '```text'
            command git -C $worktree status --short
            echo '```'
            echo
            echo "## Diff Stat"
            echo
            echo '```text'
            if test "$staged_only" -eq 1
                command git -C $worktree diff --cached --stat -- $scoped_paths
            else
                command git -C $worktree diff --stat -- $scoped_paths
                command git -C $worktree diff --cached --stat -- $scoped_paths
            end
            echo '```'
            if test "$staged_only" -ne 1
                echo
                echo "## Unstaged Diff"
                echo
                echo '```diff'
                command git -C $worktree diff --no-ext-diff -- $scoped_paths
                echo '```'
            end
            echo
            echo "## Staged Diff"
            echo
            echo '```diff'
            command git -C $worktree diff --cached --no-ext-diff -- $scoped_paths
            echo '```'
        else
            echo "Not a git worktree. Inspect the directory directly: $worktree"
        end
    end >$request_file
end

function __ai_review_write_runner --argument-names run_file agent model request_file result_file stdout_file stderr_file exit_file worktree
    set -l agent_bin (command -s $agent)
    test -n "$agent_bin"; or set agent_bin $agent

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
                printf '%s exec --skip-git-repo-check --sandbox read-only' (string escape -- $agent_bin)
                test -n "$model"; and printf ' --model %s' (string escape -- $model)
                printf ' --output-last-message %s - < %s > %s 2>| tee %s\n' \
                    (string escape -- $result_file) \
                    (string escape -- $request_file) \
                    (string escape -- $stdout_file) \
                    (string escape -- $stderr_file)
            case claude
                printf '%s' (string escape -- $agent_bin)
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

function __ai_review_pane_exists --argument-names pane
    test -n "$pane"; and test "$pane" != -; or return 1
    command -q tmux; or return 1
    tmux list-panes -a -F '#{pane_id}' 2>/dev/null | string match -q -- $pane
end

function __ai_review_pid_running --argument-names pid_file
    test -f "$pid_file"; or return 1
    set -l pid (string trim < $pid_file)
    test -n "$pid"; or return 1
    command kill -0 $pid >/dev/null 2>&1
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
    set -l pid_file $run_dir/pid.txt

    if test -s $result_file; and test -f $exit_file; and test (string trim <$exit_file) -eq 0
        __ai_review_write_state $__ai_review_dir $__ai_review_run_id $__ai_review_group_id $__ai_review_agent $__ai_review_model $__ai_review_origin_pane $__ai_review_review_pane $__ai_review_target $__ai_review_worktree done
        if __ai_review_pane_exists $__ai_review_review_pane
            tmux kill-pane -t $__ai_review_review_pane
        end
        echo done
    else if test -f $exit_file
        __ai_review_write_state $__ai_review_dir $__ai_review_run_id $__ai_review_group_id $__ai_review_agent $__ai_review_model $__ai_review_origin_pane $__ai_review_review_pane $__ai_review_target $__ai_review_worktree failed
        echo failed
    else if __ai_review_pid_running $pid_file
        echo running
    else if __ai_review_pane_exists $__ai_review_review_pane
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


function __ai_review_write_manifest --argument-names manifest_file group_id state_root origin_pane target worktree branch head_sha review_kind focus generated_at
    begin
        echo "# AI Review Harness Manifest"
        echo
        echo "- Group ID: $group_id"
        echo "- Generated At: $generated_at"
        echo "- State Root: $state_root"
        echo "- Origin Pane: $origin_pane"
        echo "- Target: $target"
        echo "- Worktree: $worktree"
        echo "- Branch: $branch"
        echo "- HEAD: $head_sha"
        echo "- Review Kind: $review_kind"
        if test -n "$focus"
            echo "- Focus: $focus"
        else
            echo "- Focus: -"
        end
        echo
        echo "## Runs"
    end >$manifest_file
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
        if set -q __ai_review_manifest_file
            echo "- Manifest: $__ai_review_manifest_file"
        end
        if set -q __ai_review_worktree
            echo "- Worktree: $__ai_review_worktree"
        end
        if set -q __ai_review_branch
            echo "- Branch: $__ai_review_branch"
        end
        if set -q __ai_review_head_sha
            echo "- HEAD: $__ai_review_head_sha"
        end
        if set -q __ai_review_review_kind
            echo "- Review Kind: $__ai_review_review_kind"
        end
        if set -q __ai_review_focus; and test -n "$__ai_review_focus"
            echo "- Focus: $__ai_review_focus"
        else
            echo "- Focus: -"
        end
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
    set -l paste no-paste
    set -l timeout 1800
    set -l id
    set -l expect
    set -l review_kind auto
    set -l focus ''
    set -l staged_only 0
    set -l review_paths
    set -l ui_mode tmux
    set -l use_all 0
    set -l deep_review 0

    for arg in $argv
        if test -n "$expect"
            switch $expect
                case target
                    set target $arg
                case worktree
                    set worktree $arg
                case timeout
                    set timeout $arg
                case kind
                    set review_kind $arg
                case focus
                    set focus $arg
                case path
                    set -a review_paths $arg
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
            case clean gc
                set action clean
            case kill --kill
                set action kill
            case --all
                set use_all 1
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
            case --paste
                set paste paste
            case --timeout
                set expect timeout
            case --kind
                set expect kind
            case --focus
                set expect focus
            case --staged-only
                set staged_only 1
            case --headless
                set ui_mode headless
                set paste no-paste
            case --deep
                set deep_review 1
                set use_all 1
            case --path -p
                set expect path
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

    if test -n "$expect"
        echo "missing value for --$expect" >&2
        return 2
    end

    if not __ai_review_valid_kind $review_kind
        echo "unknown review kind: $review_kind" >&2
        return 2
    end

    mkdir -p $state_root/runs $state_root/groups

    if test "$action" = list
        if test -n "$worktree"
            if not test -d "$worktree"
                echo "worktree not found: $worktree" >&2
                return 1
            end
            set worktree (cd $worktree; and pwd -P)
        end

        for state in $state_root/runs/*/state.fish
            test -f $state; or continue
            source $state
            if test -n "$worktree"; and test "$__ai_review_worktree" != "$worktree"
                continue
            end
            set -l reviewer $__ai_review_agent
            test -n "$__ai_review_model"; and set reviewer "$reviewer:$__ai_review_model"
            printf '%s  %-28s  %-9s  %-6s  %s\n' $__ai_review_run_id $reviewer $__ai_review_status $__ai_review_review_pane $__ai_review_worktree
        end
        return
    end

    if test "$action" = clean
        set -l removed 0
        for state in $state_root/runs/*/state.fish
            test -f $state; or continue
            set -l run_dir (dirname $state)
            source $state
            set -l run_status (__ai_review_collect_run $run_dir)
            switch $run_status
                case done failed lost killed timed_out missing
                    command rm -rf $run_dir
                    set removed (math $removed + 1)
            end
        end
        echo "Removed $removed terminal ai-review run(s)."
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
            if __ai_review_pane_exists $__ai_review_review_pane
                tmux kill-pane -t $__ai_review_review_pane
            end
            if test -f $run_dir/pid.txt
                set -l pid (string trim < $run_dir/pid.txt)
                if test -n "$pid"
                    command kill -TERM -$pid >/dev/null 2>&1; or command kill $pid >/dev/null 2>&1
                end
            end
            __ai_review_write_state $__ai_review_dir $__ai_review_run_id $__ai_review_group_id $__ai_review_agent $__ai_review_model $__ai_review_origin_pane $__ai_review_review_pane $__ai_review_target $__ai_review_worktree killed
        end
        return
    end

    set -l origin_pane -
    if test "$ui_mode" = tmux
        if not set -q TMUX_PANE
            echo "ai-review must be started from inside tmux. Use --headless for non-tmux runs."
            return 1
        end

        set origin_pane $TMUX_PANE
        if test -z "$worktree"
            set worktree (tmux display-message -p -t $origin_pane '#{pane_current_path}')
        end
    else
        set origin_pane headless
        if test -z "$worktree"
            set worktree (pwd -P)
        end
    end
    if not test -d "$worktree"
        echo "worktree not found: $worktree"
        return 1
    end
    set worktree (cd $worktree; and pwd -P)

    set -l changed_paths
    set -l branch '-'
    set -l head_sha '-'
    if command git -C $worktree rev-parse --is-inside-work-tree >/dev/null 2>&1
        if test $staged_only -eq 1
            set changed_paths (command git -C $worktree diff --cached --name-only -- $review_paths)
        else
            set changed_paths (command git -C $worktree diff --name-only -- $review_paths)
            set -a changed_paths (command git -C $worktree diff --cached --name-only -- $review_paths)
        end
        set branch (command git -C $worktree branch --show-current)
        test -n "$branch"; or set branch detached
        set head_sha (command git -C $worktree rev-parse --short HEAD)
    end

    if test "$review_kind" = auto
        set review_kind (__ai_review_detect_kind_from_paths $changed_paths)
    end

    set -l generated_at (date '+%Y-%m-%dT%H:%M:%S%z')
    set -l current_command ai-review

    if test "$ui_mode" = tmux
        set current_command (tmux display-message -p -t $origin_pane '#{pane_current_command}')

        if test -z "$target"
            set target (tmux display-message -p -t $origin_pane '#S:#W')
        end

        if not tmux list-windows -a -F '#S:#W' | string match -q -- $target
            echo "tmux target not found: $target"
            return 1
        end
    else
        set target headless
    end

    if test (count $reviewers) -eq 0
        if test $use_all -eq 1
            if test $deep_review -eq 1
                set reviewers (__ai_review_deep_reviewers)
            else
                set reviewers (__ai_review_default_reviewers)
            end
        else
            switch $current_command
                case 'codex*'
                    set reviewers claude
                case 'claude*'
                    set reviewers codex
                case '*'
                    set reviewers claude
            end
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
    set -l manifest_file $group_dir/manifest.md
    set -l scope_file $group_dir/paths.txt
    if test (count $review_paths) -gt 0
        printf '%s\n' $review_paths >$scope_file
    else
        printf '' >$scope_file
    end
    __ai_review_write_manifest $manifest_file $group_id $state_root $origin_pane $target $worktree $branch $head_sha $review_kind $focus $generated_at

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
        __ai_review_build_request $request_file $agent $model $origin_pane $current_command $worktree $review_kind $focus $branch $head_sha $generated_at $staged_only $scope_file

        set -l review_pane -

        __ai_review_write_runner $run_file $agent $model $request_file $result_file $stdout_file $stderr_file $exit_file $worktree

        if test "$ui_mode" = tmux
            set review_pane (tmux split-window -P -F '#{pane_id}' -t $target -h -c $worktree)
            if test -n "$model"
                tmux send-keys -t $review_pane "function fish_title; echo review-$agent-$model; end" C-m
            else
                tmux send-keys -t $review_pane "function fish_title; echo review-$agent; end" C-m
            end
        end

        __ai_review_write_state $run_dir $run_id $group_id $agent $model $origin_pane $review_pane $target $worktree running
        begin
            echo
            if test -n "$model"
                echo "### $agent:$model"
            else
                echo "### $agent"
            end
            echo
            echo "- Run ID: $run_id"
            echo "- Request: $request_file"
            echo "- Result: $result_file"
            echo "- Stdout: $stdout_file"
            echo "- Stderr: $stderr_file"
            echo "- Exit Code: $exit_file"
            echo "- Pane: $review_pane"
        end >>$manifest_file
        if test "$ui_mode" = tmux
            tmux send-keys -t $review_pane "fish "(string escape -- $run_file) C-m
        else
            fish $run_file >$run_dir/session.txt 2>&1 &
            echo $last_pid >$run_dir/pid.txt
            echo "- PID: $last_pid" >>$manifest_file
        end
        set -a run_ids $run_id
    end

    if test "$ui_mode" = tmux
        tmux select-layout -t $target even-horizontal >/dev/null 2>&1
    end

    begin
        printf 'set -g __ai_review_group_id %s\n' (string escape -- $group_id)
        printf 'set -g __ai_review_state_root %s\n' (string escape -- $state_root)
        printf 'set -g __ai_review_origin_pane %s\n' (string escape -- $origin_pane)
        printf 'set -g __ai_review_target %s\n' (string escape -- $target)
        printf 'set -g __ai_review_worktree %s\n' (string escape -- $worktree)
        printf 'set -g __ai_review_manifest_file %s\n' (string escape -- $manifest_file)
        printf 'set -g __ai_review_review_kind %s\n' (string escape -- $review_kind)
        printf 'set -g __ai_review_focus %s\n' (string escape -- $focus)
        printf 'set -g __ai_review_branch %s\n' (string escape -- $branch)
        printf 'set -g __ai_review_head_sha %s\n' (string escape -- $head_sha)
        printf 'set -g __ai_review_generated_at %s\n' (string escape -- $generated_at)
        printf 'set -g __ai_review_ui_mode %s\n' (string escape -- $ui_mode)
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
