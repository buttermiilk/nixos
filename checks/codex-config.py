#!/usr/bin/env python3
"""Test private config migration and directory trust without user state or APIs."""

import importlib.util
from pathlib import Path
import stat
import sys
import tempfile
import unittest

import tomlkit

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("sync", sys.argv.pop(1))
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class CodexConfigTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "codex"
        self.home.mkdir()
        self.base = self.root / "base.toml"
        self.base.write_text('model = "managed-model"\n[projects."/public/config"]\ntrust_level = "trusted"\n')
        self.dev = self.root / "Dev"
        self.dev.mkdir()
        self.patterns = [str(self.dev / "*")]

    def render(self):
        sync.sync_config(self.home, self.base, self.patterns)
        return tomlkit.parse((self.home / "config.toml").read_text())

    def test_discovers_directories_and_preserves_private_decisions(self):
        allowed = self.dev / 'project with "quotes"'
        denied = self.dev / "denied"
        allowed.mkdir()
        denied.mkdir()
        (self.dev / "not-a-directory").write_text("ignored")
        local = tomlkit.document()
        local["model"] = "old-model"
        local["projects"] = {str(denied): {"trust_level": "untrusted"},
                             "/private/project": {"trust_level": "trusted"}}
        local["plugins"] = {"personal": {"enabled": True}}
        (self.home / "config.toml").write_text(tomlkit.dumps(local))
        result = self.render()
        self.assertEqual(result["model"], "managed-model")
        self.assertEqual(result["projects"][str(allowed)]["trust_level"], "trusted")
        self.assertEqual(result["projects"][str(denied)]["trust_level"], "untrusted")
        self.assertEqual(result["projects"]["/private/project"]["trust_level"], "trusted")
        self.assertTrue(result["plugins"]["personal"]["enabled"])
        self.assertNotIn(str(self.dev / "not-a-directory"), result["projects"])

    def test_does_not_follow_directory_links_outside_the_trusted_root(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.dev / "outside-link").symlink_to(outside, target_is_directory=True)
        self.assertNotIn(str(outside), self.render()["projects"])

    def test_rejects_relative_trust_globs(self):
        self.patterns = ["relative/*"]
        with self.assertRaises(ValueError):
            self.render()

    def test_ignores_broken_and_looping_directory_links(self):
        (self.dev / "missing").symlink_to(self.root / "missing", target_is_directory=True)
        (self.dev / "loop").symlink_to("loop", target_is_directory=True)
        self.assertEqual(list(self.render()["projects"]), ["/public/config"])

    def test_migrates_a_removed_home_manager_symlink(self):
        old = self.root / "old-managed-config.toml"
        old.write_text('[projects."/private/previous"]\ntrust_level = "trusted"\n')
        original = old.read_text()
        target = self.home / "config.toml"
        target.symlink_to(old)
        sync.sync_config(self.home, self.base, self.patterns, capture=True)
        target.unlink()  # Home Manager's old-generation cleanup.
        result = self.render()
        self.assertEqual(result["projects"]["/private/previous"]["trust_level"], "trusted")
        self.assertFalse(target.is_symlink())
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        self.assertEqual(old.read_text(), original)
        self.assertFalse((self.home / ".config-home-manager-migration.toml").exists())

    def test_replaces_symlink_without_modifying_its_target(self):
        original = self.root / "immutable.toml"
        original.write_text('model = "old"\n')
        target = self.home / "config.toml"
        target.symlink_to(original)
        self.render()
        self.assertEqual(original.read_text(), 'model = "old"\n')
        self.assertFalse(target.is_symlink())

    def test_new_project_is_discovered_without_rewriting_unchanged_config(self):
        self.render()
        target = self.home / "config.toml"
        before = target.stat().st_mtime_ns
        self.render()
        self.assertEqual(target.stat().st_mtime_ns, before)
        project = self.dev / "new-project"
        project.mkdir()
        self.assertIn(str(project), self.render()["projects"])

    def test_malformed_local_config_is_not_overwritten(self):
        target = self.home / "config.toml"
        target.write_text("[invalid")
        with self.assertRaises(Exception):
            self.render()
        self.assertEqual(target.read_text(), "[invalid")


unittest.main()
