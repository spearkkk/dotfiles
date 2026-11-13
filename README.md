# Dotfiles

Personal macOS setup using fish, mise, and Homebrew.

## New Mac

Install Xcode Command Line Tools and wait for installation to finish:

```sh
xcode-select --install
```

Then, from the default macOS terminal:

```sh
git clone https://github.com/spearkkk/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash setup/install.sh
```

Open Ghostty and continue in fish. Sign in to the Mac App Store before running
bootstrap; the Brewfile includes App Store apps.

```fish
cd ~/.dotfiles
fish setup/bootstrap.fish
```

**Before applying:** back up existing dotfiles. Bootstrap changes macOS settings
and restarts the managed LaunchAgents. A failure does not roll back earlier steps.
Approve macOS permissions manually, including Accessibility for
AeroSpace/Hammerspoon and calendar access for calendar widgets.

Optional personal profile:

```fish
fish setup/profile.fish personal
```

Profiles are mutually exclusive: applying one removes the other known overlays.
To remove an overlay without replacing it:

```fish
fish setup/profile.fish --remove personal
```

`profiles/work/` is local-only and absent from a fresh clone; restore it separately
if needed. It is not required for the base setup.

## Existing local settings

Keep machine-specific zsh settings in `~/.zprofile.local`, not the managed
`~/.zprofile`. Bootstrap backs up an unmanaged `.zprofile` under
`~/.local/state/dotfiles/backups/` and prints the backup location.

If migration reports a conflict with `.zprofile.local` or a foreign symlink,
back up and review the files manually before retrying. Do not overwrite the
local file; exclude duplicate Homebrew initialization and recursive local-file
loaders when merging. To undo migration, move the managed link aside and restore
the printed backup, preserving `.zprofile.local` separately.

## Reapply or restart

Run from the active `~/.dotfiles` checkout, not a temporary worktree:

```fish
fish setup/bootstrap.fish --list-steps
fish setup/bootstrap.fish --only theme --only stow
fish setup/bootstrap.fish --only sketchybar-lua
fish setup/bootstrap.fish --only sketchybar-fonts
fish setup/bootstrap.fish --only profiles --profile personal
make -C setup/launchagents restart
make -C setup/launchagents status
tmux source-file ~/.tmux.conf
```

Select only the commands you need. `--only` does not install prerequisites
automatically. Link the base helpers before starting LaunchAgents. Plists are
copied, not symlinked; use `make restart` to reinstall them after changes.

The default bootstrap installs SF Pro through the common Brewfile and the
pinned Tabler icon font through `sketchybar-fonts`. If the matching regular
Tabler font is present, the installer moves it to a unique backup under
`~/Library/Application Support/SketchyBar/font-backups/` to avoid font-name
conflicts; it refuses to overwrite an unrecognized font.

To stop and disable the managed media/calendar agents:

```fish
make -C setup/launchagents teardown
```

`make restart` enables them again. If using Stow manually, run
`bash setup/prepare-zprofile.sh` first and use `--no-folding` to avoid overlay
conflicts.

## Verify

Requires the tools in `setup/Brewfile`, Xcode Command Line Tools, and mise Lua 5.4:

```fish
mise install lua@5.4
fish setup/check.fish
bash setup/install-sketchybar-lua.sh --check
```

The separate `bash setup/tests/sketchybar-bridge-smoke.sh` is an optional **live**
check that updates existing widgets; it is not part of the default checker.

## Optional second bar

`sketchibar` runs an independent SketchyBar instance using
`~/.config/sketchibar/sketchibarrc`. After applying the base Stow package:

```fish
sketchibar &                          # start hidden; not enabled at login
sketchibar --bar hidden=toggle        # toggle visibility without stopping it
sketchibar --bar hidden=off           # show
sketchibar --bar hidden=on            # hide
sketchibar --exit                     # stop only the second bar
```

