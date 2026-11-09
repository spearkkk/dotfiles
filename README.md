# Dotfiles

Personal macOS dotfiles with a small active layout:

```text
AGENTS.md
CLAUDE.md
README.md
home/       # base dotfiles stowed to ~/
profiles/   # optional profile overlays
setup/      # install/apply/generate scripts
share/      # resources that are not installed directly
```

## Fresh macOS setup

From the default macOS terminal:

```sh
xcode-select --install
git clone https://github.com/spearkkk/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash setup/install.sh
```

After this, Homebrew, fish, and Ghostty are installed, and the login shell is
changed to fish. Open Ghostty and continue from fish. Bootstrap installs the
Brewfile, prepares mise Lua 5.4 and its pinned SketchyBar bridge, generates theme
colors, stows base dotfiles, applies macOS defaults, and installs/restarts
LaunchAgents:

```fish
cd ~/.dotfiles
fish setup/bootstrap.fish
```

For a profile-specific setup:

```fish
fish setup/bootstrap.fish --profile personal
```

If a local work profile exists, it can be applied the same way:

```fish
fish setup/bootstrap.fish --profile work
```

## Structure

- `home/`: base dotfiles whose contents should appear under `~/` on every Mac.
- `profiles/<name>/home/`: optional profile overlay applied after `home/`.
- `profiles/<name>/setup/`: profile-owned install or post-stow steps.
- `profiles/<name>/setup/templates/home/`: initial file templates copied under
  `~/` only when the destination does not already exist.
- `setup/`: base install/apply/generator scripts.
- `setup/Brewfile`: common Homebrew, cask, and MAS apps.
- `setup/launchagents/`: LaunchAgent load/status/teardown helpers.
- `share/`: resources, source assets, exports, and documentation that are not installed directly.

User-facing commands belong under `home/.local/bin/`. Internal executable
entry points belong under `home/.local/libexec/` and use `scope-action-target`
names. Profile-owned helpers follow the same rule inside that profile's `home/`.
Loaded shell functions and application modules remain in their native paths.
The tmux status renderer and SketchyBar calendar/media daemons are internal
entry points; their callers use explicit `~/.local/libexec/` paths, not PATH lookup.

`openit <artifact>` opens AI-generated output for review. Text artifacts open
in Neovim (in a new window when called from tmux), while HTML, PDF, images, and
HTTP(S) URLs open in a new Google Chrome window.

## Profiles

Profiles are mutually exclusive overlays. Applying one profile removes other
known profile overlays first, then links the selected profile. Profile setup
templates initialize missing files but do not overwrite existing user files.

```fish
fish setup/profile.fish personal
fish setup/profile.fish work
```

Remove a profile without applying another:

```fish
fish setup/profile.fish --remove personal
fish setup/profile.fish --remove work
```

`profiles/work/` is intentionally ignored by Git for now, so a fresh clone will
not include it. Keep work-only values, company-specific settings, and local
templates there unless explicitly reviewed and approved for tracking.

## Manual Stow equivalent

For an existing `~/.zprofile`, first follow the migration rules below or run
`bash setup/prepare-zprofile.sh` before Stow. Bootstrap does this automatically.

Use `--no-folding` so base dotfiles and profile overlays can share directories
like `~/.config/fish/conf.d`.

```fish
stow --no-folding --dir=home --target=$HOME .
stow --no-folding --dir=profiles/personal/home --target=$HOME .
stow --no-folding --dir=profiles/work/home --target=$HOME .
```

## Zsh login profile and local settings

Stow owns `~/.zprofile`; it sets the shared Homebrew/PATH environment and sources
`~/.zprofile.local` for user- or machine-specific settings. Keep local settings
outside the repository; `.zprofile.local` is also ignored by Git. The installer
does not create or modify `.zprofile`: it initializes Homebrew in its own process
and creates a temporary fish configuration for the next shell.

Before linking, bootstrap prepares an existing `.zprofile`:

- Missing file or a symlink to this repository: no migration needed.
- Regular file: preserve the original under
  `~/.local/state/dotfiles/backups/zprofile.XXXXXX/.zprofile`, and copy its contents
  unchanged into `.zprofile.local` before Stow links the common profile.
- Empty files, exact copies of the common profile, and files containing only the
  old installer's standard Homebrew initialization line are backed up without
  copying redundant settings into `.zprofile.local`.
