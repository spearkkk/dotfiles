function pomo
  set work_time 25
  set break_time 5

  if count $argv >/dev/null
    set work_time $argv[1]
    set break_time $argv[2]
  end

  _pomodoro_toggle _pomodoro_break _pomodoro_work _pomodoro_work $work_time $break_time
end