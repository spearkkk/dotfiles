# tmux Alt Pane Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore `Alt+h/j/k/l` focus navigation while retaining
`Alt+Shift+h/j/k/l` pane reordering.

**Architecture:** tmux's root key table owns both shortcut families.
Plain Meta keys call built-in `select-pane`; Shift+Meta keys continue invoking
the existing Tilish-aware movement helper. A shell regression test asserts the
two families remain assigned to their separate commands.

**Tech Stack:** tmux 3.8 configuration; Bash regression tests.

**Spec:** `share/docs/2026-10-24-tmux-alt-pane-navigation-design.md`

## Global Constraints

- Keep `Alt+h/j/k/l` as focus-only navigation.
- Keep `Alt+Shift+h/j/k/l` as pane reordering through `tmux-move-pane`.
- Do not change Tilish settings or `tmux-move-pane`.

## Review Focus

- Plain `Alt+h` must use lowercase `M-h`, not uppercase `M-H`, because they
  are distinct tmux key names; test in Task 1.
- Every direction must map to its matching `select-pane` flag; test all four
  lines in Task 1.
- Shift+Alt bindings must keep invoking `tmux-move-pane`, not `select-pane`;
  test all four lines in Task 1.
- Root-table bindings must be unprefixed (`-n`); test exact lines in Task 1.

### Task 1: Restore and Lock Down Plain Alt Focus Navigation

**Files:**
- Modify: `setup/tests/tmux-move-pane.test.sh`
- Modify: `setup/tests/tmux-pane-attention.test.sh`
- Modify: `home/.tmux.conf`

**Interfaces:**
- Consumes: tmux root key syntax and the existing `tmux-move-pane` helper.
- Produces: four unprefixed `M-h/j/k/l` focus bindings and regression coverage
  that distinguishes them from `M-S-H/J/K/L` movement bindings.

- [ ] **Step 1: Write the failing test**

Add exact-line assertions to `setup/tests/tmux-move-pane.test.sh` requiring:

```bash
bind-key -n M-h select-pane -L
bind-key -n M-j select-pane -D
bind-key -n M-k select-pane -U
bind-key -n M-l select-pane -R
```

and retaining each existing `M-S-H/J/K/L` helper binding.
Update the legacy Tilish ownership guard in
`setup/tests/tmux-pane-attention.test.sh` so it continues to reject the
obsolete `Alt+z` zoom binding but permits the intentional plain Alt focus
bindings covered by the movement test.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash setup/tests/tmux-move-pane.test.sh`

Expected: FAIL because the four lowercase `M-h/j/k/l` bindings are absent.

- [ ] **Step 3: Add the plain Alt focus bindings**

Insert the four exact `bind-key -n M-h/j/k/l select-pane` lines adjacent to
the unprefixed Shift+Alt pane movement bindings in `home/.tmux.conf`.

- [ ] **Step 4: Run focused verification**

Run: `bash setup/tests/tmux-move-pane.test.sh`

Expected: `PASS: tmux-move-pane`.

- [ ] **Step 5: Run repository checks**

Run: `fish setup/check.fish`

Expected: exit code 0, including tmux movement checks.

- [ ] **Step 6: Commit**

```bash
git add home/.tmux.conf setup/tests/tmux-move-pane.test.sh \
  setup/tests/tmux-pane-attention.test.sh \
  share/docs/2026-10-24-tmux-alt-pane-navigation-design.md \
  share/docs/2026-10-24-tmux-alt-pane-navigation-plan.md
git commit -m "fix(tmux): restore Alt pane focus navigation"
```