- If migration would overwrite an existing `.zprofile.local`, or the old profile
  already references that file, stop without changing either file. Back up both,
  manually merge the desired local settings (excluding duplicate Homebrew setup
  and the local-file loader), move the old `.zprofile` aside, then rerun bootstrap.
- Foreign/broken symlinks and non-regular files require manual review.

Arbitrary shell code is not automatically filtered; review migrated settings for
duplicate Homebrew initialization and assumptions about the original file path.
The backup path is printed during migration. If a later Stow operation fails,
the backup and local settings remain available; resolve the reported conflict and
rerun bootstrap. To undo migration, move the managed `.zprofile` link aside and
restore the printed backup. Preserve/review `.zprofile.local` separately.

## Rolling out helper renames

Install only from the active dotfiles repository, never a temporary worktree.
Before integrating the rename, stop the existing SketchyBar calendar and media
LaunchAgents with `launchctl bootout` and confirm they have exited. This stops
them without changing their enabled state; `teardown` also disables the agents.

After integration, restow the base from the active repository, reinstall/restart
the LaunchAgents, then reload tmux. The plists are copied at install time, so
Stow alone does not update them:

```fish
stow --restow --no-folding --dir=home --target=$HOME .
make -C setup/launchagents bootstrap
tmux source-file ~/.tmux.conf
```

## Targeted reruns

Bootstrap can rerun only selected steps without reinstalling all packages or
reapplying macOS settings:

```fish
fish setup/bootstrap.fish --list-steps
fish setup/bootstrap.fish --only theme --only stow
fish setup/bootstrap.fish --only sketchybar-lua
fish setup/bootstrap.fish --only launchagents
fish setup/bootstrap.fish --only profiles --profile personal
```

`--only` is repeatable (`--only=stow` also works). Steps execute once each in
the following fixed order, regardless of argument order:

| Step | Action |
| --- | --- |
| `brew` | Install the common Brewfile; requires Homebrew and App Store sign-in for MAS apps |
| `sketchybar-lua` | Install/validate the pinned Lua bridge; may install mise Lua 5.4 |
| `theme` | Generate theme files in this repository |
| `stow` | Prepare `.zprofile`, restow base dotfiles, and remove the temporary Homebrew fish config when safe |
| `macos` | Apply macOS defaults |
| `launchagents` | Install plists and restart/re-enable the managed agents |
| `profiles` | Apply the requested profile overlays and their own setup steps |

Dependencies are **not** selected automatically. Required tools must already be
available on PATH, and LaunchAgents need the base helpers linked beforehand.
Include prerequisite steps explicitly when needed, such as `--only brew --only
stow`. Unselected steps are neither executed nor required: `--only stow` does
not install packages, build the bridge, regenerate themes, change macOS defaults,
or restart services. A selected profile may still install its own packages.

Without `--only`, the full bootstrap is unchanged; `--profile personal` still
applies that profile after all base steps. With `--only`, profile application
must be explicit: combine `--only profiles` with `--profile <name>`. Invalid
step/profile selections fail before changes; a runtime failure stops later
steps but does not roll back earlier completed steps.

Each underlying script can also be rerun directly:

```fish
bash setup/set-theme.sh
bash setup/set-macos.sh
make -C setup/launchagents bootstrap
make -C setup/launchagents status
fish setup/check.fish
```

LaunchAgent `bootstrap` (also used by `restart`) unloads existing jobs and confirms
both previous processes have exited before explicitly enabling, loading, and
starting either agent. It can therefore restart agents disabled by
`make -C setup/launchagents teardown`. Enabling either agent must
succeed before any job is loaded. The media and calendar daemons exit on
SIGINT/SIGTERM and remove only their own PID files on exit. Bash may defer signal
handling until an active foreground command returns.

`status` distinguishes `running` (launchd state plus PID), `loaded` (registered
but not running), `stopped` (not registered), and `unknown` (lookup failed).
Only both agents running yields exit status 0. `bootstrap` polls for readiness
instead of treating a transient startup state as failure.

