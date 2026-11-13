#!/usr/bin/env python3
"""Exercise the launcher and config without contacting a running bar."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "home/.local/bin/sketchibar"
CONFIG = ROOT / "home/.config/sketchibar/sketchibarrc"


class SketchibarTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(LAUNCHER.is_file(), "missing independent sketchibar launcher")
        self.assertTrue(CONFIG.is_file(), "missing independent sketchibar config")
        self.temp = tempfile.TemporaryDirectory(prefix="sketchibar-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home with spaces"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        (self.home / ".local/bin").mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin))

    def run_launcher(self, *args):
        return subprocess.run(["/bin/bash", str(LAUNCHER), *args],
                              env=self.env, text=True, capture_output=True)

    def test_launcher_sets_an_independent_instance_name(self):
        (self.bin / "sketchybar").symlink_to("/bin/bash")
        result = self.run_launcher("-c", 'printf "%s" "$0"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "sketchibar")

    def test_launcher_preserves_arguments(self):
        (self.bin / "sketchybar").symlink_to("/bin/bash")
        result = self.run_launcher("-c", 'printf "<%s>\\n" "$@"', "fixture",
                                   "label with spaces", "--bar", "hidden=toggle")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "<label with spaces>\n<--bar>\n<hidden=toggle>\n")

    def test_start_uses_only_its_own_config(self):
        fake = self.bin / "sketchybar"
        fake.write_text('#!/bin/sh\nprintf "<%s>\\n" "$@"\n')
        fake.chmod(0o700)
        result = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout,
                         f"<--config>\n<{self.home}/.config/sketchibar/sketchibarrc>\n")

    def test_missing_sketchybar_has_a_clear_error(self):
        result = self.run_launcher("--bar", "hidden=toggle")
        self.assertEqual(result.returncode, 127)
        self.assertIn("sketchybar", result.stderr)

    def test_visibility_commands_notify_main_bar_without_changing_exit_status(self):
        log = self.base / "calls"
        self.env["CALLS"] = str(log)
        fake = self.bin / "sketchybar"
        fake.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALLS"\nif [ "$1" = "--bar" ]; then exit "${BAR_EXIT:-0}"; fi\n')
        fake.chmod(0o700)
        for args in (("--bar", "hidden=off"), ("--bar", "hidden=toggle"), ("--exit",), ("--reload",)):
            log.write_text('')
            result = self.run_launcher(*args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log.read_text().splitlines(), [' '.join(args), '--trigger sketchibar_visibility'])
        log.write_text('')
        self.env['BAR_EXIT'] = '17'
        self.assertEqual(self.run_launcher('--bar', 'hidden=on').returncode, 17)
        self.assertEqual(log.read_text().splitlines(), ['--bar hidden=on'])
        log.write_text('')
        self.assertEqual(self.run_launcher('--set', 'example', 'label=hidden=on').returncode, 0)
        self.assertEqual(log.read_text().splitlines(), ['--set example label=hidden=on'])

    def test_config_preserves_joined_baseline_and_connects_live_collectors(self):
        fake = self.home / ".local/bin/sketchibar"
        fake.write_text("#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n")
        fake.chmod(0o700)
        env = dict(self.env, PATH=os.environ["PATH"])
        result = subprocess.run(["/bin/bash", str(CONFIG)], env=env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(result.stdout)
        bar = args[args.index("--bar") + 1:args.index("--default")]
        for value in ("display=all", "height=80", "margin=0", "y_offset=4",
                      "corner_radius=8", "border_width=3", "color=0xff0a1f2e",
                      "border_color=0xff0a1f2e", "topmost=window", "hidden=on"):
            self.assertIn(value, bar)
        self.assertFalse(any(arg.startswith("width=") for arg in bar))
        self.assertIn("--subscribe", args)
        self.assertNotIn("label=미리보기", args)
        self.assertIn("y_offset=-20", args)
        self.assertNotIn("y_offset=20", args)
        for name in ("sketchibar.battery.keyboard", "sketchibar.battery.trackpad"):
            self.assertIn(name, args)
        battery_group = args.index("sketchibar.battery")
        end = args.index("--set", battery_group)
        self.assertEqual(args[battery_group + 1:end],
                         ["sketchibar.battery.level", "sketchibar.battery.time",
                          "sketchibar.battery.keyboard", "sketchibar.battery.trackpad"])
        self.assertLess(args.index("sketchibar.battery.trackpad"), args.index("sketchibar.battery.keyboard"))
        self.assertLess(args.index("sketchibar.battery.keyboard"), args.index("sketchibar.battery.time"))
        self.assertIn("update_freq=60", args)
        self.assertIn("update_freq=1800", args)
        event = args.index('cafe_changed') if 'cafe_changed' in args else -1
        self.assertGreater(event, 0, 'register cross-bar Coffee change event')
        self.assertEqual(args[event - 2:event], ['--add', 'event'])
        self.assertTrue(any(arg.startswith('script=') and arg.endswith(' cafe') for arg in args))
        self.assertIn('sketchibar.cafe.worker', args)
        self.assertIn('sketchibar.hover', args)
        self.assertIn('mouse.entered.global', args)
        self.assertIn('mouse.exited.global', args)
        self.assertTrue(any(arg.startswith('script=') and 'sketchibar_hover' in arg for arg in args))
        self.assertTrue(any(arg.startswith("script=") and "sketchibar-update" in arg for arg in args))
        for sample in ("label=18° (17°)", "label=82%", "label=Home Wi-Fi", "label=192.168.0.24"):
            self.assertNotIn(sample, args)
        for group in ("sketchibar.weather", "sketchibar.battery", "sketchibar.cafe"):
            start = args.index(group)
            self.assertEqual(args[start - 2:start], ["--add", "bracket"])
        names = [args[i + 2] for i, arg in enumerate(args[:-2]) if arg == "--add"]
        self.assertLess(names.index("sketchibar.weather.wind"), names.index("sketchibar.battery.time"))
        self.assertFalse(any("sketchibar.wifi" in name for name in names))
        self.assertFalse(any(name.startswith("sketchibar.sound") for name in names))
        self.assertNotIn("sketchibar.gap.sound", names)
        self.assertNotIn("sketchibar.sound.slider", names)
        self.assertFalse(any(args[i + 1] == "slider" for i, value in enumerate(args[:-1]) if value == "--add"))
        self.assertNotIn("mouse.clicked", args)
        self.assertNotIn("sketchibar.audio", names)
        self.assertIn("sketchibar.pomodoro", names)
        pomo = args.index("sketchibar.pomodoro")
        self.assertEqual(args[pomo - 2:pomo + 2],
                         ["--add", "item", "sketchibar.pomodoro", "right"])
        self.assertLess(names.index("sketchibar.cafe.remaining"),
                        names.index("sketchibar.pomodoro"))
        self.assertIn("sketchibar.gap.pomodoro", names)
        self.assertLess(names.index("sketchibar.cafe.remaining"),
                        names.index("sketchibar.gap.pomodoro"))
        self.assertLess(names.index("sketchibar.gap.pomodoro"),
                        names.index("sketchibar.pomodoro"))
        for gap_name in ("sketchibar.gap.weather", "sketchibar.gap.cafe",
                         "sketchibar.gap.pomodoro"):
            start = args.index("--set", args.index(gap_name))
            end = next((i for i in range(start + 2, len(args))
                        if args[i].startswith("--")), len(args))
            self.assertIn("width=14", args[start:end])
        start = args.index("--set", pomo)
        end = next((i for i in range(start + 2, len(args))
                    if args[i].startswith("--")), len(args))
        self.assertNotIn("padding_left=8", args[start:end])
        self.assertIn("sketchibar.pomodoro.group", names)
        group = args.index("sketchibar.pomodoro.group")
        self.assertEqual(args[group - 2:group + 2],
                         ["--add", "bracket", "sketchibar.pomodoro.group", "sketchibar.pomodoro"])
        start = args.index("--set", group)
        end = next((i for i in range(start + 2, len(args))
                    if args[i].startswith("--")), len(args))
        for value in ("background.drawing=on", "background.color=0xff142c3e",
                      "background.height=28", "background.corner_radius=4",
                      "background.border_width=0"):
            self.assertIn(value, args[start:end])
        self.assertIn("sketchibar.cafe.remaining", names)
        self.assertLess(names.index("sketchibar.battery.time"), names.index("sketchibar.cafe.remaining"))

    def test_shell_syntax_and_executable_modes(self):
        for path in (LAUNCHER, CONFIG):
            self.assertTrue(os.access(path, os.X_OK), str(path))
            subprocess.run(["/bin/bash", "-n", str(path)], check=True)

    def test_detail_hover_relay_forwards_only_enter_and_exit_to_main(self):
        calls = self.base / 'hover-calls'
        main = self.bin / 'sketchybar'
        main.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALLS"\n')
        main.chmod(0o700)
        fake = self.home / '.local/bin/sketchibar'
        fake.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
        fake.chmod(0o700)
        env = dict(self.env, PATH=str(self.bin) + ':' + os.environ['PATH'], CALLS=str(calls))
        result = subprocess.run(['/bin/bash', str(CONFIG)], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(result.stdout)
        relay = next(a.removeprefix('script=') for a in args
                     if a.startswith('script=') and 'sketchibar_hover' in a)
        subprocess.run(['/bin/sh', '-n'], input=relay, text=True, check=True)
        for sender in ('mouse.entered.global', 'mouse.exited.global', 'routine', 'forced'):
            subprocess.run(['/bin/sh', '-c', relay], env=dict(env, SENDER=sender), check=True)
        self.assertEqual(calls.read_text().splitlines(),
                         ['--trigger sketchibar_hover ACTION=enter', '--trigger sketchibar_hover ACTION=exit'])


if __name__ == "__main__":
    unittest.main()
