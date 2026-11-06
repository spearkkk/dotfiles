#!/usr/bin/env bash
# Real compilation and Lua loading; only downloads and mise installation are faked.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
lua_bin=${LUA_BIN:-$(mise where lua@5.4)/bin/lua}
python3 - "$repo_root" "$lua_bin" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(sys.argv[1])
LUA = Path(sys.argv[2]).resolve()
del sys.argv[1:]


class BridgeInstaller(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sbar-install-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / 'home with spaces'
        self.setup = self.base / 'repo/setup'
        self.bin = self.base / 'bin'
        for directory in (self.home, self.setup, self.bin):
            directory.mkdir(parents=True)
        for name in ('install-sketchybar-lua.sh', 'check-sketchybar-lua.lua'):
            source = ROOT / 'setup' / name
            if source.exists():
                shutil.copy2(source, self.setup / name)
        self.target = self.home / '.local/share/sketchybar_lua'
        self.module = self.target / 'sketchybar.so'
        self.receipt = self.target / 'install.json'
        self.archive = self.base / 'source.tar.gz'
        self.lock = dict(revision='a' * 40, lua='5.4',
                         url='https://example.invalid/SbarLua/' + 'a' * 40)
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        TEST_BASE=str(self.base), TEST_LUA_DIR=str(LUA.parent.parent))
        self.stub('mise', '''
case "$*" in
  'where lua@5.4')
    if [ "${TEST_MISSING_RUNTIME:-0}" = 1 ] && [ ! -f "$TEST_BASE/runtime-installed" ]; then exit 1; fi
    printf '%s\n' "$TEST_LUA_DIR" ;;
  'install lua@5.4')
    [ "${TEST_RUNTIME_FAILURE:-0}" = 0 ] || exit 1
    touch "$TEST_BASE/runtime-installed" ;;
  *) exit 91 ;;
esac
''')
        self.stub('curl', '''
output=
url=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output|-o) output=$2; shift ;;
    https://*) url=$1 ;;
  esac
  shift
done
[ "$url" = "https://example.invalid/SbarLua/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ] || exit 92
echo download >> "$TEST_BASE/downloads"
[ "${TEST_DOWNLOAD_FAILURE:-0}" = 0 ] || exit 22
cp "$TEST_BASE/source.tar.gz" "$output"
''')
        for name in ('sketchybar', 'open'):
            self.stub(name, 'echo forbidden > "$TEST_BASE/live-call"; exit 93\n')
        self.make_archive()

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\nset -eu\n' + body)
        path.chmod(0o700)

    def make_archive(self, build_failure=False, missing_api=False):
        source = self.base / 'source'
        source.mkdir(exist_ok=True)
        names = ['add', 'remove', 'set', 'bar', 'default', 'animate', 'subscribe',
                 'query', 'event_loop', 'hotload', 'set_bar_name', 'trigger', 'push',
                 'exec', 'delay', 'begin_config', 'end_config']
        if missing_api:
            names.remove('exec')
        functions = ','.join('{"' + name + '", forbidden}' for name in names)
        (source / 'bridge.c').write_text('''
#include <lua.h>
#include <lauxlib.h>
static int forbidden(lua_State *L) { return luaL_error(L, "live API called during validation"); }
static const luaL_Reg functions[] = {''' + functions + ''', {NULL, NULL}};
int luaopen_sketchybar(lua_State *L) { luaL_newlib(L, functions); return 1; }
''')
        recipe = '\tfalse\n' if build_failure else (
            '\tmkdir -p bin\n'
            '\tclang -shared -fPIC -undefined dynamic_lookup $(ARCH) '
            '-I"$(TEST_LUA_DIR)/include" bridge.c -o bin/sketchybar.so\n')
        (source / 'makefile').write_text('bin/sketchybar.so:\n' + recipe + 'install:\n\tfalse\n')
        with tarfile.open(self.archive, 'w:gz') as archive:
            archive.add(source, arcname='SbarLua-fixture')
        self.lock['sha256'] = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.setup / 'sketchybar-lua.lock.json').write_text(json.dumps(self.lock))

    def run_installer(self, *args, success=True):
        result = subprocess.run(['bash', str(self.setup / 'install-sketchybar-lua.sh'), *args],
                                cwd='/', env=self.env, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.base / 'live-call').exists())
        self.assertEqual(list(self.target.glob('.install.*')), [])
        return result

    def seed_old_install(self):
        self.target.mkdir(parents=True)
        self.module.write_bytes(b'previous bridge')
        self.receipt.write_text('{"previous":true}\n')

    def assert_old_install(self):
        self.assertEqual(self.module.read_bytes(), b'previous bridge')
        self.assertEqual(self.receipt.read_text(), '{"previous":true}\n')

    def test_fresh_install_prepares_runtime_builds_and_loads_native_module(self):
        self.env['TEST_MISSING_RUNTIME'] = '1'
        self.run_installer()
        self.assertTrue((self.base / 'runtime-installed').exists())
        self.assertTrue(self.module.is_file())
        self.assertTrue(self.receipt.is_file())
        self.run_installer('--check')

    def test_repeat_run_reuses_valid_binary_without_download_or_build(self):
        self.run_installer()
        before = self.module.stat().st_mtime_ns
        self.env['TEST_DOWNLOAD_FAILURE'] = '1'
        self.run_installer()
        self.assertEqual(self.module.stat().st_mtime_ns, before)
        self.assertEqual((self.base / 'downloads').read_text().splitlines(), ['download'])

    def test_validation_ignores_user_lua_startup_hooks(self):
        self.env['LUA_INIT'] = 'error("user Lua startup must not execute")'
        self.env['LUA_INIT_5_4'] = self.env['LUA_INIT']
        self.run_installer()
        self.run_installer('--check')

    def test_corrupted_installed_binary_is_detected_and_rebuilt(self):
        self.run_installer()
        self.module.write_bytes(b'corrupted')
        self.run_installer('--check', success=False)
        self.run_installer()
        self.run_installer('--check')
        self.assertEqual(len((self.base / 'downloads').read_text().splitlines()), 2)

    def test_multiple_receipt_records_are_not_accepted_as_one_install(self):
        self.run_installer()
        valid = self.receipt.read_text()
        self.receipt.write_text('{"unexpected": true}\n' + valid)
        self.run_installer('--check', success=False)

    def test_check_does_not_install_runtime_download_or_create_directories(self):
        self.env['TEST_MISSING_RUNTIME'] = '1'
        self.run_installer('--check', success=False)
        self.assertFalse((self.base / 'runtime-installed').exists())
        self.assertFalse((self.base / 'downloads').exists())
        self.assertFalse(self.target.exists())

    def test_download_failure_preserves_existing_install(self):
        self.seed_old_install()
        self.env['TEST_DOWNLOAD_FAILURE'] = '1'
        self.run_installer(success=False)
        self.assert_old_install()

    def test_archive_checksum_mismatch_preserves_existing_install(self):
        self.seed_old_install()
        self.archive.write_bytes(b'tampered archive')
        self.run_installer(success=False)
        self.assert_old_install()

    def test_build_failure_preserves_existing_install(self):
        self.seed_old_install()
        self.make_archive(build_failure=True)
        self.run_installer(success=False)
        self.assert_old_install()

    def test_missing_api_rejects_candidate_and_preserves_existing_install(self):
        self.seed_old_install()
        self.make_archive(missing_api=True)
        result = self.run_installer(success=False)
        self.assertIn('exec', result.stdout + result.stderr)
        self.assert_old_install()

    def test_runtime_install_failure_preserves_existing_install(self):
        self.seed_old_install()
        self.env.update(TEST_MISSING_RUNTIME='1', TEST_RUNTIME_FAILURE='1')
        self.run_installer(success=False)
        self.assert_old_install()


unittest.main()
PY
