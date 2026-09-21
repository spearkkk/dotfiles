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
Brewfile, generates theme colors, stows base dotfiles, applies macOS defaults,
and installs/restarts LaunchAgents:

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
- `setup/`: base install/apply/generator scripts.
- `setup/Brewfile`: common Homebrew, cask, and MAS apps.
- `setup/launchagents/`: LaunchAgent load/status/teardown helpers.
- `share/`: resources, source assets, exports, and documentation that are not installed directly.

## Profiles

Profiles are mutually exclusive overlays. Applying one profile removes other
known profile overlays first, then links the selected profile.

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

Use `--no-folding` so base dotfiles and profile overlays can share directories
like `~/.config/fish/conf.d`.

```fish
stow --no-folding --dir=home --target=$HOME .
stow --no-folding --dir=profiles/personal/home --target=$HOME .
stow --no-folding --dir=profiles/work/home --target=$HOME .
```

## Targeted reruns

Bootstrap runs these for you, but each part can be rerun directly:

```fish
bash setup/set-theme.sh
bash setup/set-macos.sh
make -C setup/launchagents bootstrap
make -C setup/launchagents status
fish setup/check.fish
```
