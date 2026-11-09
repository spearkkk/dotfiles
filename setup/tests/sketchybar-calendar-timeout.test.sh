#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" "$@" <<'PY'
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(sys.argv.pop(1))
TIMEOUT = shutil.which('uu-timeout')
assert TIMEOUT, 'uu-timeout is required (brew install uutils-coreutils)'
DAEMON = ROOT / 'home/.local/libexec/sketchybar-run-calendar-daemon'


class CalendarTimeoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='calendar-timeout-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin, self.home = self.root / 'bin', self.root / 'home'
        self.cache = self.root / 'cache/sketchybar'
        for path in (self.bin, self.home, self.cache):
            path.mkdir(parents=True)
        self.pid = self.root / 'query.pid'
        self.ready = self.root / 'ready'
        self.output = self.cache / 'calendar.tsv'
        (self.root / 'clock').write_text('1700000000\n')
        self.env = {
            'HOME': str(self.home), 'XDG_CACHE_HOME': str(self.cache.parent),
            'PATH': f'{self.bin}:/usr/bin:/bin', 'LC_ALL': 'C',
            'FIXTURE_ROOT': str(self.root),
        }
        (self.bin / 'uu-timeout').symlink_to(TIMEOUT)
        self.script('sketchybar', 'exit 0')
        self.script('sleep', 'touch "$FIXTURE_ROOT/ready"\nexec /bin/sleep 0.05')
        self.script('date', '''case "$1" in
  +%H) echo 10 ;;
  +%M) echo 00 ;;
  +%s) cat "$FIXTURE_ROOT/clock" ;;
  *) exit 99 ;;
esac''')
        self.log = (self.root / 'daemon.log').open('w+')
        self.addCleanup(self.log.close)

    def script(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)

    def hanging_query(self):
        self.script('icalBuddy', '''
if [ -f "$FIXTURE_ROOT/queried" ]; then
  printf '14:00 - 15:00\\tRecovered (Test)\\n'
  exit 0
fi
touch "$FIXTURE_ROOT/queried"
printf '%s\\n' "$$" > "$FIXTURE_ROOT/query.pid"
printf '10:00 - 12:00\\tPartial (Test)\\n'
trap '' TERM
exec /bin/sleep 30
''')

    def start(self):
        self.process = subprocess.Popen(
            ['/bin/bash', str(DAEMON)], env=self.env,
            stdout=self.log, stderr=self.log, start_new_session=True,
        )
        self.addCleanup(self.stop)
        return self.process

    def stop(self):
        # Clean only fixture PIDs. timeout uses a separate process group, so a
        # failed assertion must also release the synthetic query explicitly.
        if self.process.poll() is None:
            if self.pid.exists():
                try:
                    os.kill(int(self.pid.read_text()), signal.SIGKILL)
                except ProcessLookupError:
                    pass
            try:
                os.killpg(self.process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        self.process.wait(timeout=3)

    def wait_for(self, predicate, message, timeout=9):
        deadline = time.monotonic() + timeout
        while not predicate() and self.process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        self.log.seek(0)
        self.assertTrue(predicate(), message + '\n' + self.log.read())

    def assert_query_stopped(self):
        with self.assertRaises(ProcessLookupError, msg='timed-out query was left running'):
            os.kill(int(self.pid.read_text()), 0)

    def scripted_query(self, mode='good'):
        # Advance time only at the query boundary, never halfway through the
        # previous cache publication. No real calendar or 180-second wait.
        (self.root / 'query').write_text(f'1700000000 {mode}\n')
        self.script('icalBuddy', '''
read -r now mode < "$FIXTURE_ROOT/query"
printf '%s\\n' "$now" > "$FIXTURE_ROOT/clock"
case "$mode" in
  good) printf '10:00 - 12:00\\tLast good (Test)\\n' ;;
  recovered) printf '14:00 - 15:00\\tRecovered (Test)\\n' ;;
  failed)
    printf '10:00 - 12:00\\tPartial (Test)\\n'
    exit 1 ;;
  *) exit 99 ;;
esac
''')

    def assert_cache(self, timestamp, rows):
        self.wait_for(
            lambda: self.output.exists() and self.output.read_text().startswith(f'{timestamp}\t'),
            'daemon did not publish the requested clock tick', timeout=5,
        )
        active = 'true' if rows else 'false'
        self.assertEqual(self.output.read_text(), f'{timestamp}\t{active}\n{rows}\n')

    def refresh_at(self, timestamp, mode, rows):
        # Atomic replacement prevents the collector from seeing a partial plan.
        plan = self.root / 'query.next'
        plan.write_text(f'{timestamp} {mode}\n')
        plan.replace(self.root / 'query')
        (self.cache / 'calendar.refresh').touch()
        self.assert_cache(timestamp, rows)

    def test_repeated_failures_do_not_extend_last_good_cache_grace(self):
        self.scripted_query()
        self.start()
        row = '10:00\t12:00\tLast good\tTest'
        self.assert_cache(1700000000, row)
        for timestamp, expected in (
            (1700000179, row),
            (1700000180, row),  # Inclusive grace boundary.
            (1700000181, ''),
            (1700000240, ''),  # Further failures must not resurrect stale rows.
        ):
            with self.subTest(timestamp=timestamp):
                self.refresh_at(timestamp, 'failed', expected)

    def test_success_after_expiry_starts_a_new_cache_grace(self):
        self.scripted_query()
        self.start()
        self.assert_cache(1700000000, '10:00\t12:00\tLast good\tTest')
        self.refresh_at(1700000181, 'failed', '')
        recovered = '14:00\t15:00\tRecovered\tTest'
        self.refresh_at(1700000200, 'recovered', recovered)
        self.refresh_at(1700000379, 'failed', recovered)
        self.refresh_at(1700000380, 'failed', recovered)
        self.refresh_at(1700000381, 'failed', '')

    def test_seeded_cache_expires_during_continuous_failures(self):
        row = '10:00\t12:00\tLast good\tTest'
        self.output.write_text(f'1700000000\ttrue\n{row}\n')
        self.scripted_query(mode='failed')
        self.start()
        # The initial file is already present: wait for the first polling sleep
        # before advancing the clock so startup has actually read the seed.
        self.wait_for(self.ready.exists, 'daemon did not publish seeded cache', timeout=5)
        self.assert_cache(1700000000, row)
        self.refresh_at(1700000179, 'failed', row)
        self.refresh_at(1700000180, 'failed', row)
        self.refresh_at(1700000181, 'failed', '')

    def test_timeout_discards_partial_output_and_recovers_on_refresh(self):
        self.output.write_text('1700000000\ttrue\n10:00\t11:00\tLast good\tTest\n')
        self.hanging_query()
        process = self.start()
        self.wait_for(self.ready.exists, 'hung query prevented cache publication')
        self.assert_query_stopped()
        self.assertEqual(self.output.read_text(), '1700000000\ttrue\n10:00\t11:00\tLast good\tTest\n')
        (self.cache / 'calendar.refresh').touch()
        self.wait_for(lambda: 'Recovered' in self.output.read_text(), 'next query did not recover', timeout=5)
        self.assertNotIn('Partial', self.output.read_text())
        process.send_signal(signal.SIGTERM)
        self.assertEqual(process.wait(timeout=3), 143)
        self.log.seek(0)
        diagnostic = self.log.read()
        self.assertIn('calendar query failed', diagnostic)
        self.assertNotIn('Partial', diagnostic, 'diagnostics must not expose event content')

    def test_failed_query_without_cache_does_not_publish_partial_events(self):
        self.script('icalBuddy', "printf '10:00 - 12:00\\tPartial (Test)\\n'\nexit 1")
        self.start()
        self.wait_for(self.ready.exists, 'failed query prevented cache publication', timeout=5)
        self.assertEqual(self.output.read_text(), '1700000000\tfalse\n\n')

    def test_missing_timeout_tool_never_runs_an_unbounded_query(self):
        (self.bin / 'uu-timeout').unlink()
        self.script('icalBuddy', 'touch "$FIXTURE_ROOT/queried"\nexit 0')
        self.start()
        self.wait_for(self.ready.exists, 'missing timeout tool prevented failure fallback', timeout=5)
        self.assertFalse((self.root / 'queried').exists(), 'query must not run without timeout protection')
        self.assertEqual(self.output.read_text(), '1700000000\tfalse\n\n')

    def test_sigterm_during_hung_query_exits_within_timeout_budget(self):
        self.check_signal(signal.SIGTERM)

    def test_sigint_during_hung_query_exits_within_timeout_budget(self):
        self.check_signal(signal.SIGINT)

    def check_signal(self, sig):
        self.hanging_query()
        process = self.start()
        self.wait_for(lambda: self.pid.exists() and self.pid.stat().st_size > 0, 'query did not start', timeout=5)
        process.send_signal(sig)
        try:
            code = process.wait(timeout=9)
        except subprocess.TimeoutExpired:
            self.fail('daemon did not exit within the bounded query budget')
        self.assertEqual(code, 128 + sig)
        self.assertFalse((self.cache / 'calendar.pid').exists())
        self.assert_query_stopped()


unittest.main(verbosity=2)
PY
