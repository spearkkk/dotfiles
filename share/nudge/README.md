# Nudge notifications and sound

Nudge sends passive, three-second Hammerspoon Canvas toasts. Hammerspoon must
already be running with the Nudge service loaded. The CLI never launches it.
Requests and saved state are plaintext; do not include secrets in titles,
bodies, context, or sound paths. CLI arguments can be visible to other processes.

## Send a sound

```fish
nudge send --source pomodoro --event work-completed --preset timer-ended \
  --title '집중 완료' --body '5분간 쉬세요' --sound Glass
nudge send --title '작업 완료' --sound-file '/absolute/path/chime.wav'
nudge send --title '조용한 알림' --silent
```

The three sound options are mutually exclusive. No option means no sound unless
user defaults or a preset selects one. `--silent` overrides both. System sounds
are resolved from `~/Library/Sounds`, `/Library/Sounds`, `/Network/Library/Sounds`,
then `/System/Library/Sounds`, using the filename without its extension. Matching
files within each directory are tried in lexical order until one loads. Both named
and explicit file sounds use independent `hs.sound.getByFile` objects and must
be readable audio supported by macOS. File paths must be absolute; Nudge does
not expand `~`, environment variables, URLs, or shell expressions. Volume follows
the system output setting; Nudge does not change volume or loop playback.
Each event has an independent playback object, so sounds may overlap, including
repeated uses of the same name. This avoids Hammerspoon's shared named-object
callback/finalizer races. Completion detaches the callback and releases the object.
Names registered only in memory by other Hammerspoon code are not searched;
use `--sound-file` for audio outside the standard sound directories.

## JSON and configuration

The optional request field is `"sound":{"name":"Glass"}`,
`"sound":{"file":"/absolute/path/chime.wav"}`, or `"sound":false`.
The object must contain exactly one of `name` and `file`.

```fish
printf '%s\n' '{"source":"pomodoro","content":{"title":"집중 완료"},"sound":{"name":"Glass"}}' | nudge send --json -
```

User configuration lives at `~/.nudge/config.json`. For example:

```json
{
  "version": 1,
  "presets": {
    "timer-ended": {"severity": "info", "sound": {"name": "Glass"}},
    "quiet": {"sound": false}
  }
}
```

`defaults.sound` is also supported. Resolution order is built-in defaults → user
defaults → selected preset → explicit request. A sound selection replaces the
entire previous selection, so changing a file to a name cannot combine both.
Existing built-in presets remain silent. Reload Hammerspoon yourself after
installing updated code or changing configuration; no reload is automatic.

## Delivery and diagnostics

Audio starts asynchronously only after a notification is saved and its new or
updated toast is successfully submitted for display. Display submission is not
proof that the user saw or heard it. Duplicate suppression, dry runs, failed
saves/drawing, unavailable screens, and lock/sleep/session suppression never
play audio. Restoring saved state, redraws, expiry, and returning to an active
session never replay sounds. Updating the sound selection counts as a changed
request under the existing dedupe policy.

A `send` response includes `sound.status`:

- `not_requested`: no sound selected or explicitly silent.
- `skipped`: selected, but no eligible fresh displayed toast.
- `started`: playback started; completion is not guaranteed.
- `failed`: playback could not start; `sound.warning` contains a sanitized warning.

Invalid sound fields are request errors (exit code 2). Missing names/files or
playback faults do not roll back notifications, fail successful sends, or change
existing storage/renderer exit codes. There is no automatic retry or fallback.
A timeout still has unknown outcome: do not automatically resend.

`nudge capabilities` advertises name/file/silent support. `nudge doctor` includes
`sound.available` and a sanitized `sound.last_error` for audio failures, including
asynchronous completion failures. The last error remains diagnostic until the
service restarts; it does not mark the renderer unhealthy or change doctor's exit
code. Running playback stops when the service stops or Hammerspoon reloads.

## Pomodoro integration

SketchyBar's Pomodoro sends completion notifications through the installed
`~/.local/bin/nudge` using nonblocking `Sbar.exec`, replacing macOS Notification
Center notifications. Work/break timers, click commands, saved state and automatic
transitions are unchanged.

| Transition | Event | Sound |
| --- | --- | --- |
| Work → short break | `work-completed` | `Glass` |
| Work → long break | `work-completed` | `Hero` |
| Break → work | `break-completed` | `Ping` |

Sounds still come from the `pomodoro_sound_*` settings in SketchyBar's
`lib/settings.lua`. Notifications use source `pomodoro`, preset `timer-ended`,
and a durable TTL of 60 seconds; the transient toast remains three seconds.
Starting, stopping and manually switching modes do not send notifications.

The timer immediately starts its next phase without waiting for notification
IPC. Delivery failures and sound-start warnings produce sanitized entries in
`~/.sketchybar.log`; there is no retry or fallback notification. Locked/inactive
sessions follow Nudge's existing silent-suppression policy.

When applying these changes, install the updated Nudge CLI and Hammerspoon
modules together, reload Hammerspoon, then reload SketchyBar. The CLI needs `jq`
and `hs` on SketchyBar's process PATH. Updating only Pomodoro or only the CLI is
not sufficient: the running Nudge service must support the sound field. Changes
in an isolated worktree do not update the active installation automatically.

## Verification

Use `mise x lua@5.4 -- lua setup/tests/nudge-sound.test.lua` for contract and audio
lifecycle tests, plus the existing `setup/tests/nudge-*.test.lua`, CLI and tmux
Nudge suites. Run `mise x lua@5.4 -- lua setup/tests/sketchybar-pomodoro.test.lua`
for phase transitions, sound mapping, shell quoting and asynchronous failure
handling. Automated tests fake audio and do not play sounds or reload the
running Hammerspoon service. After installation/reload, manually check a named
sound and a local audio file with the commands above and inspect their responses.
