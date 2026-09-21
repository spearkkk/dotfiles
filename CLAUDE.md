# dotfiles - Claude Guide

This repository is the active dotfiles source.

- `home/` contains base files intended to land under `~/` via Stow.
- `profiles/<name>/home/` contains optional profile overlays applied after `home/`.
- `setup/` contains scripts used to install, generate, or apply settings.
- `share/` contains resources that are not installed directly.
- Do not include secrets or company-internal details in tracked files.
- Treat `profiles/work/` as local-only unless explicitly approved for tracking.
