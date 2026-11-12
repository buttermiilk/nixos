#!/usr/bin/env python3
"""Exercise update selection and mirror validation without network or Nix writes."""

import copy
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("updater", sys.argv.pop(1))
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class DependencyUpdaterTest(unittest.TestCase):
    def setUp(self):
        self.manifest = {
            name: {"version": "1.2.3", "url": f"https://nixos.mewo.eu.org/{name}",
                   "hash": "sha256-" + "A" * 43 + "="}
            for name in ("taiko-editor",)
        }

    def read(self, manifest):
        response = io.BytesIO(json.dumps(manifest).encode())
        with patch.object(updater, "urlopen", return_value=response):
            return updater.read_mirror_manifest("https://nixos.mewo.eu.org/manifest.json")

    def test_valid_manifest(self):
        self.assertEqual(self.read(self.manifest), self.manifest)

    def test_manifest_requires_taiko_editor(self):
        del self.manifest["taiko-editor"]
        with self.assertRaises(ValueError):
            self.read(self.manifest)

    def test_rejects_invalid_fields(self):
        for field, value in (("url", "https://elsewhere.example/app.deb"),
                             ("url", "http://nixos.mewo.eu.org/app.deb"),
                             ("hash", "sha256-YWJj"),
                             ("version", "latest"), ("hash", None)):
            with self.subTest(field=field, value=value):
                manifest = copy.deepcopy(self.manifest)
                manifest["taiko-editor"][field] = value
                with self.assertRaises(ValueError):
                    self.read(manifest)

    def test_update_selection(self):
        for all_inputs in (False, True):
            with self.subTest(all_inputs=all_inputs), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "dependencies").mkdir()
                policy = {"applications": ["codex-nix"], "infrastructure": ["nixpkgs"],
                          "upstream": ["blender-mcp"],
                          "github": {"tosu": {"repo": "tosuapp/tosu", "asset": "tosu-linux-v{version}.zip"}}}
                (root / "dependencies/update-policy.json").write_text(json.dumps(policy))
                calls = []
                argv = ["update.py"] + (["--all"] if all_inputs else [])
                with patch.object(updater, "ROOT", root), \
                     patch.object(updater, "run", side_effect=lambda *args: calls.append(args)), \
                     patch.object(updater, "update_upstream") as update_upstream, \
                     patch.object(sys, "argv", argv), patch.dict(updater.os.environ, {}, clear=True):
                    updater.main()
                expected_inputs = ("codex-nix", "nixpkgs") if all_inputs else ("codex-nix",)
                self.assertEqual(calls, [("nix", "flake", "update", *expected_inputs)])
                update_upstream.assert_called_once_with(["blender-mcp", "tosu"], github=policy["github"])

    def test_monitask_index_filters_packages_and_architectures(self):
        def entry(name, arch, version):
            return (f"Package: {name}\nArchitecture: {arch}\nVersion: {version}\n"
                    f"Filename: pool/main/m/monitask/monitask_{version}_{arch}.deb\n"
                    f"SHA256: {'a' * 64}\nDescription: test\n continued description\n")
        text = "\n".join((entry("other", "amd64", "9"), entry("monitask", "arm64", "8"),
                          entry("monitask", "amd64", "0.01.86")))
        candidates = updater.parse_monitask_index(text)
        self.assertEqual(len(candidates), 1)
        self.assertEqual(candidates[0]["version"], "0.01.86")
        self.assertTrue(candidates[0]["url"].endswith("monitask_0.01.86_amd64.deb"))
        self.assertEqual(candidates[0]["hash"],
                         "sha256-qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqo=")

    def test_mirror_refresh_preserves_fixed_archive_pins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "dependencies").mkdir()
            (root / "dependencies/update-policy.json").write_text(json.dumps(
                {"applications": ["codex-nix"]}))
            path = root / "dependencies/mirrors.json"
            frozen = {"version": "fixed", "url": "https://nixos.mewo.eu.org/bongo.tar.xz",
                      "hash": "sha256-example"}
            path.write_text(json.dumps({"bongocat-osu": frozen, "taiko-editor": {"version": "old"}}))
            with patch.object(updater, "ROOT", root), patch.object(updater, "run"), \
                 patch.object(updater, "read_mirror_manifest", return_value=self.manifest), \
                 patch.object(sys, "argv", ["update.py", "--mirror-manifest-url", "https://example.org"]):
                updater.main()
            updated = json.loads(path.read_text())
            self.assertEqual(updated["bongocat-osu"], frozen)
            self.assertEqual(updated["taiko-editor"], self.manifest["taiko-editor"])

    def test_monitask_rejects_invalid_metadata(self):
        template = ("Package: monitask\nArchitecture: amd64\nVersion: 1.0\n"
                    "Filename: pool/monitask.deb\nSHA256: " + "a" * 64)
        for text in ("", template.replace("pool/monitask.deb", "pool/../outside.deb"),
                     template.replace("a" * 64, "broken")):
            with self.subTest(text=text), self.assertRaises(ValueError):
                updater.parse_monitask_index(text)

    def test_blender_peels_annotated_tag(self):
        refs = f"{'a' * 40}\trefs/tags/v1.0.3\n{'b' * 40}\trefs/tags/v1.0.3^{{}}\n"
        self.assertEqual(updater.resolve_tag_revision(refs, "v1.0.3"), "b" * 40)
        with self.assertRaises(ValueError):
            updater.resolve_tag_revision(refs, "v1.0.4")

    def test_blender_pins_release_revision_and_hash(self):
        response = io.BytesIO(json.dumps({"tag_name": "v1.0.3", "prerelease": False}).encode())
        refs = f"{'b' * 40}\trefs/tags/v1.0.3\n"
        fetched = json.dumps({"rev": "b" * 40, "hash": "sha256-example"})
        with patch.object(updater, "urlopen", return_value=response), \
             patch.object(updater.subprocess, "check_output", side_effect=[refs, fetched]) as command:
            result = updater.update_blender({"version": "1.0.0", "rev": "a" * 40})
        self.assertEqual(result["version"], "1.0.3")
        self.assertEqual(result["rev"], "b" * 40)
        self.assertEqual(result["hash"], "sha256-example")
        self.assertEqual(command.call_args_list[1].args[0][0], "nix-prefetch-git")

    def test_blender_unchanged_release_does_not_prefetch(self):
        response = io.BytesIO(json.dumps({"tag_name": "v1.0.3"}).encode())
        previous = {"version": "1.0.3", "rev": "b" * 40, "hash": "sha256-example"}
        with patch.object(updater, "urlopen", return_value=response), \
             patch.object(updater.subprocess, "check_output",
                          return_value=f"{'b' * 40}\trefs/tags/v1.0.3\n") as command:
            self.assertEqual(updater.update_blender(previous), previous)
        self.assertEqual(command.call_count, 1)

    def test_bootvine_pins_stable_release_source_without_building(self):
        response = io.BytesIO(json.dumps({"tag_name": "v0.1.3"}).encode())
        refs = f"{'a' * 40}\trefs/tags/v0.1.3\n{'b' * 40}\trefs/tags/v0.1.3^{{}}\n"
        fetched = json.dumps({"rev": "b" * 40, "hash": "sha256-example"})
        with patch.object(updater, "urlopen", return_value=response), \
             patch.object(updater.subprocess, "check_output", side_effect=[refs, fetched]) as command:
            result = updater.update_bootvine({})
        self.assertEqual(result["rev"], "b" * 40)
        self.assertEqual(result["url"], updater.BOOTVINE_REPOSITORY)
        self.assertEqual(command.call_args_list[1].args[0][0], "nix-prefetch-git")

    def test_bootvine_unchanged_release_keeps_the_verified_source_hash(self):
        response = io.BytesIO(json.dumps({"tag_name": "v0.1.3"}).encode())
        previous = {"version": "0.1.3", "rev": "b" * 40, "hash": "sha256-example"}
        with patch.object(updater, "urlopen", return_value=response), \
             patch.object(updater.subprocess, "check_output",
                          return_value=f"{'b' * 40}\trefs/tags/v0.1.3\n") as command:
            self.assertEqual(updater.update_bootvine(previous), previous)
        self.assertEqual(command.call_count, 1)

    def test_upstream_failure_preserves_previous_pins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "dependencies").mkdir()
            sources = {"monitask": {"version": "1"}, "blender-mcp": {"version": "1"}}
            path = root / "dependencies/upstream.json"
            path.write_text(json.dumps(sources))
            with patch.object(updater, "ROOT", root), \
                 patch.object(updater, "update_monitask", return_value={"version": "2"}), \
                 patch.object(updater, "update_blender", side_effect=ValueError("bad release")):
                with self.assertRaises(ValueError):
                    updater.update_upstream(["monitask", "blender-mcp"])
            self.assertEqual(json.loads(path.read_text()), sources)


