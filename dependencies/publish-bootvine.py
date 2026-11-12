#!/usr/bin/env python3
"""Build Bootvine only in GitHub Actions, publish to R2, then pin verified downloads."""

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
PUBLIC_BASE = "https://nixos.mewo.eu.org"
BUILD_EXPRESSION = """let
  flake = builtins.getFlake (toString ./.);
in flake.nixosConfigurations.sh1m3ji.pkgs.callPackage ./dependencies/builders/bootvine.nix { }
"""


def configuration(environ):
    names = ("R2_ENDPOINT", "R2_BUCKET", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
    present = [bool(environ.get(name)) for name in names]
    if not any(present):
        return None
    if not all(present):
        raise ValueError("Bootvine publishing needs R2_ENDPOINT, R2_BUCKET, and both R2 credentials")
    endpoint, bucket = environ["R2_ENDPOINT"], environ["R2_BUCKET"]
    if not re.fullmatch(r"https://[a-f0-9]{32}(?:\.(?:eu|fedramp))?\.r2\.cloudflarestorage\.com", endpoint):
        raise ValueError("R2_ENDPOINT must be the account's HTTPS R2 S3 API endpoint, without a trailing slash")
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", bucket):
        raise ValueError("Invalid R2 bucket name")
    return endpoint, bucket


def build_id(source):
    lock = json.loads((ROOT / "flake.lock").read_text())
    digest = hashlib.sha256(json.dumps(
        {"source": source, "nixpkgs": lock["nodes"]["nixpkgs"]["locked"]}, sort_keys=True,
    ).encode())
    for name in ("dependencies/builders/bootvine.nix", "dependencies/publish-bootvine.py"):
        digest.update((ROOT / name).read_bytes())
    return digest.hexdigest()


def sha256(path):
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").digest()
    return "sha256-" + base64.b64encode(digest).decode()


def archive_tree(directory, archive):
    def normalize(info):
        info.uid = info.gid = info.mtime = 0
        info.uname = info.gname = ""
        return info
    with tarfile.open(archive, "w:xz") as tar:
        for path in sorted(directory.iterdir()):
            tar.add(path, arcname=path.name, filter=normalize)


def verify_download(url, expected_hash):
    request = Request(url, headers={"User-Agent": "nixConfig-dependency-updater"})
    with urlopen(request, timeout=120) as response:
        actual = "sha256-" + base64.b64encode(hashlib.file_digest(response, "sha256").digest()).decode()
    if actual != expected_hash:
        raise ValueError("Published Bootvine download does not match the built archive")


def prepare_archives(work, source, identity):
    # A direct local invocation must never compile Bootvine on the Latitude.
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("Bootvine compilation is restricted to GitHub Actions")
    build_env = {key: value for key, value in os.environ.items()
                 if not key.startswith(("AWS_", "R2_"))}
    package = Path(subprocess.check_output(
        ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", BUILD_EXPRESSION],
        cwd=ROOT, text=True, env=build_env,
    ).strip())
    source_path = Path(subprocess.check_output(
        ["nix", "eval", "--impure", "--raw", "--expr", f"({BUILD_EXPRESSION}).src.outPath"],
        cwd=ROOT, text=True, env=build_env,
    ).strip())
    tree = work / "binary"
    tree.mkdir()
    for name in ("bin", "lib", "share"):
        shutil.copytree(package / name, tree / name)
    binary = tree / "bin/bootvine"
    binary.chmod(0o755)
    subprocess.run(["patchelf", "--remove-rpath", str(binary)], check=True)
    subprocess.run(["patchelf", "--set-interpreter", "/lib64/ld-linux-x86-64.so.2", str(binary)], check=True)
    metadata = {"source": source, "buildId": identity}
    (tree / "share/doc/bootvine").chmod(0o755)
    (tree / "share/doc/bootvine/build.json").write_text(json.dumps(metadata, indent=2) + "\n")
    name = f"bootvine-{source['version']}-{identity[:16]}-x86_64-linux"
    archive, source_archive = work / f"{name}.tar.xz", work / f"{name}-source.tar.xz"
    archive_tree(tree, archive)
    archive_tree(source_path, source_archive)
    return archive, source_archive


def publish(config, source, identity, previous):
    if previous.get("buildId") == identity:
        print("Bootvine mirror already matches its source, builder, and nixpkgs")
        return previous
    endpoint, bucket = config
    upload_env = dict(os.environ, AWS_DEFAULT_REGION="auto", AWS_EC2_METADATA_DISABLED="true",
                      AWS_REQUEST_CHECKSUM_CALCULATION="when_required",
                      AWS_RESPONSE_CHECKSUM_VALIDATION="when_required")
    with tempfile.TemporaryDirectory(prefix="bootvine-publish-") as directory:
        archive, source_archive = prepare_archives(Path(directory), source, identity)
        pins = []
        for path in (archive, source_archive):
            key = f"bootvine/{path.name}"
            checksum = sha256(path)
            subprocess.run(
                ["aws", "s3", "cp", str(path), f"s3://{bucket}/{key}", "--endpoint-url", endpoint,
                 "--region", "auto", "--only-show-errors", "--cache-control", "public,max-age=31536000,immutable"],
                env=upload_env, check=True,
            )
            url = f"{PUBLIC_BASE}/{key}"
            verify_download(url, checksum)
            pins.append((url, checksum))
    return {"version": source["version"], "rev": source["rev"], "buildId": identity,
            "url": pins[0][0], "hash": pins[0][1],
            "sourceUrl": pins[1][0], "sourceHash": pins[1][1]}


def main():
    config = configuration(os.environ)
    if config is None:
        print("Bootvine publishing is not configured; leaving its mirror pin unchanged")
        return
    source = json.loads((ROOT / "dependencies/upstream.json").read_text())["bootvine"]
    path = ROOT / "dependencies/mirrors.json"
    mirrors = json.loads(path.read_text())
    previous = mirrors.get("bootvine", {})
    updated = publish(config, source, build_id(source), previous)
    if updated != previous:
        mirrors["bootvine"] = updated
        path.write_text(json.dumps(mirrors, indent=2) + "\n")
        print("Pinned verified Bootvine binary and matching source archives")


if __name__ == "__main__":
    main()
