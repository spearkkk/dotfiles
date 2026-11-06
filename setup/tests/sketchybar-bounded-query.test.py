#!/usr/bin/env python3
"""Real subprocess tests; Python 3.9+, no live SketchyBar or HOME writes."""
import json
import os
from pathlib import Path
import resource
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

BASE = Path(sys.argv.pop(1)).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
HELPER = BASE / "home/.local/libexec/sketchybar-bounded-query"
PYTHON = str(Path(sys.executable).resolve())

# Both processes remain in the owned group. A pipe handshake ensures the
# descendant installed its signal handler before the leader exits/signals.
TREE = r'''
import json, os, signal, sys, time
from pathlib import Path
root, mode = Path(sys.argv[1]), sys.argv[2]
signal.signal(signal.SIGTERM, lambda *_: root.joinpath("term-leader").write_text(str(time.clock_gettime(time.CLOCK_MONOTONIC))))
root.joinpath("leader").write_text(json.dumps([os.getpid(), os.getpgrp()]))
r, w = os.pipe()
pid = os.fork()
if pid == 0:
    os.close(r)
    signal.signal(signal.SIGTERM, lambda *_: root.joinpath("term-descendant").write_text(str(time.clock_gettime(time.CLOCK_MONOTONIC))))
    root.joinpath("descendant").write_text(json.dumps([os.getpid(), os.getpgrp()]))
    if mode == "closed":
        os.close(1)
        os.close(2)
    os.write(w, b"R")
    os.close(w)
    while True: time.sleep(1)
os.close(w)
os.read(r, 1)
os.close(r)
if mode in ("early", "closed"):
    print('{"value":0}', flush=True)
    sys.exit(0)
if mode == "signal":
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    os.kill(os.getpid(), signal.SIGTERM)
if mode == "flood":
    os.write(1, b"x" * (256 * 1024 + 1))
while True: time.sleep(1)
'''


class BoundedQueryTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HELPER.is_file(), "bounded-query helper is not implemented")
        self.tmp = tempfile.TemporaryDirectory(prefix="bounded-query-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.addCleanup(self.kill_fixture_groups)

    def records(self):
        return [json.loads(p.read_text()) for p in self.root.glob("*/leader")] + [
            json.loads(p.read_text()) for p in self.root.glob("*/descendant")]

    def kill_fixture_groups(self):
        for group in {record[1] for record in self.records()}:
            if group != os.getpgrp():
                try:
                    os.killpg(group, signal.SIGKILL)
                except ProcessLookupError:
                    pass

    def command(self, argv, timeout_ms=1000, permit=None):
        options = ["--permit", str(permit)] if permit is not None else []
        return [str(HELPER), "--timeout-ms", str(timeout_ms)] + options + ["--"] + argv

    def permit(self):
        fd, path = tempfile.mkstemp(prefix="permit-", dir=str(self.root))
        os.close(fd)
        return Path(path)

    def decode(self, process):
        stdout, stderr = process.communicate(timeout=6)
        self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(stderr, "")
        reply = json.loads(stdout)
        self.assertEqual(set(reply), {"ok", "reason", "exit_code", "payload"})
        if not reply["ok"]:
            self.assertIsNone(reply["payload"])
            self.assertNotIn("PRIVATE", stdout)
        return reply

    def run_query(self, argv, timeout_ms=1000, permit=None):
        started = time.monotonic()
        with subprocess.Popen(self.command(argv, timeout_ms, permit), text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
            reply = self.decode(process)
        return reply, time.monotonic() - started

    def tree(self, mode, timeout_ms=1000, permit=None):
        directory = self.root / str(len(list(self.root.iterdir())))
        directory.mkdir()
        process = subprocess.Popen(self.command([PYTHON, "-c", TREE, str(directory), mode], timeout_ms, permit),
                                   text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.addCleanup(self.finish_wrapper, process)
        return process, directory

    @staticmethod
    def finish_wrapper(process):
        if process.poll() is None:
            process.terminate()
        try:
            process.communicate(timeout=6)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()

    def assert_tree_gone(self, directory):
        for name in ("leader", "descendant"):
            pid, pgid = json.loads((directory / name).read_text())
            self.assertNotEqual(pgid, os.getpgrp())
            # Orphan zombies are the OS's responsibility, not running queries.
            state = subprocess.run(["/bin/ps", "-o", "stat=", "-p", str(pid)],
                                   text=True, capture_output=True).stdout.strip()
            self.assertTrue(not state or state.startswith("Z"), (pid, state))
        leader, pgid = json.loads((directory / "leader").read_text())
        self.assertEqual(leader, pgid, "child must establish its own session/group")
        state = subprocess.run(["/bin/ps", "-o", "stat=", "-p", str(leader)],
                               text=True, capture_output=True).stdout.strip()
        self.assertEqual(state, "", "direct child must be reaped, not left a zombie")

    def test_success_decodes_json_and_preserves_literal_argv(self):
        argument = "spaces ' quotes ; $(printf PRIVATE)\n한글"
        reply, _ = self.run_query([PYTHON, "-c", "import json,sys; print(json.dumps({'value':0,'arg':sys.argv[1]}))", argument])
        self.assertEqual(reply, {"ok": True, "reason": "ok", "exit_code": 0,
                                 "payload": {"value": 0, "arg": argument}})

    def test_json_scalars_and_exact_output_limit(self):
        for payload in ("null", "false", "0", '"' + "x" * (256 * 1024 - 2) + '"'):
            reply, _ = self.run_query([PYTHON, "-c", "import sys; sys.stdout.write(sys.argv[1])", payload])
            self.assertTrue(reply["ok"])
            self.assertEqual(reply["payload"], json.loads(payload))

    def test_failed_child_never_exposes_stdout_or_stderr(self):
        reply, _ = self.run_query([PYTHON, "-c", "import sys; print('PRIVATE stdout'); print('PRIVATE stderr',file=sys.stderr); sys.exit(7)"])
        self.assertEqual(reply["reason"], "child_failed")
        self.assertEqual(reply["exit_code"], 7)

    def test_invalid_json_never_exposes_raw_output(self):
        reply, _ = self.run_query(["/usr/bin/printf", "%s", "PRIVATE invalid JSON"])
        self.assertEqual(reply["reason"], "invalid_json")

    def test_invalid_utf8_is_a_sanitized_failure(self):
        reply, _ = self.run_query([PYTHON, "-c", "import os; os.write(1, b'\"\\xff PRIVATE\"')"])
        self.assertEqual(reply["reason"], "invalid_json")

    def test_stderr_flood_does_not_block_or_leak(self):
        reply, _ = self.run_query([PYTHON, "-c", "import os; os.write(2, b'PRIVATE' * 100000); print('{}')"])
        self.assertTrue(reply["ok"])
        self.assertEqual(reply["payload"], {})

    def test_closed_stdout_does_not_release_slot_or_busy_spin(self):
        before = resource.getrusage(resource.RUSAGE_CHILDREN)
        reply, elapsed = self.run_query([PYTHON, "-c",
            "import os,signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); "
            "os.write(1,b'{}'); os.close(1); time.sleep(10)"])
        after = resource.getrusage(resource.RUSAGE_CHILDREN)
        self.assertEqual(reply["reason"], "timeout", "EOF is not process completion")
        self.assertGreaterEqual(elapsed, 0.8)
        cpu = after.ru_utime + after.ru_stime - before.ru_utime - before.ru_stime
        self.assertLess(cpu, 0.35, "no pipe descriptors must not turn deadline polling into a busy loop")

    def test_spawn_failure_is_distinct_from_child_exit_127(self):
        reply, _ = self.run_query([str(self.root / "missing")])
        self.assertEqual(reply["reason"], "spawn_failed")
        reply, _ = self.run_query([PYTHON, "-c", "raise SystemExit(127)"])
        self.assertEqual(reply["reason"], "child_failed")
        self.assertEqual(reply["exit_code"], 127)

    def test_setsid_failure_never_announces_group_readiness(self):
        # Fault only the syscall boundary, not the supervisor. The harmless
        # printf child also makes a failed pre-readiness check safe under test.
        module = self.root / "FailSetsid.pm"
        for result in ("-1", "$$"):
            module.write_text("package FailSetsid; use POSIX (); no warnings 'redefine'; "
                              "*POSIX::setsid = sub { " + result + " }; 1;\n")
            environment = dict(os.environ, PERL5LIB=str(self.root), PERL5OPT="-MFailSetsid")
            with subprocess.Popen(self.command(["/usr/bin/printf", "%s", "{}"]),
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  env=environment) as process:
                self.assertEqual(self.decode(process)["reason"], "spawn_failed",
                                 "setsid must establish a new group, not merely return a defined value")

    def test_permit_is_claimed_before_child_and_proof_contains_no_payload(self):
        permit = self.permit()
        source = ("import os,sys; p=sys.argv[1]; "
                  "assert not os.path.exists(p); assert os.path.isfile(p+'.claimed'); "
                  "assert not os.path.exists(p+'.done'); print('{\"value\":\"PRIVATE\"}')")
        reply, _ = self.run_query([PYTHON, "-c", source, str(permit)], permit=permit)
        self.assertTrue(reply["ok"])
        self.assertFalse(permit.exists())
        for suffix in (".claimed", ".done"):
            path = Path(str(permit) + suffix)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(Path(str(permit) + ".done").read_text(), "ok\n")
        self.assertFalse(Path(str(permit) + ".done.tmp").exists())

    def test_revocation_fences_a_late_invocation(self):
        permit = self.permit()
        permit.rename(str(permit) + ".revoked")
        sentinel = self.root / "must-not-run"
        source = "from pathlib import Path; import sys; Path(sys.argv[1]).touch(); print('{}')"
        for _ in range(2):
            reply, _ = self.run_query([PYTHON, "-c", source, str(sentinel)], permit=permit)
            self.assertEqual(reply["reason"], "spawn_failed")
            self.assertFalse(sentinel.exists())
            self.assertFalse(Path(str(permit) + ".claimed").exists())
            self.assertFalse(Path(str(permit) + ".done").exists())

    def test_claim_prevents_revocation_and_duplicate_launch_until_cleanup(self):
        permit = self.permit()
        process, directory = self.tree("hang", permit=permit)
        deadline = time.monotonic() + 0.7
        while not (directory / "descendant").exists() and time.monotonic() < deadline:
            time.sleep(0.005)
        self.assertTrue((directory / "descendant").exists())
        with self.assertRaises(FileNotFoundError):
            permit.rename(str(permit) + ".revoked")
        self.assertFalse(Path(str(permit) + ".done").exists(), "no completion proof while group is live")
        reply, _ = self.run_query(["/usr/bin/printf", "%s", "{}"], permit=permit)
        self.assertEqual(reply["reason"], "spawn_failed")
        self.assertFalse(Path(str(permit) + ".done").exists(), "non-owner cannot publish completion")
        self.assertEqual(self.decode(process)["reason"], "timeout")
        self.assertEqual(Path(str(permit) + ".done").read_text(), "timeout\n")
        self.assert_tree_gone(directory)

    def test_failed_query_proof_is_sanitized(self):
        permit = self.permit()
        reply, _ = self.run_query(["/usr/bin/printf", "%s", "PRIVATE invalid JSON"], permit=permit)
        self.assertEqual(reply["reason"], "invalid_json")
        self.assertEqual(Path(str(permit) + ".done").read_text(), "invalid_json\n")

    def test_cleanup_failure_proof_does_not_claim_success(self):
        # Simulate group liveness after a harmless child exits; no unkillable
        # process is actually created for this failure-path test.
        module = self.root / "GroupRemains.pm"
        module.write_text("package GroupRemains; *CORE::GLOBAL::kill = sub { "
                          "return 1 if $_[0] eq '0'; return CORE::kill($_[0], @_[1..$#_]); }; 1;\n")
        environment = dict(os.environ, PERL5LIB=str(self.root), PERL5OPT="-MGroupRemains")
        permit = self.permit()
        with subprocess.Popen(self.command(["/usr/bin/printf", "%s", "{}"], permit=permit),
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              env=environment) as process:
            self.assertEqual(self.decode(process)["reason"], "cleanup_failed")
        self.assertEqual(Path(str(permit) + ".done").read_text(), "cleanup_failed\n")

    def test_rejects_invalid_cli_without_running_child(self):
        for args in (["--timeout-ms", str(ms), "--", "/usr/bin/true"]
                     for ms in (999, 5001, "1000.5", "bad", "-1")):
            with subprocess.Popen([str(HELPER)] + args, text=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE) as process:
                self.assertEqual(self.decode(process)["reason"], "spawn_failed")
        for args in ([], ["--timeout-ms", "1000", "--", "printf", "{}"],
                     ["--timeout-ms", "1000", "/usr/bin/true"]):
            with subprocess.Popen([str(HELPER)] + args, text=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE) as process:
                self.assertEqual(self.decode(process)["reason"], "spawn_failed")

    def test_term_ignoring_descendants_timeout_and_recover_repeatedly(self):
        with subprocess.Popen(["/bin/sleep", "20"]) as unrelated:
            try:
                for _ in range(3):
                    # Python 3.9's macOS monotonic() epoch is process-relative;
                    # explicit CLOCK_MONOTONIC can compare child timestamps.
                    started = time.clock_gettime(time.CLOCK_MONOTONIC)
                    process, directory = self.tree("hang")
                    reply = self.decode(process)
                    elapsed = time.clock_gettime(time.CLOCK_MONOTONIC) - started
                    self.assertEqual(reply["reason"], "timeout")
                    self.assertGreaterEqual(elapsed, 0.8)
                    self.assertLess(elapsed, 1.3)
                    term = float((directory / "term-leader").read_text())
                    self.assertGreaterEqual(term - started, 0.78, "execution gets 80% of budget")
                    self.assertGreaterEqual(started + elapsed - term, 0.08, "TERM gets 10% grace before KILL")
                    self.assertTrue((directory / "term-descendant").exists(), "TERM must target entire group")
                    self.assert_tree_gone(directory)
                    self.assertIsNone(unrelated.poll())
                    reply, _ = self.run_query(["/usr/bin/printf", "%s", '{"recovered":true}'])
                    self.assertEqual(reply["payload"], {"recovered": True})
            finally:
                unrelated.terminate()
                unrelated.wait()

    def test_five_second_budget_includes_kill_and_reap(self):
        started = time.monotonic()
        process, directory = self.tree("hang", 5000)
        self.assertEqual(self.decode(process)["reason"], "timeout")
        elapsed = time.monotonic() - started
        self.assertGreaterEqual(elapsed, 4.0)
        self.assertLess(elapsed, 5.0)
        self.assert_tree_gone(directory)

    def test_leader_early_exit_cleans_descendants_even_without_open_stdout(self):
        for mode in ("early", "closed"):
            process, directory = self.tree(mode)
            reply = self.decode(process)
            self.assertEqual(reply["payload"], {"value": 0})
            self.assertTrue(reply["ok"])
            self.assert_tree_gone(directory)

    def test_output_cap_cleans_group(self):
        process, directory = self.tree("flood")
        self.assertEqual(self.decode(process)["reason"], "output_limit")
        self.assert_tree_gone(directory)

    def test_child_signal_cleans_group(self):
        process, directory = self.tree("signal")
        reply = self.decode(process)
        self.assertEqual(reply["reason"], "child_failed")
        self.assertEqual(reply["exit_code"], 143)
        self.assert_tree_gone(directory)

    def test_wrapper_term_and_int_clean_owned_group(self):
        for sig in (signal.SIGTERM, signal.SIGINT):
            process, directory = self.tree("hang")
            deadline = time.monotonic() + 1
            while not (directory / "descendant").exists() and time.monotonic() < deadline:
                time.sleep(0.005)
            self.assertTrue((directory / "descendant").exists())
            process.send_signal(sig)
            reply = self.decode(process)
            self.assertEqual(reply["reason"], "child_failed")
            self.assert_tree_gone(directory)

    def test_lua_async_lifecycle(self):
        lua = os.environ.get("LUA_BIN") or shutil.which("lua")
        self.assertTrue(lua, "set LUA_BIN to a Lua 5.4 interpreter (mise)")
        result = subprocess.run([lua, str(BASE / "setup/tests/sketchybar-bounded-query.test.lua"), str(BASE)],
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS: bounded_query Lua async lifecycle", result.stdout)


if __name__ == "__main__":
    unittest.main()
