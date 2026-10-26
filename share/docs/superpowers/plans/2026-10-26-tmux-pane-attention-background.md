# Tmux Pane Attention Border Background Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep a waiting or completed pane's title and border background highlighted with the same color as its status-line attention marker until that exact pane receives focus.

**Architecture:** Preserve `@attention_state` as the single source of truth. Change the controller's acknowledgement set from every pane visible in a focused window to only the pane selected by each focused client, then render inactive pane border and title backgrounds from `@attention_state` with native tmux style formats and shared palette options. Leave pane content backgrounds unchanged.

**Tech Stack:** tmux 3.x formats and hooks, POSIX `sh`, Bash integration-test harness

**Spec:** Approved bounded design in this conversation on 2026-10-26; no separate spec file was created.

## Global Constraints

- A pane must retain attention until that exact pane is selected by a focused client.
- `waiting` uses gold `#C8AE6A`; `done` uses green `#68BE92`; both use foreground `#071420`.
- Pane and status-line attention colors must reference the same tmux palette options.
- Pane content backgrounds must remain unchanged.
- A selected pane uses the existing active border style immediately.
- Existing multi-client, zoomed-window, window aggregate, and status refresh behavior must remain covered.
- Keep root content minimal and store this plan under `share/docs/`.

---

### Task 1: Acknowledge Only the Focused Pane

**Files:**
- Modify: `setup/tests/tmux-pane-attention.test.sh:1-240`
- Modify: `home/.local/libexec/tmux-pane-attention:52-340`

**Interfaces:**
- Consumes: focused client rows in the existing `client_name|client_flags|window_id|pane_id|window_zoomed_flag` format.
- Produces: `is_focused <pane-id>` and `acknowledge_focused [window-id]` behavior; the public `acknowledge-visible` operation remains unchanged for hook compatibility.

- [ ] **Step 1: Change the unit tests to require exact-pane focus**

Replace the initial unzoomed expectation and multi-client acknowledgement assertions with cases equivalent to:

```bash
export FAKE_PANES=$'@1|%1\n@1|%2\n@2|%3'
export FAKE_CLIENTS='focused,UTF-8|@1|%1|0'
run_controller command-done %2 || fail unselected_done "controller exited $?"
assert_called unselected_done 'set-option .*%2 .*@attention_state done'

export FAKE_CLIENT_ATTENTION_ROWS='focused|done'
export FAKE_PANE_SNAPSHOT=$'@1|%1|\n@1|%2|done\n@2|%3|'
run_controller acknowledge-visible || fail unselected_not_acknowledged "controller exited $?"
assert_not_called unselected_not_acknowledged 'set-option .*%2 -u @attention_state|set-option .*%2 .* -u .*@attention_state'

export FAKE_PANE_SNAPSHOT=$'@1|%1|done\n@1|%2|\n@2|%3|'
run_controller acknowledge-visible || fail selected_acknowledged "controller exited $?"
assert_called selected_acknowledged 'set-option .*%1 -u @attention_state|set-option .*%1 .* -u .*@attention_state'
```

Update the multi-client case so only each focused client's selected pane (`%1` and `%3`) is cleared. Keep the zoomed test because its selected pane semantics should remain identical.

- [ ] **Step 2: Run the controller tests and verify RED**

Run:

```bash
bash setup/tests/tmux-pane-attention.test.sh
```

Expected: FAIL for `unselected_done` and/or `unselected_not_acknowledged` because the current snapshot treats all panes in an unzoomed focused window as visible.

- [ ] **Step 3: Replace visibility tracking with focused-pane tracking**

In `home/.local/libexec/tmux-pane-attention`, rename the internal collection and predicates while retaining the external operation name:

```sh
focused_panes=

is_focused() {
  wanted=$1
  while IFS= read -r row_pane; do
    [ "$row_pane" = "$wanted" ] && return 0
  done <<EOF
$focused_panes
EOF
  return 1
}

add_focused() {
  pane_exists "$1" || return
  is_focused "$1" && return
  focused_panes="${focused_panes}${focused_panes:+
}$1"
}

snapshot_focus() {
  pane_rows=$(tmux list-panes -a -F '#{window_id}|#{pane_id}|#{@attention_state}' 2>/dev/null) || return 1
  client_rows=$(tmux list-clients -F '#{client_name}|#{client_flags}|#{window_id}|#{pane_id}|#{window_zoomed_flag}' 2>/dev/null) || return 1
  focused_panes=

  while IFS='|' read -r client_name flags client_window client_pane zoomed; do
    case ",$flags," in
      *,focused,*) add_focused "$client_pane" ;;
    esac
  done <<EOF
$client_rows
EOF
  return 0
}
```

Rename internal calls from `is_visible` to `is_focused`, `snapshot_visibility` to `snapshot_focus`, and `acknowledge_visible` to `acknowledge_focused`. Iterate over `$focused_panes` in the acknowledgement helper. Do not rename the command-line operation or tmux hooks.

- [ ] **Step 4: Run the controller tests and verify GREEN**

Run:

```bash
bash setup/tests/tmux-pane-attention.test.sh
```

Expected: PASS with `0 failure(s)`.

- [ ] **Step 5: Commit the focus semantics**

```bash
git add home/.local/libexec/tmux-pane-attention setup/tests/tmux-pane-attention.test.sh
git commit -m "fix(tmux): acknowledge attention on pane focus"
```

### Task 2: Render Persistent Pane Border Backgrounds from Shared Attention Colors

**Files:**
- Modify: `setup/tests/tmux-pane-attention.test.sh:410-630`
- Modify: `home/.tmux.conf:90-150`