`bootstrap`/`restart` and `teardown` share the same stop/cleanup helper: wait for
both deregistration and the recorded processes to exit before removing an
unchanged PID file. Only `teardown` disables agents during this stop phase.
Neither command signals a PID from a file, which could belong to an unrelated
process. Both startup and shutdown waits use 100 polls at 0.2-second intervals (plus command
overhead). Control/query errors, invalid or changed PID files, and stop timeouts
return nonzero and preserve that agent's PID file if still present. Already
stopped agents are safe to process again. On a stop failure, `bootstrap` aborts
before enabling or loading either agent; `teardown` still processes the other
agent before returning failure.

The calendar daemon deduplicates only rows with the same normalized start time,
end time, title, and calendar name. Same-title events at different times or in
different calendars remain separate. This is a display-row comparison, not an
event-ID comparison: distinct events with all four fields identical still merge.

Calendar queries use `uu-timeout` from the existing `uutils-coreutils` Brewfile
dependency: send TERM after 5 seconds, then KILL after one additional second if
needed. Failed or timed-out queries discard partial stdout and use the existing
180-second last-good cache grace period; subsequent polls/refreshes retry normally.
Without `uu-timeout`, the collector fails closed rather than running unbounded.
Diagnostics contain the exit status, not event contents. Bash can defer a daemon
shutdown signal until this bounded query finishes (roughly 6 seconds worst case
for a stalled collector).

Weather refreshes use asynchronous `Sbar.exec`, with only one fetch in flight.
The current display remains visible while fetching; startup and failed requests
show `--°`. Each of the two sequential HTTP requests has a 3-second connection
timeout and an 8-second total timeout (up to 16 seconds of network waiting).
The helper ignores user curlrc settings to prevent extra retries. The 30-minute
refresh interval and wake/Wi-Fi/manual refresh events are unchanged; events
during an active fetch are ignored, and later events can retry after failure.

### Neovim initialization

Java attaches JDTLS on each Java `FileType` event, resolving the project root
and workspace per buffer. Same-project buffers reuse the workspace; distinct
project roots keep separate workspaces. Rootless Java files remain unattached
without preventing later project files from attaching. Existing mise/JDK
selection is unchanged.

Treesitter resolves filetypes to parser names (including `sh`, React, and help
buffers). Folding and indentation are enabled only after the parser starts.
Parser installation remains asynchronous; completion retries loaded buffers,
and entering a buffer window reapplies its window-local folding settings.
Installation task errors are reported without disabling available parsers.

### Validation

The macOS checker requires the tools in `setup/Brewfile` and Lua 5.4 installed
through mise (`mise install lua@5.4`), plus Xcode Command Line Tools for the
offline installer build fixtures. It can be invoked from any directory and
does not require the ignored work profile; available local overlays are checked
when present. SSH tests use temporary fixtures and `ssh -G`, without connecting
to hosts or reading the user's SSH configuration.

`setup/check.fish` includes all `setup/tests/nudge-*.test.lua` suites and the
Nudge CLI tests. The storage suite uses temporary macOS files; rendering and IPC
are mocked, so no running Hammerspoon instance or desktop permissions are needed.

## SketchyBar Lua bridge

The Lua configuration loads `~/.local/share/sketchybar_lua/sketchybar.so`.
This is an installed native module, not the repository's `share/` directory.
Bootstrap now prepares it automatically; no binary is checked into Git.

```sh
bash setup/install-sketchybar-lua.sh          # install or reuse a verified build
bash setup/install-sketchybar-lua.sh --check # read-only installed-build validation
```

