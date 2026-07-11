function pomo --description "Control the SketchyBar Pomodoro timer"
    set -l action toggle
    if test (count $argv) -gt 0
        set action $argv[1]
    end

    switch $action
        case start work break stop toggle
            if not type -q sketchybar
                echo "pomo: sketchybar is not installed or not on PATH" >&2
                return 1
            end
            sketchybar --trigger pomodoro_change ACTION=$action
        case -h --help help
            echo "Usage: pomo [start|work|break|stop|toggle]"
        case '*'
            echo "pomo: unknown action '$action'" >&2
            echo "Usage: pomo [start|work|break|stop|toggle]" >&2
            return 2
    end
end
