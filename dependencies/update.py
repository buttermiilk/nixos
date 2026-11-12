#!/usr/bin/env python3
"""Update the dependency catalog. Run inside nix develop .#maintenance."""

import argparse
import base64
import json
import os
from pathlib import Path
from pathlib import PurePosixPath
import re
import subprocess
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
MONITASK_REPOSITORY = "https://deskcap.blob.core.windows.net/deployment/Linux/deb/Release/"
MONITASK_INDEX = MONITASK_REPOSITORY + "dists/bionic/main/binary-amd64/Packages"
BLENDER_REPOSITORY = "https://projects.blender.org/lab/blender_mcp.git"
BLENDER_RELEASE = "https://projects.blender.org/api/v1/repos/lab/blender_mcp/releases/latest"
BOOTVINE_REPOSITORY = "https://codeberg.org/wvhulle/bootvine.git"
BOOTVINE_RELEASE = "https://codeberg.org/api/v1/repos/wvhulle/bootvine/releases/latest"


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def update_github_release(spec, previous):
    repo = spec["repo"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError(f"Invalid GitHub repository: {repo}")
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "nixConfig-dependency-updater"}
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(f"https://api.github.com/repos/{repo}/releases/latest", headers=headers)
    with urlopen(request, timeout=60) as response:
        release = json.load(response)
    tag = release["tag_name"]
    match = re.fullmatch(r"v?([0-9]+(?:\.[0-9]+)+)", tag)
    if not match or release.get("draft") or release.get("prerelease"):
        raise ValueError(f"Expected a stable GitHub release: {repo}")
    version = match[1]
    filename = spec["asset"].format(version=version, tag=tag)
    assets = [asset for asset in release["assets"] if asset["name"] == filename]
    if len(assets) != 1 or assets[0].get("state") != "uploaded":
        raise ValueError(f"Missing or ambiguous release asset: {repo}/{filename}")
    asset = assets[0]
    url = asset["browser_download_url"]
    if url != f"https://github.com/{repo}/releases/download/{tag}/{filename}":
        raise ValueError(f"Unexpected GitHub download URL: {url}")
    digest = asset.get("digest")
    if digest:
        if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
            raise ValueError(f"Invalid release asset SHA-256: {repo}/{filename}")
        source_hash = "sha256-" + base64.b64encode(bytes.fromhex(digest[7:])).decode()
    elif previous.get("version") == version and previous.get("url") == url:
        # Older GitHub assets may not publish a digest. Preserve the verified pin.
        return previous
    else:
        fetched = json.loads(subprocess.check_output(
            ["nix", "store", "prefetch-file", "--json", url], text=True,
        ))
        source_hash = fetched["hash"]
    return {"version": version, "url": url, "hash": source_hash}


def parse_monitask_index(text):
    candidates = []
    for paragraph in re.split(r"\n\s*\n", text.strip()):
        fields = dict(line.split(": ", 1) for line in paragraph.splitlines()
                      if ": " in line and not line.startswith((" ", "\t")))
        if fields.get("Package") != "monitask" or fields.get("Architecture") != "amd64":
            continue
        version, filename, checksum = (fields[key] for key in ("Version", "Filename", "SHA256"))
        if not re.fullmatch(r"[0-9][A-Za-z0-9.+:~_-]*", version):
            raise ValueError("Invalid Monitask package version")
        if (not filename.startswith("pool/") or ".." in PurePosixPath(filename).parts
                or not re.fullmatch(r"[A-Za-z0-9_./+~-]+\.deb", filename)):
            raise ValueError("Invalid Monitask package filename")
        if not re.fullmatch(r"[0-9a-fA-F]{64}", checksum):
            raise ValueError("Invalid Monitask SHA-256 checksum")
        candidates.append({
            "version": version, "url": MONITASK_REPOSITORY + filename,
            "hash": "sha256-" + base64.b64encode(bytes.fromhex(checksum)).decode(),
        })
    if not candidates:
        raise ValueError("No Monitask amd64 package found in the official index")
    return candidates


def update_monitask(previous):
    with urlopen(MONITASK_INDEX, timeout=60) as response:
        candidates = parse_monitask_index(response.read().decode())
    latest = candidates[0]
    for candidate in candidates[1:]:
        result = subprocess.run(
            ["dpkg", "--compare-versions", candidate["version"], "gt", latest["version"]],
            check=False,
        )
        if result.returncode not in (0, 1):
            raise ValueError("Cannot compare Monitask package versions")
        if result.returncode == 0:
            latest = candidate
    return latest


