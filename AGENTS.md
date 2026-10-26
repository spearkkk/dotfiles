# dotfiles - Agent Guide

## Behavior

1. Don't assume. Don't hide confusion. Surface tradeoffs.
2. Minimum code that solves the problem. Nothing speculative.
3. Touch only what you must. Clean up only your own mess.
4. Define success criteria. Loop until verified.
5. Don't ignore errors. Find the root cause.
6. Don't create bidirectional dependencies.
7. Never expose secrets in public places.

## Repository Rules

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

## Commit & PR

- Write commit messages in imperative form: `<Verb> <what changed>`.
- Prefer short, natural titles like `Update fish function` or `Add SketchyBar item`.
- Before committing, always check changed files for secrets.
- Never force push or run destructive git commands without explicit confirmation from the user.
