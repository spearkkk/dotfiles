# dotfiles - Agent Guide

## Behavior
1. Don't assume. Don't hide confusion. Surface tradeoffs.
2. Minimum code that solves the problem. Nothing speculative.
3. Touch only what you must. Clean up only your own mess.
4. Define success criteria. Loop until verified.
5. Don't ignore errors. Find the root cause.
6. Don't create bidirectional dependencies.
7. Never expose secrets in public places.

## Commit & PR
- Write commit messages in imperative form: `<Verb> <what changed>`.
- Prefer short, natural titles like `Update fish function` or `Add SketchyBar item`.
- Before committing, always check changed files for secrets.
- Never force push or run destructive git commands without explicit confirmation from the user.
