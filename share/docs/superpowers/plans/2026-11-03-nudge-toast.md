# Nudge Canvas toast implementation plan

> Execution: inline, test-first; no automatic commit or Hammerspoon reload.

## Approved design

Reference: `share/nudge/toast-preview.html` (Pelagic, combined severity treatment).
360×164pt cards (width shrinks on narrow screens), 2pt severity border,
14% severity-tinted header through title, source and subtitle in metadata row.
Title up to two lines; body up to three lines with reserved empty space.
Three seconds per new/replaced event, at most three cards globally; oldest
visible card is discarded, not queued. No time label, sound, actions, history,
Notification Center, focus activation, or automatic replay.

## Architecture and invariants

- Keep core/CLI/storage contracts and durable TTL/dedupe unchanged.
- `renderers/toast.lua`: injected clocks/backend/timer; transient deadlines,
  bounded visible set, state restoration without replay, teardown and diagnostics.
- `renderers/canvas.lua`: Hammerspoon screen/session watchers, passive canvases,
  fixed geometry and measured UTF-8 plain-text fitting; no storage or IPC.
- `renderers/text.lua`: pure text wrapping with injected width measurement.
- Shared generated `lib/theme.lua` supplies semantic colors. Extend its generator,
  not a second hand-maintained palette.
- Existing renderer methods remain restore/upsert/remove/count. Optional status
  and stop methods expose displayed_count, per-ID presentation and cleanup.
- First restore seeds the seen state without showing cards. Recovery reconciles
  existing pending cards against committed records without resetting deadlines;
  events in the recovering transaction must still be delivered after restore.
- Lock/sleep/screensaver/inactive session clear visible cards and consume new
  events silently. Returning never replays them. Monitor removal drops cards;
  remaining cards stay on their original monitor and are relaid out.
- Async drawing faults are sanitized, reported by doctor and retried without
  extending deadlines. Save failure never displays an uncommitted send.
- `presented` reports submitted visible canvas state, not proof of human attention.
  `doctor` separates stored active count and transient displayed_count.

## Tasks and verification

- [x] Add failing pure tests for three-second boundaries, replacement, suppression,
  restoration, overflow, short TTL, sleep/wake, monitor changes, failed drawing,
  teardown, unicode text fitting and fixed geometry.
- [x] Implement pure presentation/text modules; run `lua setup/tests/nudge-toast.test.lua`.
- [x] Implement Canvas adapter and extend generated theme. Use fake hs primitives
  to verify frames, palette, clipping, passive window behavior and watcher cleanup.
- [x] Extend service tests for canvas reporting, save ordering, dirty recovery,
  stopped-service behavior and shutdown; integrate default canvas renderer.
- [x] Run all `setup/tests/nudge-*.test.lua`, `bash setup/tests/nudge-cli.test.sh`,
  `fish setup/check.fish`; inspect diffs and review failure paths inline.
- [x] With approval: Stow dry-run/apply, reload, send only uniquely keyed `test`
  alerts, verify 3-second disappearance + persistent state, dedupe/update/dismiss,
  no reload replay and focus preservation. Remove only our test IDs.

## Rollout / fallback

No change to ~/.nudge/config.json or active snapshot format. Existing alerts stay
stored but do not replay. Debug renderer remains available as an injected backend
for tests and troubleshooting. If live Canvas setup fails, retain persisted state
and expose the rendering error; do not silently report successful presentation.
Multi-monitor/fullscreen/lock behavior requires a real desktop acceptance check;
unit tests alone cannot certify macOS window ordering or font rasterization.

## Verification result

Implemented and installed locally. Core 239 tests, store 71 tests, service 38 tests,
CLI 17 groups, plus transient lifecycle, measured text, Canvas adapter and startup
isolation tests pass. `fish setup/check.fish` and Stow simulation pass.
Actual Hammerspoon cards were rendered and captured without changing focus.
The live CLI verified create/suppression/update, disappearance after three seconds
while retaining durable state, dismissal, early TTL and reload without replay.
Only the three uniquely generated test IDs were cleaned. Final doctor reports
canvas/applied with zero stored and zero displayed alerts.
Multi-monitor/fullscreen ordering and physical lock/sleep transitions still need
human desktop acceptance; the corresponding state handling is covered by injected
tests.
