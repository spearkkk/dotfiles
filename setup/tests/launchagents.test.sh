#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" "$@" <<'PY'
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(sys.argv.pop(1))
LABELS = [f'dev.spearkkk.sketchybar.{kind}-daemon' for kind in ('media', 'calendar')]
FISH = shutil.which('fish')
JQ = shutil.which('jq')
TIMEOUT = shutil.which('uu-timeout')
assert FISH and JQ and TIMEOUT, 'fish, jq and uu-timeout are required'


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-launchagents-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.home = self.root / 'home'
        self.home.mkdir()
        self.cache = self.root / 'cache' / 'sketchybar'
        self.cache.mkdir(parents=True)
        self.state = self.root / 'launchctl.json'
        self.state.write_text(json.dumps({'loaded': [], 'disabled': [], 'calls': []}))
        dead = subprocess.Popen(['/usr/bin/true'])
        dead.wait()
        self.dead_pid = str(dead.pid)
        self.env = {
            'PATH': f'{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin',
            'HOME': str(self.home),
            'XDG_CONFIG_HOME': str(self.home / '.config'),
            'XDG_CACHE_HOME': str(self.cache.parent),
            'STATE': str(self.state),
            'DEAD_PID': self.dead_pid,
            'READY': str(self.root / 'ready'),
        }
        self.script('fish', f'exec {shlex.quote(FISH)} --no-config "$@"')
        self.script('uname', 'echo Darwin')
        self.script('sleep', 'touch "$READY"\nexec /bin/sleep 0.05')
        self.script('sketchybar', 'exit 0')
        self.script('icalBuddy', 'exit 0')
        self.script('nowplaying-cli', '''printf '%s\\n' '{"title":"Fixture","artist":"Test","playbackRate":0}' ''')
        (self.bin / 'jq').symlink_to(JQ)
        (self.bin / 'uu-timeout').symlink_to(TIMEOUT)
        mock = self.bin / 'launchctl'
        mock.write_text(f'#!{sys.executable}\n' + '''
import json
import os
from pathlib import Path
import sys

path = Path(os.environ['STATE'])
state = json.loads(path.read_text())
action, target = sys.argv[1:3]
label = target.split('/')[-1]
if action == 'bootstrap':
    label = Path(sys.argv[3]).stem
state['calls'].append(sys.argv[1:])
code = 0
if action in ('bootout', 'remove'):
    if os.environ.get('FAIL_BOOTOUT') == label:
        code = 5
    elif label in state['loaded'] and not os.environ.get('STUCK'):
        state['loaded'].remove(label)
        if os.environ.get('REPLACE_PID'):
            Path(os.environ['REPLACE_PID']).write_text(str(os.getppid()))
elif action == 'disable':
    if os.environ.get('FAIL_DISABLE') == label:
        code = 1
    elif label not in state['disabled']:
        state['disabled'].append(label)
elif action == 'enable':
    if os.environ.get('FAIL_ENABLE') == label:
        code = 1
    elif label in state['disabled']:
        state['disabled'].remove(label)
elif action == 'bootstrap':
    if label in state['disabled'] or label in state['loaded']:
        code = 1
    else:
        state['loaded'].append(label)
elif action == 'print':
    if os.environ.get('FAIL_PRINT') == label:
        print('Permission denied', file=sys.stderr)
        code = 1
    elif label not in state['loaded']:
        print(f'Could not find service "{label}"', file=sys.stderr)
        code = 113
    else:
        job = state.get('jobs', {}).get(label, {})
        print(target + ' = {')
        polls = state.setdefault('polls', {}).get(label, 0)
        state['polls'][label] = polls + 1
        starting = polls < int(os.environ.get('STARTUP_DELAY', '0'))
        print('\\tstate = ' + ('spawn scheduled' if starting else job.get('state', 'running')))
        if job.get('pid', os.environ['DEAD_PID']) is not None:
            print('\\tpid = ' + str(job.get('pid', os.environ['DEAD_PID'])))
        print('\\tlast exit code = ' + str(job.get('exit', 0)))
        print('\\tresource coalition = {\\n\\t\\tstate = active\\n\\t}')
        print('}')
elif action == 'kickstart':
    code = int(label not in state['loaded'])
else:
    raise SystemExit('Unexpected launchctl action: ' + action)
path.write_text(json.dumps(state))
sys.exit(code)
''')
        mock.chmod(0o755)
        plists = self.home / 'Library' / 'LaunchAgents'
        plists.mkdir(parents=True)
        for label in LABELS:
            shutil.copy(ROOT / 'setup/launchagents/plists' / f'{label}.plist', plists)

    def script(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)

    def run_lifecycle(self, name):
        return subprocess.run(
            [FISH, '--no-config', str(ROOT / 'setup/launchagents' / f'{name}.fish')],
            env=self.env, capture_output=True, text=True, timeout=30,
        )

    def loaded_jobs(self, jobs=None):
        self.state.write_text(json.dumps({
            'loaded': LABELS, 'disabled': [], 'calls': [], 'jobs': jobs or {},
        }))

    def test_status_reports_running_pid_and_loaded_waiting(self):
        self.loaded_jobs({LABELS[0]: {'pid': 12345},
                          LABELS[1]: {'state': 'waiting', 'pid': None, 'exit': 7}})
        result = self.run_lifecycle('status')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('running: ' + LABELS[0] + ' (pid=12345)', result.stdout)
        self.assertIn('loaded: ' + LABELS[1], result.stdout)
        self.assertIn('state=waiting', result.stdout)
        self.assertIn('last_exit=7', result.stdout)
        self.assertNotIn('state=active', result.stdout)

    def test_status_requires_pid_for_running(self):
        self.loaded_jobs({LABELS[0]: {'pid': None}})
        result = self.run_lifecycle('status')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('loaded: ' + LABELS[0], result.stdout)

    def test_status_distinguishes_lookup_error_from_stopped(self):
        self.env['FAIL_PRINT'] = LABELS[0]
        result = self.run_lifecycle('status')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unknown: ' + LABELS[0], result.stdout)
        self.assertIn('Permission denied', result.stderr)
        self.assertIn('stopped: ' + LABELS[1], result.stdout)
        self.assertNotIn('stopped: ' + LABELS[0], result.stdout)

    def test_teardown_repeats_and_removes_stale_pid(self):
        pid = self.cache / 'media.pid'
        pid.write_text(self.dead_pid + '\n')
        for _ in range(2):
            result = self.run_lifecycle('teardown')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(pid.exists())

    def test_teardown_preserves_pid_on_control_errors(self):
        for failure in ('FAIL_DISABLE', 'FAIL_BOOTOUT', 'FAIL_PRINT', 'STUCK'):
            with self.subTest(failure=failure):
                self.loaded_jobs()
                self.env[failure] = LABELS[0]
                pid = self.cache / 'media.pid'
                pid.write_text(self.dead_pid + '\n')
                result = self.run_lifecycle('teardown')
                self.env.pop(failure)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertTrue(pid.exists(), 'failed teardown discarded PID file')
                self.assertIn(LABELS[0], result.stderr)

    def test_teardown_preserves_live_pid_even_when_job_absent(self):
        # The test runner is a known-live unrelated process: never signal it.
        pid = self.cache / 'media.pid'
        pid.write_text(f'{os.getpid()}\n')
        result = self.run_lifecycle('teardown')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(pid.read_text().strip(), str(os.getpid()))

    def test_teardown_waits_for_launchd_pid_without_pid_file(self):
        self.loaded_jobs({LABELS[0]: {'pid': os.getpid()}})
        result = self.run_lifecycle('teardown')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Timed out', result.stderr)

    def test_teardown_waits_for_process_exit_before_cleanup(self):
        process = subprocess.Popen(['/bin/sleep', '1'], start_new_session=True)
        self.addCleanup(self.stop_fixture, process)
        pid = self.cache / 'media.pid'
        pid.write_text(f'{process.pid}\n')
        # Reap independently so ps cannot see a zombie after sleep exits.
        import threading
        reaper = threading.Thread(target=process.wait)
        reaper.start()
        self.addCleanup(reaper.join)
        result = self.run_lifecycle('teardown')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNotNone(process.poll(), 'teardown returned before process exit')
        self.assertFalse(pid.exists())

    def test_teardown_preserves_malformed_pid(self):
        pid = self.cache / 'media.pid'
        pid.write_text('not-a-pid\n')
        result = self.run_lifecycle('teardown')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(pid.read_text(), 'not-a-pid\n')

    def test_teardown_preserves_replaced_pid_file(self):
        self.loaded_jobs()
        pid = self.cache / 'media.pid'
        pid.write_text(self.dead_pid + '\n')
        self.env['REPLACE_PID'] = str(pid)
        result = self.run_lifecycle('teardown')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(pid.exists())
        self.assertNotEqual(pid.read_text().strip(), self.dead_pid)

    def test_teardown_fails_closed_on_process_probe_error(self):
        self.script('ps', 'echo "Operation not permitted" >&2; exit 1')
        pid = self.cache / 'media.pid'
        pid.write_text(self.dead_pid + '\n')
        result = self.run_lifecycle('teardown')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(pid.exists())
        self.assertIn('Operation not permitted', result.stderr)

    def test_bootstrap_waits_for_running_state(self):
        self.env['STARTUP_DELAY'] = '2'
        result = self.run_lifecycle('bootstrap')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('running: ' + LABELS[0], result.stdout)
        self.assertIn('running: ' + LABELS[1], result.stdout)

    def test_bootstrap_recovers_after_teardown(self):
        self.assertEqual(self.run_lifecycle('teardown').returncode, 0)
        self.assertCountEqual(json.loads(self.state.read_text())['disabled'], LABELS)
        result = self.run_lifecycle('bootstrap')
        self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads(self.state.read_text())
        self.assertCountEqual(state['loaded'], LABELS)
        self.assertEqual(state['disabled'], [])

    def test_bootstrap_can_repeat(self):
        for _ in range(2):
            result = self.run_lifecycle('bootstrap')
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertCountEqual(json.loads(self.state.read_text())['loaded'], LABELS)

    def test_enable_failure_prevents_bootstrap(self):
        self.env['FAIL_ENABLE'] = LABELS[1]
        result = self.run_lifecycle('bootstrap')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Failed to enable ' + LABELS[1], result.stderr)
        calls = json.loads(self.state.read_text())['calls']
        self.assertFalse(any(call[0] in ('bootstrap', 'kickstart') for call in calls))

    def test_missing_plist_leaves_services_alone(self):
        (self.home / 'Library/LaunchAgents' / f'{LABELS[1]}.plist').unlink()
        result = self.run_lifecycle('bootstrap')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('plist is missing', result.stderr)
        self.assertEqual(json.loads(self.state.read_text())['calls'], [])

    def test_unload_timeout_preserves_pid_and_prevents_startup(self):
        self.state.write_text(json.dumps({'loaded': LABELS, 'disabled': [], 'calls': []}))
        self.env['STUCK'] = '1'
        pid = self.cache / 'media.pid'
        pid.write_text('fixture-owner\n')
        result = self.run_lifecycle('bootstrap')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Timed out while unloading', result.stderr)
        self.assertEqual(pid.read_text(), 'fixture-owner\n')
        calls = json.loads(self.state.read_text())['calls']
        self.assertFalse(any(call[0] in ('enable', 'bootstrap', 'kickstart') for call in calls))

    def stop_fixture(self, process):
        # Only signal the isolated fixture process group, never a real daemon.
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait(timeout=5)

    def start_daemon(self, kind):
        ready = Path(self.env['READY'])
        ready.unlink(missing_ok=True)
        log = (self.root / f'{kind}.log').open('w+')
        self.addCleanup(log.close)
        process = subprocess.Popen(
            ['/bin/bash', str(ROOT / 'home/.local/libexec' / f'sketchybar-run-{kind}-daemon')],
            env=self.env, stdout=log, stderr=log, start_new_session=True,
        )
        self.addCleanup(self.stop_fixture, process)
        deadline = time.monotonic() + 5
        while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        log.seek(0)
        self.assertIsNone(process.poll(), log.read())
        self.assertTrue(ready.exists(), 'daemon did not reach its polling loop')
        pid = self.cache / f'{kind}.pid'
        self.assertEqual(pid.read_text().strip(), str(process.pid))
        return process, pid

    def test_signals_exit_and_remove_owned_pid(self):
        for kind in ('media', 'calendar'):
            for sig in (signal.SIGTERM, signal.SIGINT):
                with self.subTest(kind=kind, signal=sig):
                    process, pid = self.start_daemon(kind)
                    try:
                        process.send_signal(sig)
                        try:
                            code = process.wait(timeout=3)
                        except subprocess.TimeoutExpired:
                            self.fail('daemon remained alive after ' + sig.name)
                        self.assertEqual(code, 128 + sig)
                        self.assertFalse(pid.exists(), 'owned PID file was not removed')
                    finally:
                        self.stop_fixture(process)

    def test_exit_preserves_another_owners_pid(self):
        for kind in ('media', 'calendar'):
            with self.subTest(kind=kind):
                process, pid = self.start_daemon(kind)
                pid.write_text('another-owner\n')
                process.send_signal(signal.SIGTERM)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.fail('daemon remained alive after SIGTERM')
                self.assertEqual(pid.read_text(), 'another-owner\n')

    def test_duplicate_daemon_preserves_live_owner(self):
        for kind in ('media', 'calendar'):
            with self.subTest(kind=kind):
                owner = self.cache / f'{kind}.pid'
                owner.write_text(f'{os.getpid()}\n')
                result = subprocess.run(
                    ['/bin/bash', str(ROOT / 'home/.local/libexec' / f'sketchybar-run-{kind}-daemon')],
                    env=self.env, capture_output=True, text=True, timeout=5,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(owner.read_text(), f'{os.getpid()}\n')


unittest.main(verbosity=2)
PY
