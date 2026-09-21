# dotfiles - Agent Guide

## Rules

- This repository is the active dotfiles source.
- Keep root content minimal: `AGENTS.md`, `CLAUDE.md`, `README.md`, and layout directories.
- Put files that should be symlinked into `~/` under `home/`.
- Put optional profile overlays under `profiles/<name>/home/`.
- Put install/apply/template material under `setup/`.
- Put non-installed source material, assets, exports, and docs under `share/`.
- Never move private, secret, or company-internal content into tracked paths without explicit user approval.
- Treat `profiles/work/` as local-only unless the user explicitly decides to track reviewed work-safe content.

## Layout

```text
home/      # base stow package targeting ~
profiles/  # optional personal/work overlays
setup/     # bootstrap, brew, macOS defaults, launchagents, generators
share/     # assets, source resources, exports, docs
```
