# SketchyBar Output Audio Device Popup Design

## Goal
Implement a single right-side SketchyBar audio item that:
- Shows only the currently selected output device icon.
- Uses muted/on color states.
- Opens a popup with output device list on click.
- Switches device on popup item click.
- Closes popup on selection or after idle timeout.
- Uses fade-in/fade-out for popup open/close.

## Scope
### In scope
- Output devices only.
- One main icon item (`lua.volume`).
- Popup list entries generated from installed `SwitchAudioSource` output devices.
- Device icon mapping using SF Symbol-style glyph mappings used by SketchyBar.
- Muted/unmuted color behavior aligned to existing theme variables.

### Out of scope
- Input device switching.
- Per-device volume sliders.
- New external daemons or services.

## Existing Context
- Current structure already follows `items/*.sh` + `plugins/*.lua`.
- Existing components (`pomodoro`, `battery`) already implement popup tokenized auto-close and fade logic.
- `volume` currently toggles mute only and does not provide device selection popup.

## Approaches Considered
### Approach A (recommended): `SwitchAudioSource` for routing + AppleScript for mute/volume
- Device list and switching via `SwitchAudioSource`.
- Mute/volume state via AppleScript `get volume settings`.
- Trade-off: two backends, but minimal code and good compatibility with current setup.

### Approach B: CoreAudio helper only
- Single backend via custom helper.
- Trade-off: more implementation and maintenance.

### Approach C: Cached state daemon
- Background process caches device state.
- Trade-off: smoother UX potential but unnecessary complexity right now.

## Selected Design
Adopt Approach A.

## Architecture
### Files
- Update `~/.config/sketchybar/items/volume.sh`
- Update `~/.config/sketchybar/plugins/volume.lua`
- Reuse existing color/theme variables from current sketchybar config.

### Responsibilities
- `items/volume.sh`
  - Define one bar item (`lua.volume`) on `right`.
  - Define popup container and popup row defaults.
  - Subscribe to `volume_change`, `system_woke`, and manual refresh events.
- `plugins/volume.lua`
  - `--refresh`: update current device icon and mute color.
  - `--toggle-popup`: open/close popup with fade and idle timeout.
  - `--select <device>`: switch output device, refresh icon, close popup.
  - Build popup entries dynamically from detected output devices.

## Data Flow
1. Refresh path
- Triggered by startup, wake, and volume events.
- Read current output device (`SwitchAudioSource -c -t output`).
- Read mute state (`osascript` volume settings).
- Resolve icon by device mapping.
- Resolve color by mute state.
- Apply icon/color to `lua.volume`.

2. Popup open path
- User clicks `lua.volume`.
- Plugin queries output device list (`SwitchAudioSource -a -t output`).
- Creates/updates popup rows.
- Marks popup token/state files for race-safe timeout.
- Enables popup drawing and runs fade-in.

3. Device selection path
- User clicks popup row.
- Plugin runs `SwitchAudioSource -s <device> -t output`.
- Refreshes main icon/color immediately.
- Closes popup via fade-out.

4. Idle close path
- Timeout worker checks token/state.
- If unchanged and still open, runs fade-out.

## Icon Mapping Spec (SF Symbol-style)
Default fallback icon: volume (`speaker.wave.2.fill` style glyph currently used in SketchyBar).

Matching rules:
- Normalize device string to lowercase.
- Evaluate most-specific patterns first.
- Stop at first match.

Map:
- `airpods pro`, `airpods max`, `airpods` -> headphones icon.
- `headphone`, `headset`, `earphone`, `buds` -> headphones icon.
- `monitor`, `display`, `hdmi`, `dp`, `usb-c monitor` -> display/speaker icon.
- `macbook`, `built-in`, `internal speakers` -> built-in speaker icon.
- `tv`, `apple tv`, `homepod` -> media output icon.
- no match -> fallback volume icon.

## Color Spec
- Main icon muted: muted/dim color.
- Main icon unmuted: on color.
- Popup rows: default foreground color.
- Selected/current device row may optionally use accent color, but not required for v1.

## Error Handling
- If `SwitchAudioSource` is unavailable/fails:
  - Keep main icon visible with fallback icon/color.
  - Skip popup device population gracefully.
- If selected device disappears:
  - Refresh and show current system output.
- If popup state gets stale:
  - Token check prevents outdated timeout from closing a newer popup.

## Testing Plan
1. Functional
- Click volume icon -> popup opens with output device list.
- Click device -> output switches and popup closes.
- No action -> popup auto-closes after timeout.
- Fade-in/fade-out visible for open/close.

2. State
- Mute/unmute changes icon color between muted/on states.
- Current device icon changes after switching device.

3. Compatibility
- Validate with built-in speaker, monitor output, and AirPods/headphones.

## Rollout
- Implement in-place with current `volume` item.
- No migration or data conversion required.
