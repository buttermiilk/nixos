#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${INVOCATION_ID:-} ]]; then
  echo "backup-and-reboot: use systemctl --user start backup-and-reboot.service" >&2
  exit 2
fi

echo "backup-and-reboot: creating a Restic snapshot"
systemd-inhibit \
  --what=sleep:shutdown \
  --mode=block \
  --why="Backing up sh1m3ji before reboot" \
  systemctl --user start --wait restic-backups-gdrive.service

echo "backup-and-reboot: backup complete; rebooting"
systemctl reboot