`setup/sketchybar-lua.lock.json` pins the upstream
[FelixKratz/SbarLua](https://github.com/FelixKratz/SbarLua) source commit and archive
SHA-256. Commit `437bd2031da38ccda75827cb7548e7baa4aa9978` is the last Lua 5.4-based
revision before upstream switched to Lua 5.5. Its unmodified build bundles Lua
5.4.7; the installer validates the result with mise's Lua 5.4 interpreter.
The previously installed local binary had no source receipt, so this pin does
not claim to identify that binary's exact origin.

The installer prepares Lua through mise if missing, verifies the source checksum,
and builds for the current `arm64` or `x86_64` environment. A temporary candidate
must pass architecture, exact-file loading, and required API checks before it
replaces `sketchybar.so`. Download, build, or validation failure leaves the old
binary intact. `install.json` records the pin, architecture, and binary checksum;
matching, loadable builds are reused without another download or build.
An old unmanaged binary without that receipt is rebuilt, not silently adopted.

Updating requires deliberately reviewing and changing the lock file, running the
installer tests, and rerunning the installer. Do not point it at upstream `main`
or change the Lua ABI without updating the configuration and tests together.

Default checks use offline build fixtures and never require an installed bridge.
The installer's load probe does not issue bar commands or enter the event loop.
The separate `setup/tests/sketchybar-bridge-smoke.sh` remains explicit opt-in: its
live event loop updates existing widgets, so it is not part of bootstrap or the
default checker. The installer itself never launches or reloads SketchyBar.

On a new Mac, approve required macOS permissions manually (for example,
Accessibility for AeroSpace/Hammerspoon and calendar access for calendar widgets).
Installing the bridge does not grant these permissions or verify live widgets.

## SketchyBar weather

`~/.local/libexec/sketchybar-fetch-weather` performs a one-shot location and
weather lookup using Bash, curl, and jq. It emits weather code, Celsius
temperature, and day/night flag as one tab-separated line; failures produce
no stdout and exit nonzero with diagnostics on stderr. `weather.lua` invokes
the helper by its HOME-based absolute path and owns icons, colors, rounding,
refresh events, and the `--°` fallback. Fetching remains synchronous, without
new caching, retries, or timeouts.

## cw pane contexts

`cw` uses the contexts defined by your profile. Without placement options it
applies them in the current tmux pane; it does not change windows or reuse a
different pane with matching contexts.

```fish
cw CONTEXT                       # current pane
cw CONTEXT --pane                # new pane to the right
cw CONTEXT --pane --bottom       # new pane below
cw CONTEXT --session SESSION     # new pane beside that session's active pane
cw CONTEXT --session SESSION --bottom
cw clear                         # clear contexts in the current pane
```

`--pane` (`-P`) and `--session` (`-s`) always create a fresh split in the target
window. `--bottom` requires one of them. The named session must already exist;
outside tmux, specify `--session`. Profile session defaults no longer select the
destination. Multiple contexts still apply to one pane, with rollback on failure.

## tmux activity status

The tmux window list shows unread attention from background panes:

- `?` means a background Codex pane title contains `Action Required | `.
- `✓` means a general command ran for at least 10 seconds and completed, or a
  background Codex pane changed from a spinner title to an idle title.
- A marker is cleared when its pane or window receives focus.

Set a different general-command threshold in fish before starting commands:

```fish
set -gx TMUX_ACTIVITY_MIN_SECONDS 30
```

Background pane transitions also send Nudge toasts:

- Entering `waiting`: **warning**, “입력이나 승인이 필요해요”.
- Entering `completed`: **info**, “작업이 끝났어요” (not a success assertion).
- Focused panes, unchanged states, and bulk reconciliation/reload do not notify.

`tmux-notify-pane-activity` runs asynchronously after the activity controller
unlocks, and rechecks focus/state before sending. Each transition is attempted
once; superseded jobs are dropped. Toasts use `source=tmux`, the session name,
and numeric window/pane location—not command text, pane output, cwd, or titles.
Avoid secrets in session names. Cards disappear after 3 seconds; these events
have a 60-second internal TTL, with no replay, click action, or focus change.

Nudge/Hammerspoon failures do not affect tmux markers. There is no automatic
launch, retry, or persistent queue. Check a pane's most recent delivery error
(cleared on its next delivery attempt):

```fish
tmux show-options -pqv -t %1 @activity_nudge_error
```

Codex markers depend on its current braille-spinner titles and the
`Action Required | ` segment; arbitrary TUIs waiting for input are not detected.
Reload tmux after applying the dotfiles:

```fish
tmux source-file ~/.tmux.conf
```

## Simhae palette source

The canonical palette is maintained in [spearkkk/simhae-theme](https://github.com/spearkkk/simhae-theme). This repository consumes the snapshot at `share/themes/simhae/palette.yaml`; its exact source commit and checksum are recorded in `share/themes/simhae/source.json`. Edit the representative repository rather than this snapshot.

With Node 24 (managed by mise), update explicitly from a local checkout:

```sh
bash setup/sync-simhae.sh ~/Projects/simhae-theme
bash setup/set-theme.sh
```

The first command refuses to overwrite locally modified palette data. The second regenerates existing application configuration. Bootstrap continues to use the checked-in snapshot and does not fetch the network. See the representative repository's [maintenance guide](https://github.com/spearkkk/simhae-theme/blob/main/docs/maintenance.md).
