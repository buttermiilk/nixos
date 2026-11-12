"""Exercise power-mode transitions against fake RAPL files and desktop commands."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

POWER_SOURCE = Path(sys.argv[1]).read_text().replace("#!/usr/bin/env bash", "#!" + shutil.which("bash"))
DESKTOP_SOURCE = Path(sys.argv[2]).read_text()


class PowerModes(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root / "state"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / "runtime").mkdir()
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        XDG_RUNTIME_DIR=str(self.root / "runtime"), FIXTURE=str(self.root))
        self.limits = []
        for zone, values in [("intel-rapl:0", (45000000, 90000000)),
                             ("intel-rapl-mmio:0", (55000000, 110000000))]:
            folder = self.root / "powercap" / zone
            folder.mkdir(parents=True)
            for index, (name, value) in enumerate(zip(("long_term", "short_term"), values)):
                (folder / f"constraint_{index}_name").write_text(name + "\n")
                limit = folder / f"constraint_{index}_power_limit_uw"
                limit.write_text(str(value) + "\n")
                self.limits.append(limit)
        self.native = self.values()
        self.power = self.root / "power-limit"
        self.power.write_text(POWER_SOURCE.replace("/run/power-limit", str(self.state))
                             .replace("/sys/class/powercap", str(self.root / "powercap"))
                             .replace("/run/booted-system", str(self.root / "booted")))
        self.desktop = self.root / "desktop.sh"
        self.desktop.write_text(DESKTOP_SOURCE.replace("/run/power-limit", str(self.state))
                                .replace("/run/current-system/sw/bin/power-limit", str(self.power))
                                .replace("/run/wrappers/bin/sudo", str(self.bin / "sudo")))
        self.power.chmod(0o755)
        mock = self.bin / "mock"
        mock.write_text(f"#!{sys.executable}\n" + '''
import os
from pathlib import Path
import sys
root = Path(os.environ["FIXTURE"])
command = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(command + " " + " ".join(args) + "\\n")
if command == "sudo":
    os.execv(args[1], args[1:])
if command == "pgrep" and (root / "no-compositor").exists():
    sys.exit(1)
if command == "tlp":
    if args[0] == "performance" and (root / "fail-performance").exists():
        sys.exit(1)
    (root / "profile").write_text(args[0])
if command == "brightnessctl":
    brightness = root / "brightness"
    if args == ["-m"]:
        print("display,backlight,80," + brightness.read_text() + "%,100")
    else:
        brightness.write_text(args[-1].rstrip("%"))
''')
        mock.chmod(0o755)
        for name in ("sudo", "tlp", "brightnessctl", "notify-send", "pgrep", "pkill", "i3-msg", "polybar-msg"):
            (self.bin / name).symlink_to(mock)
        (self.root / "brightness").write_text("80")

    def values(self):
        return [int(p.read_text()) for p in self.limits]

    def run_power(self, action, success=True):
        result = subprocess.run(["bash", str(self.power), action], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def run_desktop(self, mode, action, success=True):
        result = subprocess.run(["bash", str(self.desktop), action],
                                env=dict(self.env, POWER_MODE_TARGET=mode),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def test_performance_restores_native_limits_and_timer_respects_thermald(self):
        self.run_power("capture")
        self.run_power("apply")
        self.assertEqual(self.values(), [30000000] * 4)
        self.run_power("capture")  # Recapture must not replace native values with the cap.
        self.run_power("performance")
        self.assertEqual(self.values(), self.native)
        self.limits[0].write_text("20000000\n")  # A lower thermald limit remains effective.
        self.run_power("apply")
        self.assertEqual(self.values(), [20000000] + self.native[1:])
        self.run_power("normal")
        self.assertEqual(self.values(), [20000000, 30000000, 30000000, 30000000])
        self.assertEqual((self.root / "profile").read_text(), "balanced")

    def test_migration_requires_fresh_boot(self):
        old = self.root / "booted/sw/bin/apply-package-power-cap"
        old.parent.mkdir(parents=True)
        old.touch()
        old.chmod(0o755)
        self.run_power("capture")
        self.assertFalse((self.state / "baseline/ready").exists())
        self.run_power("performance", success=False)
        self.assertEqual(self.values(), self.native)

    def test_bad_baseline_cannot_partially_restore_limits(self):
        self.run_power("capture")
        self.run_power("normal")
        saved = next((self.state / "baseline").glob("*power_limit_uw"))
        saved.write_text("invalid\n")
        self.run_power("performance", success=False)
        self.assertEqual(self.values(), [30000000] * 4)
        self.assertEqual((self.state / "mode").read_text().strip(), "normal")

    def test_failed_profile_change_rolls_back(self):
        self.run_power("capture")
        (self.root / "fail-performance").touch()
        self.run_power("performance", success=False)
        self.assertEqual(self.values(), [30000000] * 4)
        self.assertEqual((self.state / "mode").read_text().strip(), "normal")
        self.assertEqual((self.root / "profile").read_text(), "balanced")

    def test_invalid_constraint_does_not_change_other_limits(self):
        self.limits[-1].with_name("constraint_1_name").write_text("unexpected\n")
        self.run_power("normal", success=False)
        self.assertEqual(self.values(), self.native)

    def test_shortcuts_switch_exclusively_and_restore_desktop(self):
        self.run_power("capture")
        self.run_desktop("eco", "on")
        self.assertEqual((self.root / "brightness").read_text(), "40")
        self.assertEqual(self.run_desktop("eco", "status").stdout.strip(), "on")
        self.run_desktop("performance", "toggle")
        self.assertEqual(self.values(), self.native)
        self.assertEqual((self.root / "brightness").read_text(), "80")
        self.assertFalse((self.root / "runtime/eco-mode").exists())
        self.assertEqual(self.run_desktop("eco", "status").stdout.strip(), "off")
        self.run_desktop("performance", "toggle")
        self.assertEqual(self.values(), [30000000] * 4)
        self.assertEqual((self.root / "profile").read_text(), "balanced")
        self.run_desktop("performance", "on")
        self.run_desktop("eco", "on")
        self.assertEqual(self.values(), [30000000] * 4)
        self.assertEqual((self.root / "profile").read_text(), "power-saver")
        self.run_desktop("eco", "off")
        self.assertEqual((self.root / "brightness").read_text(), "80")
        self.assertEqual((self.root / "profile").read_text(), "balanced")
        self.assertNotIn("pkill ", (self.root / "calls").read_text())

    def test_power_modes_recover_missing_compositor(self):
        self.run_power("capture")
        (self.root / "no-compositor").touch()
        for mode in ("eco", "performance"):
            for action in ("on", "off"):
                (self.root / "calls").write_text("")
                self.run_desktop(mode, action)
                calls = (self.root / "calls").read_text()
                self.assertIn("i3-msg -q exec --no-startup-id picom --config ", calls)
                self.assertNotIn("pkill ", calls)

    def test_failed_performance_keeps_eco_desktop_intact(self):
        self.run_desktop("eco", "on")
        self.run_desktop("performance", "on", success=False)
        self.assertEqual((self.root / "brightness").read_text(), "40")
        self.assertEqual(self.run_desktop("eco", "status").stdout.strip(), "on")

    def test_profile_failure_restores_desktop_after_root_rollback(self):
        self.run_power("capture")
        self.run_desktop("eco", "on")
        (self.root / "fail-performance").touch()
        self.run_desktop("performance", "on", success=False)
        self.assertEqual((self.root / "brightness").read_text(), "80")
        self.assertEqual((self.state / "mode").read_text().strip(), "normal")


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
