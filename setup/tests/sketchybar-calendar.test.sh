#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(sys.argv.pop(1))
DAEMON = ROOT / 'home/.local/libexec/sketchybar-run-calendar-daemon'


class CalendarTests(unittest.TestCase):
    def collect(self, rows):
        # Execute the real daemon and read its public cache format. Only the
        # calendar/SketchyBar boundaries, clock and polling delay are synthetic.
        with tempfile.TemporaryDirectory(prefix='sketchybar-calendar-') as tmp:
            root = Path(tmp)
            home, bin_dir, cache = root / 'home', root / 'bin', root / 'cache'
            home.mkdir()
            bin_dir.mkdir()
            fixture, ready = root / 'events.tsv', root / 'ready'
            fixture.write_text('\n'.join(rows) + '\n')
            scripts = {
                'icalBuddy': 'exec /bin/cat "$FIXTURE"',
                'sketchybar': 'exit 0',
                'sleep': 'touch "$READY"\nexec /bin/sleep 0.05',
                'date': '''case "$1" in
  +%H) echo 10 ;;
  +%M) echo 00 ;;
  +%s) echo 1700000000 ;;
  *) exit 99 ;;
esac''',
            }
            for name, body in scripts.items():
                path = bin_dir / name
                path.write_text('#!/bin/sh\n' + body + '\n')
                path.chmod(0o755)
            env = {
                'HOME': str(home), 'XDG_CACHE_HOME': str(cache), 'LC_ALL': 'C',
                'PATH': f'{bin_dir}:/usr/bin:/bin',
                'FIXTURE': str(fixture), 'READY': str(ready),
            }
            with (root / 'daemon.log').open('w+') as log:
                process = subprocess.Popen(
                    ['/bin/bash', str(DAEMON)], env=env, stdout=log, stderr=log,
                    start_new_session=True,
                )
                try:
                    deadline = time.monotonic() + 5
                    while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.02)
                    log.seek(0)
                    self.assertIsNone(process.poll(), log.read())
                    self.assertTrue(ready.exists(), 'daemon did not publish its first cache')
                    lines = (cache / 'sketchybar/calendar.tsv').read_text().splitlines()
                    process.send_signal(signal.SIGTERM)
                    self.assertEqual(process.wait(timeout=3), 143)
                    log.seek(0)
                    self.assertEqual(log.read(), '', 'unexpected daemon diagnostic')
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=3)
            header = lines[0].split('\t')
            self.assertEqual(header[0], '1700000000')
            self.assertIn(header[1], ('true', 'false'))
            return header[1], [line for line in lines[1:] if line]

    def test_same_title_with_different_start_is_preserved(self):
        _, rows = self.collect([
            '11:00 - 12:00\tReview (Test)',
            '10:00 - 12:00\tReview (Test)',
        ])
        self.assertEqual(rows, [
            '10:00\t12:00\tReview\tTest',
            '11:00\t12:00\tReview\tTest',
        ])

    def test_same_title_with_different_end_is_preserved(self):
        _, rows = self.collect([
            '10:00 - 12:00\tReview (Test)',
            '10:00 - 11:00\tReview (Test)',
        ])
        self.assertCountEqual(rows, [
            '10:00\t11:00\tReview\tTest',
            '10:00\t12:00\tReview\tTest',
        ])

    def test_same_title_in_different_calendars_is_preserved(self):
        _, rows = self.collect([
            '10:00 - 11:00\tReview (Calendar B)',
            '10:00 - 11:00\tReview (Calendar A)',
        ])
        self.assertCountEqual(rows, [
            '10:00\t11:00\tReview\tCalendar A',
            '10:00\t11:00\tReview\tCalendar B',
        ])

    def test_same_time_with_different_title_is_preserved(self):
        _, rows = self.collect([
            '10:00 - 11:00\tBeta (Test)',
            '10:00 - 11:00\tAlpha (Test)',
        ])
        self.assertEqual(rows, [
            '10:00\t11:00\tAlpha\tTest',
            '10:00\t11:00\tBeta\tTest',
        ])

    def test_only_exact_normalized_duplicates_are_removed(self):
        _, rows = self.collect([
            '9:05 - 10:00\t  팀   회의 (Test (Shared))  ',
            '09:05 - 10:00\t팀 회의 (Test (Shared))',
            '14:00 - 15:00\t팀 회의 (Test (Shared))',
            '9:05 - 10:00\t팀 회의 (Test (Shared))',
        ])
        self.assertEqual(rows, [
            '09:05\t10:00\t팀 회의\tTest (Shared)',
            '14:00\t15:00\t팀 회의\tTest (Shared)',
        ])

    def test_events_without_calendar_keep_distinct_times(self):
        _, rows = self.collect([
            '10:00 - 11:00\tReview',
            '10:00 - 11:00\tReview',
            '14:00 - 15:00\tReview',
        ])
        self.assertEqual(rows, ['10:00\t11:00\tReview\t', '14:00\t15:00\tReview\t'])

    def test_ended_event_does_not_hide_next_same_title_event(self):
        active, rows = self.collect([
            '09:00 - 09:30\tReview (Test)',
            '14:00 - 15:00\tReview (Test)',
        ])
        self.assertEqual(active, 'true', 'the widget must still see the upcoming event')
        self.assertEqual(len(rows), 2)

    def test_empty_calendar_keeps_inactive_cache_contract(self):
        active, rows = self.collect([])
        self.assertEqual(active, 'false')
        self.assertEqual(rows, [])


unittest.main(verbosity=2)
PY
