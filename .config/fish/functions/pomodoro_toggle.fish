function pomodoro_toggle
    set -lx CONFIG_DIR ~/.config/sketchybar
    ~/.config/sketchybar/plugins/pomodoro.sh $argv > /dev/null 2>&1 &
end