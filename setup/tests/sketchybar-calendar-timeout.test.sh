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
  +%s) echo 1700000000 ;;
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
