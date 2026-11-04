#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
import os
import plistlib
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
cases = [
    ('home/.tmux/scripts/status-box.sh', 'tmux-render-status-box', '/bin/sh'),
    ('home/.config/sketchybar/daemons/calendar.sh',
     'sketchybar-run-calendar-daemon', '/bin/bash'),
    ('home/.config/sketchybar/daemons/media.sh',
     'sketchybar-run-media-daemon', '/bin/bash'),
]
for old, name, shell in cases:
    path = root / 'home/.local/libexec' / name
    assert path.is_file(), f'missing helper: {name}'
    assert os.access(path, os.X_OK), f'not executable: {name}'
    assert not os.path.lexists(root / old), f'legacy entry remains: {old}'
    subprocess.run([shell, '-n', str(path)], check=True)

for kind in ('calendar', 'media'):
    label = f'dev.spearkkk.sketchybar.{kind}-daemon'
    path = root / 'setup/launchagents/plists' / f'{label}.plist'
    with path.open('rb') as stream:
        plist = plistlib.load(stream)
    assert plist['Label'] == label
    assert plist['ProgramArguments'] == [
        '/bin/bash', '-lc',
        f'exec ~/.local/libexec/sketchybar-run-{kind}-daemon',
    ]
    assert plist['KeepAlive'] is True
    assert plist['RunAtLoad'] is True
    assert plist['EnvironmentVariables']['PATH'] == (
        '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
    )
    assert plist['StandardOutPath'] == f'/tmp/{label}.log'
    assert plist['StandardErrorPath'] == f'/tmp/{label}.err.log'
print('PASS: libexec-layout')
PY
