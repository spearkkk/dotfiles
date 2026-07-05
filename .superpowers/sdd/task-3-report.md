## 2026-07-05 Task 3

### Scope
Implemented Task 3 runtime logic in `.config/sketchybar/plugins/volume.lua` for the SketchyBar output-device popup contract introduced by Task 2.

### Changes
- Replaced the prior mute-toggle-only Lua runtime with output-device popup behavior.
- Added support for `--refresh`, `--toggle-popup`, `--select <device_name>`, and `--timeout-close`.
- Wired runtime state through:
  - `/tmp/sketchybar.volume.popup.open`
  - `/tmp/sketchybar.volume.popup.token`
- Integrated device discovery and icon selection through `lib.audio_devices` and `SwitchAudioSource`.
- Restored the executable bit on `plugins/volume.lua` after file replacement so SketchyBar `click_script` execution still works.

### Verification
Required commands from the brief:
- `lua /Users/al02494219/.dotfiles/.config/sketchybar/tests/audio_devices_spec.lua`
  - Result: failed
  - Error: `module 'lib.audio_devices' not found`
  - Notes: the spec prepends `./lua/...` to `package.path`, so running it from `/Users/al02494219/.dotfiles` does not resolve `.config/sketchybar/lua`.
- `sketchybar --reload`
  - Result: passed (exit code 0)
- `SwitchAudioSource -t output -a`
  - Result: passed (exit code 0)

Supplemental diagnostic check:
- `cd /Users/al02494219/.dotfiles/.config/sketchybar && lua tests/audio_devices_spec.lua`
  - Result: passed
  - Output: `ok: audio_devices_spec`

### Manual validation
Not performed in this session. GUI-driven behaviors still need direct user verification for:
1. Popup opens with fade on volume click.
2. Selecting a device switches output, closes popup, and updates the icon.
3. Popup auto-closes after 3 seconds.
4. Muted/unmuted color flips correctly.

### Files changed
- `.config/sketchybar/plugins/volume.lua`
- `.superpowers/sdd/task-3-report.md`
