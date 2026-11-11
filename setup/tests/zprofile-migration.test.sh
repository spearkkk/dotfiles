#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(sys.argv.pop())
FISH = shutil.which('fish')


class ZprofileMigration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='zprofile-migration-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / 'home with spaces'
        self.repo = self.base / 'repo'
        self.bin = self.base / 'bin'
        for path in (self.home, self.bin, self.repo / 'setup/launchagents', self.repo / 'home'):
            path.mkdir(parents=True)
        for name in ('bootstrap.fish', 'prepare-zprofile.sh', 'install.sh'):
            source = ROOT / 'setup' / name
            if source.exists():
                shutil.copy(source, self.repo / 'setup' / name)
        shutil.copy(ROOT / 'home/.zprofile', self.repo / 'home/.zprofile')
        (self.repo / 'setup/Brewfile').touch()
        (self.repo / 'setup/launchagents/Makefile').touch()
        for name in ('set-theme.sh', 'set-macos.sh', 'install-sketchybar-lua.sh', 'install-sketchybar-fonts.sh'):
            path = self.repo / 'setup' / name
            path.write_text('#!/bin/sh\nexit 0\n')
            path.chmod(0o700)
        self.stub('brew', 'case "$*" in\n'
                  '  shellenv) exit 0 ;;\n'
                  '  --prefix) printf "%s\\n" "$TEST_PREFIX" ;;\n'
                  '  install*|"bundle install"*) exit 0 ;;\n'
                  '  *) exit 91 ;;\nesac\n')
        self.stub('make', 'exit 0\n')
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        TEST_PREFIX=str(self.base / 'prefix'))

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body)
        path.chmod(0o700)

    def bootstrap(self, success=True):
        result = subprocess.run([FISH, '--no-config', str(self.repo / 'setup/bootstrap.fish')],
                                env=self.env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((self.home / '.zprofile').is_symlink())
            self.assertEqual((self.home / '.zprofile').resolve(), self.repo / 'home/.zprofile')
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def backups(self):
        return list((self.home / '.local/state/dotfiles/backups').glob('zprofile.*/.zprofile'))

    def test_fresh_home_and_repeated_bootstrap(self):
        self.bootstrap()
        self.bootstrap()
        self.assertFalse((self.home / '.zprofile.local').exists())
        self.assertEqual(self.backups(), [])

    def test_bridge_install_failure_stops_before_stow_or_profile_migration(self):
        (self.repo / 'setup/install-sketchybar-lua.sh').write_text(
            '#!/bin/sh\nexit 1\n')
        profile = self.home / '.zprofile'
        profile.write_text('export ORIGINAL=yes\n')
        self.bootstrap(success=False)
        self.assertFalse(profile.is_symlink())
        self.assertEqual(profile.read_text(), 'export ORIGINAL=yes\n')
        self.assertFalse((self.home / '.zprofile.local').exists())

    def test_existing_settings_are_backed_up_and_loaded_from_local(self):
        original = 'export DOTFILES_MIGRATION_TEST="kept value"\n'
        (self.home / '.zprofile').write_text(original)
        self.bootstrap()
        self.assertEqual((self.home / '.zprofile.local').read_text(), original)
        self.assertEqual(len(self.backups()), 1)
        self.assertEqual(self.backups()[0].read_text(), original)
        self.assertEqual(self.backups()[0].parent.stat().st_mode & 0o777, 0o700)
        result = subprocess.run(['/bin/zsh', '-f', '-c',
                                 'source "$HOME/.zprofile"; print -r -- "$DOTFILES_MIGRATION_TEST"'],
                                env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.strip(), 'kept value')
        self.bootstrap()
        self.assertEqual(len(self.backups()), 1)

    def test_old_installer_homebrew_line_is_not_duplicated(self):
        for prefix in ('/opt/homebrew', '/usr/local'):
            with self.subTest(prefix=prefix):
                profile = self.home / '.zprofile'
                if profile.is_symlink():
                    profile.unlink()
                original = 'eval "$(' + prefix + '/bin/brew shellenv)"\n'
                profile.write_text(original)
                self.bootstrap()
                self.assertFalse((self.home / '.zprofile.local').exists())
                self.assertIn(original, [p.read_text() for p in self.backups()])

    def test_existing_local_is_preserved_when_only_homebrew_needs_migration(self):
        (self.home / '.zprofile').write_text('eval "$(/opt/homebrew/bin/brew shellenv)"\n')
        local = self.home / '.zprofile.local'
        local.write_text('export KEEP_LOCAL=yes\n')
        self.bootstrap()
        self.assertEqual(local.read_text(), 'export KEEP_LOCAL=yes\n')

    def test_two_user_files_require_manual_merge_without_modification(self):
        profile = self.home / '.zprofile'
        local = self.home / '.zprofile.local'
        profile.write_text('export ORIGINAL=yes\n')
        local.write_text('export EXISTING_LOCAL=yes\n')
        result = self.bootstrap(success=False)
        self.assertIn('.zprofile.local', result.stdout + result.stderr)
        self.assertFalse(profile.is_symlink())
        self.assertEqual(profile.read_text(), 'export ORIGINAL=yes\n')
        self.assertEqual(local.read_text(), 'export EXISTING_LOCAL=yes\n')

    def test_empty_and_common_profile_copies_do_not_become_local_settings(self):
        profile = self.home / '.zprofile'
        for original in ('', (self.repo / 'home/.zprofile').read_text()):
            with self.subTest(empty=not original):
                if profile.is_symlink():
                    profile.unlink()
                profile.write_text(original)
                self.bootstrap()
                self.assertFalse((self.home / '.zprofile.local').exists())
                self.assertIn(original, [p.read_text() for p in self.backups()])

    def test_local_symlink_is_never_followed_or_replaced(self):
        profile = self.home / '.zprofile'
        profile.write_text('export ORIGINAL=yes\n')
        local = self.home / '.zprofile.local'
        target = self.base / 'missing-local'
        local.symlink_to(target)
        self.bootstrap(success=False)
        self.assertEqual(os.readlink(local), str(target))
        self.assertFalse(target.exists())
        self.assertEqual(profile.read_text(), 'export ORIGINAL=yes\n')

    def test_profile_directory_is_not_moved(self):
        profile = self.home / '.zprofile'
        profile.mkdir()
        (profile / 'keep').write_text('original')
        self.bootstrap(success=False)
        self.assertEqual((profile / 'keep').read_text(), 'original')

    def test_foreign_and_broken_symlinks_are_not_replaced(self):
        target = self.base / 'foreign'
        target.write_text('export FOREIGN=yes\n')
        profile = self.home / '.zprofile'
        for destination in (target, self.base / 'missing'):
            with self.subTest(destination=destination):
                profile.symlink_to(destination)
                self.bootstrap(success=False)
                self.assertEqual(os.readlink(profile), str(destination))
                self.assertEqual(target.read_text(), 'export FOREIGN=yes\n')
                profile.unlink()

    def test_local_source_is_not_migrated_into_recursive_source(self):
        original = 'source "$HOME/.zprofile.local"\nexport CUSTOM=yes\n'
        (self.home / '.zprofile').write_text(original)
        self.bootstrap(success=False)
        self.assertEqual((self.home / '.zprofile').read_text(), original)
        self.assertFalse((self.home / '.zprofile.local').exists())

    def test_install_leaves_zprofile_ownership_to_stow(self):
        prefix = Path(self.env['TEST_PREFIX'])
        (prefix / 'bin').mkdir(parents=True)
        (prefix / 'bin/fish').write_text('#!/bin/sh\nexit 0\n')
        (prefix / 'bin/fish').chmod(0o700)
        self.stub('uname', 'echo Darwin\n')
        self.stub('xcode-select', 'exit 0\n')
        self.stub('dscl', 'printf "UserShell: %s/bin/fish\\n" "$TEST_PREFIX"\n')
        # Never touch /etc/shells: the fixture fish is treated as registered.
        self.stub('grep', 'case "$*" in *"/etc/shells"*) exit 0 ;; esac\nexec /usr/bin/grep "$@"\n')
        self.stub('sudo', 'exit 92\n')
        self.stub('chsh', 'exit 93\n')
        for existing in (False, True):
            with self.subTest(existing=existing):
                profile = self.home / '.zprofile'
                if existing:
                    profile.write_text('export ORIGINAL=yes\n')
                result = subprocess.run(['/bin/bash', str(self.repo / 'setup/install.sh')],
                                        env=self.env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if existing:
                    self.assertEqual(profile.read_text(), 'export ORIGINAL=yes\n')
                else:
                    self.assertFalse(profile.exists(), 'installer must not create .zprofile')


unittest.main()
PY
