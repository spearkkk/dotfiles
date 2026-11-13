# Approved SketchyBar expansion baseline

Approved on 2026-11-12. Preserve this appearance in subsequent work.

- Both bars have `margin=0`; AeroSpace gaps remain unchanged.
- Main `sketchybar`: height 40pt, y-offset 4pt, `topmost=on`.
- Detail `sketchibar`: height 80pt, y-offset 4pt, `topmost=window`.
  Its background sits behind the main bar, forming one expanded outline.
- All detail items and brackets use `y_offset=-20`, placing the information
  in the lower row. Positive offsets move upward and hide it behind the main bar.
- Main item positions and sizes are unchanged.
- Both backgrounds: `0xff0a1f2e`, border color `0xff0a1f2e`,
  border width 3pt, corner radius 8pt, shadow off, blur radius 0.
- Width follows each display automatically, with no horizontal outer margin.

## Persistence status

The detail-bar startup configuration preserves the 80pt backplate,
zero margin and lower-row offsets. The main bar's `margin=0` and `topmost=on`
are also persisted in its configuration. Coordinated toggle/restore behavior
for the bar backgrounds is not implemented; Pomodoro display routing is
coordinated through the `sketchibar` wrapper.

`topmost=window` was verified as native window layer 3 for the detail bar;
the main bar is layer 25. SketchyBar's bar query reports `topmost=on` for
the detail bar even when its actual layer is 3.

## Live information

The lower row is right-aligned, ordered wake prevention → battery → weather. Wi-Fi was removed
at the user's request.
Battery and wake prevention refresh every 60 seconds and on relevant system events;
weather refreshes every 30 minutes, on wake and on Wi-Fi changes.

- Wake prevention: the main bar's rounded-square state icon plus remaining
  assertion time for the selected `caffeinate` PID. The box and its group gap
  are hidden when inactive; `--` means timeout unknown while active. Claude
  resume processes are excluded. Main-bar toggles emit `cafe_changed` to the
  detail bar after process/assertion readiness. Its independent Coffee worker
  refreshes immediately on that event, on wake and every 60 seconds; battery
  collection never overwrites Coffee state or blocks its refresh.
- Battery: percentage, macOS remaining-time estimate (`↑` for charging,
  only when at least one minute). The whole time item is hidden for zero,
  unknown or invalid estimates and when fully charged; the battery icon and
  percentage remain visible.
- Connected keyboard and trackpad battery percentages follow the Mac battery
  within the same group (`keyboard` and `rectangle` Tabler icons). These refresh
  every 60 seconds with system data. Only currently connected devices with a
  valid 0–100% reading are shown; missing/disconnected or ambiguous same-kind
  devices are hidden. No device names, addresses or historical values are saved.
- Weather: current (apparent) temperature, today's low/high, current-hour
  precipitation probability (including snow), wind speed in m/s.
- Weather uses IP-derived location (ipinfo.io) and Open-Meteo. Network failures
  clear values to `—`, rather than showing samples or unlabeled stale values.

Main-bar battery and wake-prevention hover popups are removed. The main
wake-prevention icon still toggles the session on click. Sound remains a
read-only device/mute indicator without hover, click or device-switching UI.

The lower-row Pomodoro item sits immediately left of wake prevention in the
same right-aligned flow, avoiding collisions with a fixed notch anchor on narrow
displays. It receives display updates from the main bar's
single timer engine. When the detail bar is hidden or exited through the wrapper,
the original main-bar timer popup returns. No timer state or notifications are
owned by the detail bar; toggling visibility never resets a session.
