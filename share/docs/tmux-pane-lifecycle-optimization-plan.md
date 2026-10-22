# tmux Pane Lifecycle Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tmux pane lifecycle 및 attention 처리를 정확한 window로 한정하고 상태가 없는 공통 전환 경로의 작업을 제거한다.

**Architecture:** `tmux-pane-attention`이 한 번의 snapshot에서 pane/window/attention 상태를 읽고 실제 상태 변경만 반영한다. `.tmux.conf`의 조건부 hook과 전용 indexed lifecycle hook이 controller의 `reconcile-window` operation을 호출한다.

**Tech Stack:** POSIX sh, tmux hooks/formats, Bash integration tests, fish repository checks

**Spec:** `share/docs/tmux-pane-lifecycle-optimization-design.md`

## Global Constraints

- macOS 기본 도구와 POSIX `sh`에서 동작해야 한다.
- Tilish 원본 TPM plugin을 유지한다.
- 기존 `Alt-[`, `Alt-]`, prefix/Korean pane binding을 유지한다.
- 다른 plugin이나 사용자 indexed hook을 삭제하지 않는다.
- 동작 변경은 실패하는 회귀 테스트를 먼저 작성한다.

---

### Task 1: Attention no-op fast path

**Files:**
- Modify: `setup/tests/tmux-pane-attention.test.sh`
- Modify: `home/.local/libexec/tmux-pane-attention`
- Modify: `home/.tmux.conf`

**Interfaces:**
- Consumes: pane snapshot from `tmux list-panes -a`
- Produces: `pane_attention_state <pane-id>` lookup and conditionally launched acknowledge hooks

- [ ] **Step 1: Write failing tests**

Add assertions that an absent `@attention_state` causes no pane option unset, no window aggregate query, and no `refresh-client`. Add config assertions requiring attention-gated focus/window/resize hooks and a zoom-plus-attention gated pane-selection hook.

- [ ] **Step 2: Verify RED**

Run: `setup/tests/tmux-pane-attention.test.sh`

Expected: FAIL because the current controller unsets missing state and hooks always launch the helper.

- [ ] **Step 3: Implement the minimal fast path**

Extend `pane_rows` to `window_id|pane_id|attention_state`, add a snapshot lookup, and return early from `unset_attention_state` when the snapshot state is empty. Update the four high-frequency hooks with tmux format conditions; require zoom for `after-select-pane`.

- [ ] **Step 4: Verify GREEN**

Run: `setup/tests/tmux-pane-attention.test.sh`

Expected: `PASS: tmux-pane-attention`.

- [ ] **Step 5: Commit**

```bash
git add home/.local/libexec/tmux-pane-attention home/.tmux.conf setup/tests/tmux-pane-attention.test.sh
git commit -m "perf(tmux): skip no-op attention updates"
```

### Task 2: Safe lifecycle hook ownership and target

**Files:**
- Modify: `setup/tests/tmux-pane-attention.test.sh`
- Modify: `home/.tmux.conf`

**Interfaces:**
- Consumes: Tilish-created `pane-exited[0]` and `M-Q` binding
- Produces: target-aware pane-exit hook and dedicated indexed after-kill hook

- [ ] **Step 1: Write failing integration tests**

Create two windows in the isolated tmux server. Keep one active, terminate a pane in the inactive window, and assert the hook command targets `#{hook_window}`. Seed an unrelated indexed `after-kill-pane` callback and assert it survives config loading. Assert `M-Q` contains only `kill-pane`, leaving layout to the hook.

- [ ] **Step 2: Verify RED**

Run: `setup/tests/tmux-pane-attention.test.sh`

Expected: FAIL because hooks are globally cleared, layout has no target, and Tilish `M-Q` repeats layout work.

- [ ] **Step 3: Implement owned hooks**

Replace only Tilish's known pane-exit index after TPM loading, add this configuration's high indexed after-kill callback without `set-hook -gu`, and override `M-Q` to invoke `kill-pane` once. Use `run-shell` format expansion for `#{hook_window}`.

- [ ] **Step 4: Verify GREEN**

Run: `setup/tests/tmux-pane-attention.test.sh`

Expected: all lifecycle ownership and target assertions pass.

- [ ] **Step 5: Commit**

```bash
git add home/.tmux.conf setup/tests/tmux-pane-attention.test.sh
git commit -m "fix(tmux): scope pane lifecycle hooks"
```

### Task 3: Window-scoped reconciliation

**Files:**
- Modify: `setup/tests/tmux-pane-attention.test.sh`
- Modify: `home/.local/libexec/tmux-pane-attention`
- Modify: `home/.tmux.conf`

**Interfaces:**
- Consumes: `reconcile-window <window-id>` operation argument
- Produces: reconciliation limited to panes and aggregate state in the requested surviving window

- [ ] **Step 1: Write failing controller and integration tests**

Invoke `reconcile-window @1` with panes in `@1` and `@2`. Assert title/state reads and aggregate synchronization occur for `@1` only. Assert pane lifecycle hooks pass their affected window ID to this operation.

- [ ] **Step 2: Verify RED**

Run: `setup/tests/tmux-pane-attention.test.sh`

Expected: exit 64 or missing-call failures because `reconcile-window` does not exist.

- [ ] **Step 3: Implement scoped reconciliation**

Accept the new operation, iterate only matching snapshot rows, mark the requested window dirty directly, acknowledge only visible panes belonging to that window, then synchronize that window aggregate. Keep `reconcile-all` for startup and `pane-moved`.

- [ ] **Step 4: Verify GREEN and regression suite**

Run:

```bash
setup/tests/tmux-pane-attention.test.sh
fish setup/check.fish
```

Expected: both commands exit 0 and report all checks passed.

- [ ] **Step 5: Commit**

```bash
git add home/.local/libexec/tmux-pane-attention home/.tmux.conf setup/tests/tmux-pane-attention.test.sh
git commit -m "perf(tmux): reconcile only affected windows"
```

### Task 4: Runtime verification and migration

**Files:**
- Modify if findings require clarification: `share/docs/tmux-pane-lifecycle-optimization-design.md`

**Interfaces:**
- Consumes: completed hooks and controller
- Produces: verified active tmux configuration without legacy owned hook indices

- [ ] **Step 1: Run syntax and repository checks**

Run: `sh -n home/.local/libexec/tmux-pane-attention && bash -n setup/tests/tmux-pane-attention.test.sh && fish setup/check.fish`

Expected: exit 0.

- [ ] **Step 2: Inspect the final diff**

Run: `git diff main...HEAD --check && git diff --stat main...HEAD`

Expected: no whitespace errors; only controller, tmux config, tests, and requested documentation changed.

- [ ] **Step 3: Apply one-time active-server migration**

Unset only legacy `after-kill-pane[0]` and `[1]` from the running server, source the new configuration, then inspect `show-hooks` and `list-keys` to verify owned and unrelated callbacks coexist.

- [ ] **Step 4: Final verification**

Run the attention test and full repository check once more after migration. Record any tmux platform limitation in the design document rather than adding polling or a global hook reset.
