#!/usr/bin/env python3
"""Check publication ordering, immutable pins, and the local no-compile guard."""

import importlib.util
import json
import os
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("publisher", sys.argv.pop(1))
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublisherTest(unittest.TestCase):
    config = ("https://" + "a" * 32 + ".r2.cloudflarestorage.com", "nixos")
    source = {"version": "0.1.3", "rev": "b" * 40, "hash": "sha256-test"}

    def test_configuration_is_optional_but_partial_configuration_fails(self):
        self.assertIsNone(publisher.configuration({}))
        with self.assertRaises(ValueError):
            publisher.configuration({"R2_BUCKET": "nixos"})
        env = dict(R2_ENDPOINT=self.config[0], R2_BUCKET="nixos",
                   AWS_ACCESS_KEY_ID="test", AWS_SECRET_ACCESS_KEY="test")
        self.assertEqual(publisher.configuration(env), self.config)
        for value in ("http://example.org", self.config[0] + "/nixos"):
            with self.subTest(endpoint=value), self.assertRaises(ValueError):
                publisher.configuration(dict(env, R2_ENDPOINT=value))

    def test_compilation_is_rejected_outside_github_actions(self):
        with patch.dict(os.environ, {}, clear=True), \
             patch.object(publisher.subprocess, "check_output") as command:
            with self.assertRaises(RuntimeError):
                publisher.prepare_archives(Path("/unused"), self.source, "c" * 64)
        command.assert_not_called()

    def test_unchanged_build_does_not_build_or_upload(self):
        previous = {"buildId": "c" * 64}
        with patch.object(publisher, "prepare_archives") as build, \
             patch.object(publisher.subprocess, "run") as upload:
            self.assertEqual(publisher.publish(self.config, self.source, "c" * 64, previous), previous)
        build.assert_not_called()
        upload.assert_not_called()

    def test_preparation_removes_build_credentials_and_archives_source_and_units(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package, source, work = root / "package", root / "source", root / "work"
            for name in ("bin", "lib/systemd/system", "share/doc/bootvine"):
                (package / name).mkdir(parents=True)
            (package / "bin/bootvine").write_bytes(b"binary fixture")
            (package / "lib/systemd/system/bootvine.service").write_text("ExecStart=/usr/bin/bootvine")
            (package / "share/doc/bootvine/LICENSE").write_text("license fixture")
            (package / "share/doc/bootvine").chmod(0o555)
            source.mkdir()
            (source / "Cargo.lock").write_text("locked source fixture")
            work.mkdir()
            with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "AWS_SECRET_ACCESS_KEY": "test-secret"}), \
                 patch.object(publisher.subprocess, "check_output", side_effect=[str(package), str(source)]) as build, \
                 patch.object(publisher.subprocess, "run") as patch_binary:
                binary_archive, source_archive = publisher.prepare_archives(work, self.source, "c" * 64)
            for call in build.call_args_list:
                self.assertNotIn("AWS_SECRET_ACCESS_KEY", call.kwargs["env"])
            self.assertEqual(patch_binary.call_args_list[0].args[0][1], "--remove-rpath")
            self.assertEqual(patch_binary.call_args_list[1].args[0][1], "--set-interpreter")
            with tarfile.open(binary_archive) as archive:
                self.assertIn("lib/systemd/system/bootvine.service", archive.getnames())
                info = json.load(archive.extractfile("share/doc/bootvine/build.json"))
                self.assertEqual(info["source"], self.source)
            with tarfile.open(source_archive) as archive:
                self.assertEqual(archive.extractfile("Cargo.lock").read(), b"locked source fixture")

    def test_both_downloads_are_verified_before_a_new_pin_is_returned(self):
        with tempfile.TemporaryDirectory() as directory:
            binary, source = Path(directory) / "binary.tar.xz", Path(directory) / "source.tar.xz"
            binary.write_bytes(b"binary")
            source.write_bytes(b"source")
            events = []
            with patch.object(publisher, "prepare_archives", return_value=(binary, source)), \
                 patch.object(publisher.subprocess, "run", side_effect=lambda *a, **k: events.append("upload")), \
                 patch.object(publisher, "verify_download", side_effect=lambda *a: events.append("verify")):
                result = publisher.publish(self.config, self.source, "c" * 64, {})
            self.assertEqual(events, ["upload", "verify", "upload", "verify"])
            self.assertEqual(result["hash"], publisher.sha256(binary))
            self.assertEqual(result["sourceHash"], publisher.sha256(source))
            self.assertTrue(result["url"].startswith(publisher.PUBLIC_BASE + "/bootvine/"))

    def test_failed_publication_preserves_all_previous_mirror_pins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "dependencies").mkdir()
            (root / "dependencies/upstream.json").write_text(json.dumps({"bootvine": self.source}))
            path = root / "dependencies/mirrors.json"
            original = {"bootvine": {"version": "0.1.2"}, "bongocat-osu": {"version": "fixed"}}
            path.write_text(json.dumps(original))
            with patch.object(publisher, "ROOT", root), \
                 patch.object(publisher, "configuration", return_value=self.config), \
                 patch.object(publisher, "build_id", return_value="c" * 64), \
                 patch.object(publisher, "publish", side_effect=ValueError("public download failed")):
                with self.assertRaises(ValueError):
                    publisher.main()
            self.assertEqual(json.loads(path.read_text()), original)

    def test_archive_is_reproducible_and_has_no_machine_ownership_or_timestamps(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tree = root / "tree"
            tree.mkdir()
            (tree / "LICENSE").write_text("license fixture")
            first, second = root / "first.tar.xz", root / "second.tar.xz"
            publisher.archive_tree(tree, first)
            os.utime(tree / "LICENSE", (123456, 123456))
            publisher.archive_tree(tree, second)
            self.assertEqual(publisher.sha256(first), publisher.sha256(second))
            with tarfile.open(first) as archive:
                info = archive.getmember("LICENSE")
                self.assertEqual((info.uid, info.gid, info.mtime, info.uname, info.gname), (0, 0, 0, "", ""))

    def test_build_identity_changes_with_source_builder_or_nixpkgs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "dependencies/builders").mkdir(parents=True)
            builder = root / "dependencies/builders/bootvine.nix"
            builder.write_text("builder")
            (root / "dependencies/publish-bootvine.py").write_text("publisher")
            lock = root / "flake.lock"
            lock.write_text(json.dumps({"nodes": {"nixpkgs": {"locked": {"rev": "old"}}}}))
            with patch.object(publisher, "ROOT", root):
                first = publisher.build_id(self.source)
                self.assertNotEqual(first, publisher.build_id(dict(self.source, rev="new")))
                builder.write_text("updated builder")
                self.assertNotEqual(first, publisher.build_id(self.source))
                builder.write_text("builder")
                lock.write_text(json.dumps({"nodes": {"nixpkgs": {"locked": {"rev": "new"}}}}))
                self.assertNotEqual(first, publisher.build_id(self.source))


unittest.main()