Hover anywhere over the main bar to reveal the detail bar. Moving into the
detail row keeps it open; leaving both bars closes it after 300ms. Re-entry
cancels a pending close. Before closing, a one-shot native cursor query checks
the actual display/bar bounds, handling overlapping tracking areas and late
relay events; this adds a small query delay after the 300ms debounce. Transient
query failures retry up to three times and otherwise log a diagnostic. There
is no continuous cursor polling. There is no extra button or shortcut, and manual
visibility commands above still work. The optional process must already be
running; hovering does not launch it. Both configurations start with the detail
bar hidden. Geometry is unchanged: native `hidden` is boolean and cannot be
animated directly, so opening/closing is instantaneous.

It spans each display with an 80pt backplate and puts wake-prevention time,
battery and weather
in the lower row, aligned right. The main bar must use `margin=0` and
`topmost=on` to sit above it (both are configured in the main bar; see the
[approved baseline](share/docs/sketchibar-baseline.md)).
Battery and wake-prevention time refresh every 60 seconds and on relevant system events;
weather refreshes every 30 minutes, on wake and on Wi-Fi changes. Weather uses
IP-based location from ipinfo.io and Open-Meteo, with current-hour precipitation
probability (including snow), today's low/high and wind in m/s.
Missing weather values show `—`. Battery time is macOS's estimate;
`↑` means time to full. The time item, including its icon and spacing, is hidden
when fully charged, zero, unavailable or invalid. Wi-Fi details are not collected.
The same battery group shows Mac battery/time → connected keyboard → connected
trackpad, using Tabler `keyboard` and `rectangle` icons. Peripheral values refresh
with the 60-second system collector and on wake/power events. Bluetooth System
Profiler data identifies connected devices; Bluetooth HID registry data supplies
missing battery values. Unknown/disconnected devices are hidden, never cached.
There is one slot per device kind; ambiguous multiple keyboards or trackpads are
hidden rather than displaying an unidentified value. AirPods/mouse batteries
are not included yet. Device names and addresses are not persisted.
There are no device hover popups or shortcuts. Reload with `sketchibar --reload`.
The main bar's battery and wake-prevention hover popups are removed; its
wake-prevention click toggle remains. Sound is a read-only status icon with
no popup or output-device selection. Wake time is read from the selected
`caffeinate` process's macOS assertion (`--` if no timeout can be determined);
Claude resume sessions are excluded as in the main bar. When inactive, the
detail Coffee box and its group spacing are hidden. Main-bar toggles wait for
process/assertion readiness before sending `sketchibar --trigger cafe_changed`.
A dedicated Coffee collector handles that event immediately, independently of
Bluetooth/battery collection, with a 60-second fallback and wake refresh.

Pomodoro keeps one timer engine in the main bar. While the detail bar is visible,
its leftmost right-aligned item shows the phase icon, cycle and remaining time instead of
the main popup. Hiding or stopping the detail bar restores that popup without
resetting the timer. Main-bar controls and notifications are unchanged.
Use the `sketchibar` wrapper for visibility/reload/exit commands: it notifies the
main bar to re-query visibility. Direct binary commands bypass this notification.
Transient IPC failures fall back to the main popup with up to three retries;
an absent optional bar is not polled indefinitely.

## Maintenance choices

- **SketchyBar Lua bridge:** [the lock file](setup/sketchybar-lua.lock.json) pins
  the Lua 5.4-compatible upstream revision because newer upstream code moved to
  Lua 5.5. Review ABI compatibility and installer tests before changing the pin;
  do not replace it with upstream `main` blindly.
- **Theme source:** edit [simhae-theme](https://github.com/spearkkk/simhae-theme),
  not the palette snapshot in this repository. With mise-managed Node 24,
  update from its local checkout and regenerate:

  ```fish
  bash setup/sync-simhae.sh ~/Projects/simhae-theme
  bash setup/set-theme.sh
  ```
