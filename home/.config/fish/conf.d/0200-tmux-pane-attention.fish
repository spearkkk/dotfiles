if status is-interactive; and set -q TMUX; and set -q TMUX_PANE
    set -q TMUX_ATTENTION_MIN_SECONDS; or set -g TMUX_ATTENTION_MIN_SECONDS 10

    function __tmux_attention_postexec --on-event fish_postexec
        set -l minimum_duration (math "$TMUX_ATTENTION_MIN_SECONDS * 1000" 2>/dev/null); or return
        test "$CMD_DURATION" -ge "$minimum_duration" 2>/dev/null; or return
        ~/.local/libexec/tmux-pane-attention command-done "$TMUX_PANE"
    end
end
