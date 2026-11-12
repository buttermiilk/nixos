#!/usr/bin/env python3
"""Merge declarative defaults with private Codex state and local trust globs."""

import argparse
from collections.abc import Mapping
from copy import deepcopy
import fcntl
import glob
import json
import os
from pathlib import Path
import tempfile

import tomlkit


def write_private(path, text):
    descriptor, temporary = tempfile.mkstemp(prefix=".codex-config-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as output:
            output.write(text)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def matching_directories(patterns):
    for pattern in patterns:
        pattern = os.path.expanduser(pattern)
        if not Path(pattern).is_absolute():
            raise ValueError("Codex trust globs must be absolute paths or start with ~")
        anchor = Path(pattern).anchor
        for component in Path(pattern).parts[1:]:
            if glob.has_magic(component):
                break
            anchor = str(Path(anchor) / component)
        anchor = Path(anchor).resolve()
        for match in sorted(glob.iglob(pattern)):
            path = Path(match)
            if not path.is_dir():
                continue
            try:
                resolved = path.resolve()
            except (OSError, RuntimeError):
                continue
            if resolved.is_relative_to(anchor):
                yield resolved


def merge_defaults(local, defaults):
    result = deepcopy(local)
    for key, value in defaults.items():
        if isinstance(value, Mapping) and isinstance(result.get(key), Mapping):
            result[key] = merge_defaults(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result


def sync_config(home, base, patterns, capture=False):
    home.mkdir(mode=0o700, parents=True, exist_ok=True)
    target = home / "config.toml"
    migration = home / ".config-home-manager-migration.toml"
    lock_descriptor = os.open(home / ".config-sync.lock", os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(lock_descriptor, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if capture:
            if target.exists():
                write_private(migration, target.read_text())
            return

        source = target if target.exists() else migration
        previous = source.read_text() if source.exists() else ""
        local = tomlkit.parse(previous)
        defaults = tomlkit.parse(base.read_text())
        # Local trust decisions, including explicit denials, take precedence.
        public_projects = defaults.pop("projects", {})
        merged = merge_defaults(local, defaults)
        projects = merged.setdefault("projects", tomlkit.table())
        for path, settings in public_projects.items():
            projects.setdefault(path, deepcopy(settings))
        for path in matching_directories(patterns):
            projects.setdefault(str(path), tomlkit.table()).setdefault("trust_level", "trusted")

        rendered = tomlkit.dumps(merged)
        if not target.exists() or target.is_symlink() or target.read_text() != rendered:
            write_private(target, rendered)
        else:
            target.chmod(0o600)
        migration.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    sync_config(args.home, args.base, json.loads(args.policy.read_text()), args.capture)


if __name__ == "__main__":
    main()