class GitHubReleaseTest(unittest.TestCase):
    def setUp(self):
        self.spec = {"repo": "tosuapp/tosu", "asset": "tosu-linux-v{version}.zip"}
        self.release = {
            "tag_name": "v4.26.3", "draft": False, "prerelease": False,
            "assets": [{"name": "tosu-linux-v4.26.3.zip", "state": "uploaded",
                        "browser_download_url": "https://github.com/tosuapp/tosu/releases/download/v4.26.3/tosu-linux-v4.26.3.zip",
                        "digest": "sha256:" + "0" * 64}],
        }
        self.source_hash = "sha256-" + "A" * 43 + "="

    def update(self, release=None, previous=None):
        response = io.BytesIO(json.dumps(release or self.release).encode())
        with patch.object(updater, "urlopen", return_value=response), \
             patch.dict(updater.os.environ, {}, clear=True):
            return updater.update_github_release(self.spec, previous or {})

    def test_selects_linux_asset_and_records_published_checksum(self):
        self.release["assets"].insert(0, {"name": "tosu-windows-v4.26.3.zip"})
        with patch.object(updater.subprocess, "check_output") as prefetch:
            result = self.update()
        self.assertEqual(result["version"], "4.26.3")
        self.assertTrue(result["url"].endswith("/tosu-linux-v4.26.3.zip"))
        self.assertEqual(result["hash"], self.source_hash)
        prefetch.assert_not_called()

    def test_concord_constant_asset_name_and_unprefixed_tag(self):
        self.spec = {"repo": "chojs23/concord", "asset": "concord-x86_64-unknown-linux-gnu.tar.xz"}
        self.release["tag_name"] = "2.7.0"
        self.release["assets"] = [{"name": self.spec["asset"], "state": "uploaded",
                                   "browser_download_url": "https://github.com/chojs23/concord/releases/download/2.7.0/" + self.spec["asset"],
                                   "digest": "sha256:" + "0" * 64}]
        self.assertEqual(self.update()["version"], "2.7.0")

    def test_rejects_unstable_and_incomplete_releases(self):
        for field, value in (("draft", True), ("prerelease", True),
                             ("tag_name", "v4.27.0-rc1"), ("assets", [])):
            release = copy.deepcopy(self.release)
            release[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.update(release)

    def test_rejects_duplicate_assets_bad_checksums_and_wrong_urls(self):
        cases = []
        duplicate = copy.deepcopy(self.release)
        duplicate["assets"] *= 2
        cases.append(duplicate)
        for field, value in (("digest", "sha256:invalid"),
                             ("browser_download_url", "https://example.org/binary.zip"),
                             ("state", "new")):
            release = copy.deepcopy(self.release)
            release["assets"][0][field] = value
            cases.append(release)
        for release in cases:
            with self.subTest(release=release), self.assertRaises(ValueError):
                self.update(release)

    def test_prefetches_asset_without_a_published_digest(self):
        self.release["assets"][0]["digest"] = None
        with patch.object(updater.subprocess, "check_output",
                          return_value=json.dumps({"hash": self.source_hash})) as prefetch:
            result = self.update()
        self.assertEqual(result["hash"], self.source_hash)
        prefetch.assert_called_once_with(
            ["nix", "store", "prefetch-file", "--json", result["url"]], text=True)

    def test_preserves_unchanged_pin_without_a_digest(self):
        self.release["assets"][0]["digest"] = None
        previous = {"version": "4.26.3", "url": self.release["assets"][0]["browser_download_url"],
                    "hash": self.source_hash}
        with patch.object(updater.subprocess, "check_output") as prefetch:
            self.assertEqual(self.update(previous=previous), previous)
        prefetch.assert_not_called()

    def test_uses_actions_token_for_github_api_request(self):
        response = io.BytesIO(json.dumps(self.release).encode())
        with patch.dict(updater.os.environ, {"GITHUB_TOKEN": "test-token"}, clear=True), \
             patch.object(updater, "urlopen", return_value=response) as request:
            updater.update_github_release(self.spec, {})
        api_request = request.call_args.args[0]
        self.assertEqual(api_request.full_url, "https://api.github.com/repos/tosuapp/tosu/releases/latest")
        self.assertEqual(api_request.get_header("Authorization"), "Bearer test-token")

unittest.main()
