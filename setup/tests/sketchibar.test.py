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
                      "border_color=0xff0a1f2e", "topmost=window", "hidden=off"):
            self.assertIn(value, bar)
        self.assertFalse(any(arg.startswith("width=") for arg in bar))
        self.assertIn("--subscribe", args)
        self.assertNotIn("label=미리보기", args)
        self.assertIn("y_offset=-20", args)
        self.assertNotIn("y_offset=20", args)
        self.assertIn("update_freq=60", args)
        self.assertIn("update_freq=1800", args)
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
        self.assertIn("sketchibar.cafe.remaining", names)
        self.assertLess(names.index("sketchibar.battery.time"), names.index("sketchibar.cafe.remaining"))

    def test_shell_syntax_and_executable_modes(self):
        for path in (LAUNCHER, CONFIG):
            self.assertTrue(os.access(path, os.X_OK), str(path))
            subprocess.run(["/bin/bash", "-n", str(path)], check=True)


if __name__ == "__main__":
    unittest.main()
