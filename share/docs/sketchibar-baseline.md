# Approved SketchyBar expansion baseline

Approved on 2026-11-12. Preserve this appearance in subsequent work.

- Both bars have `margin=0`; AeroSpace gaps remain unchanged.
- Main `sketchybar`: height 40pt, y-offset 0pt, `topmost=window` (layer 3, below the auto-hidden macOS menu bar at layer 24).
- Detail `sketchibar`: height 40pt, y-offset 40pt, `topmost=window`.
  It occupies the row directly below the main bar and never overlaps it; the
  matching background and border colors make one expanded outline.
- Detail items and brackets use `y_offset=0` within that row.
- Main item positions and sizes are unchanged.
- Both backgrounds: `0xff0a1f2e`, border color `0xff0a1f2e`,
  border width 3pt, corner radius 0pt (square), shadow off, blur radius 0.
- Width follows each display automatically, with no horizontal outer margin.

## Persistence status

The detail-bar startup configuration preserves the 40pt lower row,
zero margin and its y-offset. The main bar's `margin=0` and `topmost=window`
are also persisted in its configuration. The detail bar starts hidden. Main-bar
global hover reveals it; it stays open over either bar and closes 300ms after
leaving both. Re-entry cancels a pending close. No geometry animation or separate
button is used; manual wrapper visibility commands remain available. Pomodoro
display routing is coordinated through the `sketchibar` wrapper.

`topmost=window` was verified as native window layer 3 for both bars, so the
auto-hidden macOS menu bar (layer 24) appears above them. The bars do not
overlap, so their same-layer order does not matter. An earlier 80pt detail
backplate behind the main bar needed `sketchybar --bar topmost=window` after
each show to stay below it, and that re-assertion flickered on hover. Detail
`topmost=off` is layer -20 and normal windows cover it. SketchyBar's bar query
reports `topmost=on` even when the actual layer is 3.

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
