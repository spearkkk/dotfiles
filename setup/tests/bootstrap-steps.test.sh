#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(sys.argv.pop(1))
FISH = shutil.which('fish')
assert FISH, 'fish is required'
STEPS = ['brew', 'sketchybar-lua', 'theme', 'stow', 'macos', 'launchagents', 'profiles']
DEFAULT_ACTIONS = ['brew', 'sketchybar-lua', 'theme', 'prepare-zprofile', 'stow', 'macos', 'launchagents']


class BootstrapSteps(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bootstrap-steps-')
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.repo, self.home, self.bin = base / 'repo with spaces', base / 'home', base / 'bin'
        self.log = base / 'calls'
        for path in (self.repo / 'setup/launchagents', self.repo / 'home', self.home, self.bin):
            path.mkdir(parents=True)
        shutil.copy(ROOT / 'setup/bootstrap.fish', self.repo / 'setup/bootstrap.fish')
        (self.repo / 'setup/Brewfile').touch()
        (self.repo / 'setup/launchagents/Makefile').touch()
        for profile in ('personal', 'local'):
            (self.repo / 'profiles' / profile).mkdir(parents=True)
        self.env = {
            'HOME': str(self.home), 'PATH': f'{self.bin}:/usr/bin:/bin',
            'XDG_CONFIG_HOME': str(self.home / '.config'), 'CALL_LOG': str(self.log),
        }
        self.stub(self.bin / 'fish', f'exec {shlex.quote(FISH)} --no-config "$@"')
        self.stub(self.bin / 'brew', '''
[ "$HOMEBREW_NO_AUTO_UPDATE" = 1 ] || exit 91
[ "$1 $2 $3" = 'bundle install --file' ] || exit 92
''' + self.record('brew'))
        self.stub(self.bin / 'stow', self.record('stow'))
        self.stub(self.bin / 'make', '''
[ "$1" = -C ] && [ "$3" = bootstrap ] || exit 93
''' + self.record('launchagents'))
        for name, action in (
            ('install-sketchybar-lua.sh', 'sketchybar-lua'),
            ('set-theme.sh', 'theme'), ('set-macos.sh', 'macos'),
            ('prepare-zprofile.sh', 'prepare-zprofile'),
        ):
            self.stub(self.repo / 'setup' / name, self.record(action))
        (self.repo / 'setup/profile.fish').write_text('''
printf 'profile:%s\\n' "$argv[1]" >> "$CALL_LOG"
test "$FAIL_ACTION" != "profile:$argv[1]"
''')

    def record(self, action):
        return f'''printf '%s\\n' '{action}' >> "$CALL_LOG"
[ "${{FAIL_ACTION:-}}" != '{action}' ]
'''

    def stub(self, path, body):
        path.write_text('#!/bin/sh\nset -eu\n' + body + '\n')
        path.chmod(0o755)

    def run_bootstrap(self, *args, status=0):
        self.log.write_text('')
        result = subprocess.run(
            [FISH, '--no-config', str(self.repo / 'setup/bootstrap.fish'), *args],
            env=self.env, cwd='/', text=True, capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode, status, result.stdout + result.stderr)
        return self.log.read_text().splitlines(), result

    def test_default_preserves_full_order(self):
        actions, _ = self.run_bootstrap()
        self.assertEqual(actions, DEFAULT_ACTIONS)

    def test_default_applies_requested_profiles_last(self):
        actions, _ = self.run_bootstrap('--profile', 'personal', '--profile=local')
        self.assertEqual(actions, DEFAULT_ACTIONS + ['profile:personal', 'profile:local'])

    def test_each_step_runs_only_its_own_actions(self):
        for step in STEPS:
            with self.subTest(step=step):
                args = ['--only', step]
                expected = [step]
                if step == 'stow':
                    expected = ['prepare-zprofile', 'stow']
                elif step == 'profiles':
                    args += ['--profile', 'personal']
                    expected = ['profile:personal']
                actions, _ = self.run_bootstrap(*args)
                self.assertEqual(actions, expected)

    def test_selection_is_deduplicated_and_uses_canonical_order(self):
        actions, _ = self.run_bootstrap('--only=stow', '--only', 'theme', '--only', 'stow')
        self.assertEqual(actions, ['theme', 'prepare-zprofile', 'stow'])

    def test_non_brew_step_does_not_require_brewfile_or_call_brew(self):
        (self.repo / 'setup/Brewfile').unlink()
        self.env['FAIL_ACTION'] = 'brew'
        actions, _ = self.run_bootstrap('--only', 'theme')
        self.assertEqual(actions, ['theme'])

    def test_missing_unselected_scripts_are_ignored(self):
        for name in ('set-macos.sh', 'set-theme.sh', 'install-sketchybar-lua.sh'):
            (self.repo / 'setup' / name).unlink()
        (self.repo / 'setup/launchagents/Makefile').unlink()
        actions, _ = self.run_bootstrap('--only', 'stow')
        self.assertEqual(actions, ['prepare-zprofile', 'stow'])

    def test_stow_home_changes_only_happen_in_stow_step(self):
        conf = self.home / '.config/fish/conf.d'
        conf.mkdir(parents=True)
        bootstrap_brew = conf / '0000-bootstrap-homebrew.fish'
        bootstrap_brew.write_text('# Managed by setup/install.sh bootstrap phase.\n')
        (conf / '0000-homebrew.fish').touch()
        (self.home / '.zprofile').write_text('# local settings\n')
        actions, _ = self.run_bootstrap('--only', 'theme')
        self.assertEqual(actions, ['theme'])
        self.assertTrue(bootstrap_brew.exists())
        self.assertEqual((self.home / '.zprofile').read_text(), '# local settings\n')
        actions, _ = self.run_bootstrap('--only', 'stow')
        self.assertEqual(actions, ['prepare-zprofile', 'stow'])
        self.assertFalse(bootstrap_brew.exists())

    def test_invalid_arguments_fail_before_any_actions(self):
        for args in (
            ['--only'], ['--only='], ['--only', 'unknown'], ['--bogus'],
            ['--profile'], ['--profile='], ['--profile', '../personal'],
            ['--profile', 'missing'], ['--only', 'profiles'],
            ['--only', 'theme', '--profile', 'personal'],
        ):
            with self.subTest(args=args):
                actions, _ = self.run_bootstrap(*args, status=2)
                self.assertEqual(actions, [])

    def test_help_and_step_list_have_no_side_effects(self):
        actions, result = self.run_bootstrap('--help')
        self.assertEqual(actions, [])
        self.assertIn('--only', result.stdout)
        actions, result = self.run_bootstrap('--list-steps')
        self.assertEqual(actions, [])
        self.assertEqual(result.stdout.splitlines(), STEPS)

    def test_failure_stops_before_later_selected_steps(self):
        self.env['FAIL_ACTION'] = 'theme'
        actions, _ = self.run_bootstrap('--only', 'theme', '--only', 'stow', status=1)
        self.assertEqual(actions, ['theme'])

    def test_missing_stow_fails_without_running_other_steps(self):
        (self.bin / 'stow').unlink()
        actions, result = self.run_bootstrap('--only', 'stow', status=1)
        self.assertEqual(actions, [])
        self.assertIn('Stow', result.stderr)

    def test_failed_migration_never_runs_stow_or_later_steps(self):
        self.env['FAIL_ACTION'] = 'prepare-zprofile'
        actions, _ = self.run_bootstrap('--only', 'stow', '--only', 'macos', status=1)
        self.assertEqual(actions, ['prepare-zprofile'])


unittest.main(verbosity=2)
PY
