# Record the last finished command (and how long it took, via fish's builtin
# $CMD_DURATION in ms) as tmux pane-scoped user options, so the tmux status
# line can show "what I was just doing" when the pane is idle at a shell
# prompt (pane_current_command is just "fish" and useless on its own).
function __tmux_record_last_cmd --on-event fish_postexec
    if set -q TMUX
        # -t $TMUX_PANE is mandatory here: "set-option -p" without -t targets
        # whatever pane the CLIENT currently has focused, not necessarily the
        # pane this shell/hook is actually running in -- without it, a
        # background window's finished command gets recorded onto whatever
        # window you happen to be looking at when it completes.
        tmux set-option -p -t "$TMUX_PANE" @last_cmd "$argv"
        tmux set-option -p -t "$TMUX_PANE" @last_cmd_duration_ms $CMD_DURATION

        # Ring the terminal bell for commands that took a while, so tmux's
        # monitor-bell flags this window (styled via window-status-bell-style)
        # as "finished" if I'm not currently looking at it. Skipped for quick
        # commands so it doesn't fire on every `ls`.
        if test $CMD_DURATION -gt 3000
            printf '\a'
        end
    end
end