def resolve_tag_revision(text, tag):
    refs = dict(line.split()[::-1] for line in text.splitlines() if line.strip())
    revision = refs.get(f"refs/tags/{tag}^{{}}", refs.get(f"refs/tags/{tag}", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError(f"Missing or invalid release tag: {tag}")
    return revision


def update_blender(previous):
    with urlopen(BLENDER_RELEASE, timeout=60) as response:
        release = json.load(response)
    tag = release["tag_name"]
    match = re.fullmatch(r"v([0-9]+\.[0-9]+\.[0-9]+)", tag)
    if not match or release.get("draft") or release.get("prerelease"):
        raise ValueError("Expected a stable Blender MCP release")
    refs = subprocess.check_output(
        ["git", "ls-remote", "--tags", BLENDER_REPOSITORY,
         f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}"], text=True,
    )
    revision = resolve_tag_revision(refs, tag)
    if previous["version"] == match[1] and previous["rev"] == revision:
        return previous
    fetched = json.loads(subprocess.check_output(
        ["nix-prefetch-git", "--quiet", "--url", BLENDER_REPOSITORY, "--rev", revision],
        text=True,
    ))
    if fetched["rev"] != revision:
        raise ValueError("Prefetched Blender MCP revision differs from the release tag")
    return {"version": match[1], "url": BLENDER_REPOSITORY,
            "rev": revision, "hash": fetched["hash"]}


def update_bootvine(previous):
    request = Request(BOOTVINE_RELEASE, headers={"User-Agent": "nixConfig-dependency-updater"})
    with urlopen(request, timeout=60) as response:
        release = json.load(response)
    tag = release["tag_name"]
    match = re.fullmatch(r"v([0-9]+\.[0-9]+\.[0-9]+)", tag)
    if not match or release.get("draft") or release.get("prerelease"):
        raise ValueError("Expected a stable Bootvine release")
    refs = subprocess.check_output(
        ["git", "ls-remote", "--tags", BOOTVINE_REPOSITORY,
         f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}"], text=True,
    )
    revision = resolve_tag_revision(refs, tag)
    if previous.get("version") == match[1] and previous.get("rev") == revision:
        return previous
    fetched = json.loads(subprocess.check_output(
        ["nix-prefetch-git", "--quiet", "--url", BOOTVINE_REPOSITORY, "--rev", revision],
        text=True,
    ))
    if fetched["rev"] != revision:
        raise ValueError("Prefetched Bootvine revision differs from the release tag")
    return {"version": match[1], "url": BOOTVINE_REPOSITORY,
            "rev": revision, "hash": fetched["hash"]}


def update_upstream(names, github=None):
    path = ROOT / "dependencies/upstream.json"
    sources = json.loads(path.read_text())
    updated = dict(sources)
    handlers = {"monitask": update_monitask, "blender-mcp": update_blender,
                "bootvine": update_bootvine}
    github = github or {}
    for name in names:
        if name in github:
            updated[name] = update_github_release(github[name], sources.get(name, {}))
        else:
            updated[name] = handlers[name](sources.get(name, {}))
    if updated != sources:
        path.write_text(json.dumps(updated, indent=2) + "\n")


def read_mirror_manifest(url):
    if urlparse(url).scheme != "https":
        raise ValueError("Mirror manifest must use HTTPS")
    with urlopen(url, timeout=60) as response:
        data = json.loads(response.read(1024 * 1024))
    expected = {"taiko-editor"}
    if not isinstance(data, dict) or set(data) != expected:
        raise ValueError("Mirror manifest must contain taiko-editor")
    for name, source in data.items():
        if not isinstance(source, dict) or set(source) != {"version", "url", "hash"}:
            raise ValueError(f"Invalid mirror entry: {name}")
        if not all(isinstance(value, str) for value in source.values()):
            raise ValueError(f"Mirror fields must be strings: {name}")
        if not isinstance(source["version"], str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", source["version"]):
            raise ValueError(f"Invalid version: {name}")
        parsed = urlparse(source["url"])
        if parsed.scheme != "https" or parsed.netloc != "nixos.mewo.eu.org":
            raise ValueError(f"Unexpected package mirror: {name}")
        if not source["hash"].startswith("sha256-"):
            raise ValueError(f"Expected SHA-256 hash: {name}")
        if len(base64.b64decode(source["hash"][7:], validate=True)) != 32:
            raise ValueError(f"Invalid SHA-256 hash: {name}")
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Also update infrastructure inputs")
    parser.add_argument("--mirror-manifest-url", default=os.environ.get("MIRROR_MANIFEST_URL"))
    args = parser.parse_args()
    policy = json.loads((ROOT / "dependencies/update-policy.json").read_text())
    inputs = policy["applications"] + (policy["infrastructure"] if args.all else [])
    run("nix", "flake", "update", *inputs)
    github = policy.get("github", {})
    upstream = policy.get("upstream", []) + list(github)
    if upstream:
        update_upstream(upstream, github=github)
    if args.mirror_manifest_url:
        manifest = read_mirror_manifest(args.mirror_manifest_url)
        mirror_path = ROOT / "dependencies/mirrors.json"
        sources = json.loads(mirror_path.read_text())
        sources.update(manifest)
        mirror_path.write_text(json.dumps(sources, indent=2) + "\n")


if __name__ == "__main__":
    main()
