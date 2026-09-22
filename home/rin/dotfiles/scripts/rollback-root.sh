#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${INVOCATION_ID:-} ]]; then
  echo "rollback-root: this command is only for the initrd systemd service" >&2
  exit 2
fi

mkdir -p /btrfs_tmp
mount -t btrfs -o subvolid=5 /dev/mapper/crypted /btrfs_tmp
trap 'umount /btrfs_tmp 2>/dev/null || true' EXIT

# Keep recent roots outside every normally mounted subvolume. This is a
# recovery window, not a snapshot/backup policy.
mkdir -p /btrfs_tmp/root.old.d
if btrfs subvolume show /btrfs_tmp/root >/dev/null 2>&1; then
  timestamp=$(date --utc +%Y-%m-%dT%H:%M:%SZ)
  destination="/btrfs_tmp/root.old.d/$timestamp"
  suffix=0
  while [[ -e "$destination" ]]; do
    suffix=$((suffix + 1))
    destination="/btrfs_tmp/root.old.d/$timestamp-$suffix"
  done
  mv /btrfs_tmp/root "$destination"
  touch "$destination"
fi

# Create the new root before pruning archives so interrupted cleanup cannot
# leave the next boot without a root subvolume.
btrfs subvolume create /btrfs_tmp/root

while IFS= read -r -d "" old_root; do
  btrfs subvolume delete --recursive "$old_root"
done < <(find /btrfs_tmp/root.old.d -mindepth 1 -maxdepth 1 -mtime +30 -print0)

umount /btrfs_tmp
trap - EXIT
rmdir /btrfs_tmp
