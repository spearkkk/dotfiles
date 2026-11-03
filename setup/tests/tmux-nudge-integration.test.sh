#!/bin/bash
# Real, isolated tmux server; fake HOME/Nudge. Never touches user sessions or IPC.
set -euo pipefail
export TEST_REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - <<'PY'
import json, os, pathlib, subprocess, tempfile, time

root = pathlib.Path(os.environ['TEST_REPO_ROOT'])
with tempfile.TemporaryDirectory(prefix='tmux-nudge-live-') as directory:
    home = pathlib.Path(directory)
    socket = home / 'socket'
    log = home / 'deliveries.jsonl'
    helpers = home / '.local/libexec'
    helpers.mkdir(parents=True)
    (helpers / 'tmux-notify-pane-activity').symlink_to(
        root / 'home/.local/libexec/tmux-notify-pane-activity')
    (home / '.local/bin').mkdir()
    nudge = home / '.local/bin/nudge'
    nudge.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
with (pathlib.Path(os.environ['HOME']) / 'deliveries.jsonl').open('a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
''')
    nudge.chmod(0o755)
    env = dict(os.environ, HOME=str(home))
    env.pop('TMUX', None)
    env.pop('TMUX_PANE', None)

    def tmux(*args):
        return subprocess.check_output(
            ['tmux', '-S', str(socket), *args], env=env, text=True, timeout=5).strip()

    def records():
        return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

    def wait_count(count):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if len(records()) == count:
                return
            time.sleep(.05)
        raise AssertionError('background worker did not deliver: ' + repr(records()))

    try:
        pane = tmux('-f', '/dev/null', 'new-session', '-d', '-P', '-F', '#{pane_id}',
                    '-s', 'nudge-isolated', 'sleep 60')
        controller_env = dict(env, TMUX=str(socket) + ',0,0', TMUX_PANE=pane)

        def reconcile(operation):
            subprocess.run([str(root / 'home/.local/libexec/tmux-reconcile-pane-activity'),
                            operation, pane], env=controller_env, check=True, timeout=5)

        reconcile('command-done')
        wait_count(1)
        first = records()[0]
        assert dict(zip(first[1::2], first[2::2]))['--severity'] == 'info'
        token = tmux('show-options', '-pqv', '-t', pane, '@activity_nudge_token')
        assert token.startswith('claimed:'), token
        reconcile('command-done')
        subprocess.run([str(helpers / 'tmux-notify-pane-activity'), pane, 'completed',
                        token.removeprefix('claimed:')], env=controller_env, check=True, timeout=5)
        assert len(records()) == 1

        tmux('select-pane', '-t', pane, '-T', 'Action Required | private title')
        reconcile('reconcile-title')
        wait_count(2)
        second = records()[1]
        fields = dict(zip(second[1::2], second[2::2]))
        assert fields['--severity'] == 'warning' and fields['--subtitle'] == 'nudge-isolated'
        assert 'private title' not in str(records())
        # A fresh lock acquisition proves neither controller nor worker leaked it.
        tmux('wait-for', '-L', 'tmux-pane-activity-lock')
        tmux('wait-for', '-U', 'tmux-pane-activity-lock')
        print('PASS: real tmux background dispatch, socket inheritance, once-only delivery, lock release')
    finally:
        if socket.exists():
            subprocess.run(['tmux', '-S', str(socket), 'kill-server'], env=env,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
PY