**Interfaces:**
- Consumes: pane-local `@attention_state` values `waiting`, `done`, or empty.
- Produces: global foreground/background options for waiting and done; `pane-border-style` evaluates each inactive pane's state, while `pane-active-border-style` uses the selected light accent. `window-style` is explicitly reset to `default` so config reloads clear the obsolete content-background style.

- [ ] **Step 1: Add failing configuration and integration assertions**

Add static assertions that status formats use shared palette options instead of literal attention backgrounds:

```bash
grep -qF "set -g @attention_waiting_bg '#C8AE6A'" "$tmux_config" || fail attention_waiting_palette "missing shared waiting background"
grep -qF "set -g @attention_waiting_fg '#071420'" "$tmux_config" || fail attention_waiting_foreground "missing shared waiting foreground"
grep -qF "set -g @attention_done_bg '#68BE92'" "$tmux_config" || fail attention_done_palette "missing shared done background"
grep -qF "set -g @attention_done_fg '#071420'" "$tmux_config" || fail attention_done_foreground "missing shared done foreground"
grep -q 'window-status-format.*#{E:@attention_waiting_bg}.*#{E:@attention_done_bg}' "$tmux_config" || fail attention_status_palette "status attention does not use shared colors"
grep -q 'pane-border-style.*@attention_state.*@attention_waiting_bg.*@attention_done_bg' "$tmux_config" || fail attention_pane_border_style "pane border background is not attention-aware"
if grep -q 'window-style.*@attention_state' "$tmux_config"; then
  fail attention_pane_content_style "pane content background must not be attention-aware"
fi
grep -qF 'set -g window-style "default"' "$tmux_config" || fail attention_pane_content_reset "pane content style is not reset on config reload"
```

In the isolated real-tmux section, set `@attention_state` on an inactive split pane and expand `#{E:pane-border-style}` in that pane's context. Assert the shared dark/gold pair for `waiting`, the dark/green pair for `done`, and the gold/base background pair after unsetting the option. Retain the selected active border style assertion.

- [ ] **Step 2: Run the tmux integration tests and verify RED**

Run:

```bash
bash setup/tests/tmux-pane-attention.test.sh
```

Expected: FAIL for the missing palette and pane style assertions.

- [ ] **Step 3: Define shared palette options and native pane styles**

In `home/.tmux.conf`, add shared colors before the status formats and consume them from both status and pane styles:

```tmux
set -g @attention_waiting_fg '#071420'
set -g @attention_waiting_bg '#C8AE6A'
set -g @attention_done_fg '#071420'
set -g @attention_done_bg '#68BE92'

set -g window-status-format '#{?#{==:#{@attention_window_state},waiting},#[fg=#{E:@attention_waiting_fg}#,bg=#{E:@attention_waiting_bg}#,bold],#{?#{==:#{@attention_window_state},done},#[fg=#{E:@attention_done_fg}#,bg=#{E:@attention_done_bg}#,bold],#[default]}}[#[underscore]#{window_index}#[nounderscore]·#{window_name}#{?#{==:#{@attention_window_state},waiting},?,#{?#{==:#{@attention_window_state},done},✓,}}]#[default]'

set -g window-style "default"
set -g pane-border-style "fg=#{?#{==:#{@attention_state},waiting},#{E:@attention_waiting_fg},#{?#{==:#{@attention_state},done},#{E:@attention_done_fg},#C8AE6A}},bg=#{?#{==:#{@attention_state},waiting},#{E:@attention_waiting_bg},#{?#{==:#{@attention_state},done},#{E:@attention_done_bg},#0A1F2E}}"
set -g pane-active-border-style "fg=#071420,bg=#C6D8E4,bold"
```

Set the current window and selected pane to the reviewed dark/light pair while preserving all window markers and attention-state logic.

- [ ] **Step 4: Run all tmux-related tests and verify GREEN**

Run:

```bash
for test_file in setup/tests/tmux-*.test.sh
  bash "$test_file"; or exit 1
end
```

Expected: every tmux test exits `0`, including `tmux-pane-attention.test.sh` with `0 failure(s)`.

- [ ] **Step 5: Reload in an isolated tmux server for a parse check**

Run:

```bash
socket="attention-plan-$fish_pid"
tmux -L "$socket" -f /dev/null new-session -d -s parse-check 'sleep 5'
tmux -L "$socket" source-file home/.tmux.conf
tmux -L "$socket" kill-server
```

Expected: all commands exit `0` with no parse errors.

- [ ] **Step 6: Commit the pane border background rendering**

```bash
git add home/.tmux.conf setup/tests/tmux-pane-attention.test.sh
git commit -m "fix(tmux): highlight attention pane borders"
```

### Task 3: Final Regression Verification

**Files:**
- Verify: `home/.tmux.conf`
- Verify: `home/.local/libexec/tmux-pane-attention`
- Verify: `setup/tests/tmux-pane-attention.test.sh`

**Interfaces:**
- Consumes: the completed focus semantics and native pane styles from Tasks 1 and 2.
- Produces: a verified branch ready for review; no new runtime interface.

- [ ] **Step 1: Run the complete setup test suite**

Run:

```bash
for test_file in setup/tests/*.test.sh
  bash "$test_file"; or exit 1
end
```

Expected: every test script exits `0`.

- [ ] **Step 2: Inspect the final diff for scope and secrets**

Run:

```bash
git diff HEAD~2 --check
git diff HEAD~2 -- home/.tmux.conf home/.local/libexec/tmux-pane-attention setup/tests/tmux-pane-attention.test.sh
```

Expected: no whitespace errors, no unrelated changes, and no private or company-internal content.

- [ ] **Step 3: Confirm the worktree is clean**

Run:

```bash
git status --short
```

Expected: no output.
