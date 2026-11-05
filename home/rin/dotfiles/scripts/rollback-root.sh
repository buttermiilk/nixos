#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${INVOCATION_ID:-} ]]; then
  echo "rollback-root: this command is only for the initrd systemd service" >&2
  exit 2
fi

mkdir -p /btrfs_tmp
mount -t btrfs -o subvolid=5 /dev/mapper/crypted /btrfs_tmp
trap 'umount /btrfs_tmp 2>/dev/null || true' EXIT

shopt -s nullglob
cache_dirs=(
  /btrfs_tmp/root/var/cache
  /btrfs_tmp/root/root/.cache
)
for user_home in /btrfs_tmp/home/*; do
  [[ -d "$user_home" && ! -L "$user_home" ]] || continue
  cache_dirs+=(
    "$user_home/.cache"
    "$user_home/.npm/_cacache"
    "$user_home/.bun/install/cache"
    "$user_home/.local/share/pnpm/store"
    "$user_home/.cargo/registry/cache"
    "$user_home/.cargo/registry/src"
    "$user_home/.cargo/git/db"
    "$user_home/.cargo/git/checkouts"
    "$user_home/Documents/osu-lazer/cache"
    "$user_home"/.var/app/*/cache
  )
done
for cache_dir in "${cache_dirs[@]}"; do
  component="$cache_dir"
  safe=1
  while [[ "$component" != /btrfs_tmp ]]; do
    if [[ -L "$component" ]]; then
      safe=0
      break
    fi
    component="${component%/*}"
  done
  if (( safe )) && [[ -d "$cache_dir" ]]; then
    find -P "$cache_dir" -xdev -mindepth 1 -delete
  fi
done

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

btrfs subvolume create /btrfs_tmp/root

while IFS= read -r -d "" old_root; do
  btrfs subvolume delete --recursive "$old_root"
done < <(find /btrfs_tmp/root.old.d -mindepth 1 -maxdepth 1 -mmin +4320 -print0)

umount /btrfs_tmp
trap - EXIT
rmdir /btrfs_tmp
