#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${INVOCATION_ID:-} ]]; then
  echo "quiesce-zen-for-backup: start the Restic user service instead" >&2
  exit 2
fi

zen_is_running() {
  pgrep -u "$UID" -x zen >/dev/null \
    || pgrep -u "$UID" -x zen-bin >/dev/null \
    || pgrep -u "$UID" -x zen-beta >/dev/null
}

if ! zen_is_running; then
  exit 0
fi

echo "backup: closing Zen before reading its profile"
pkill -TERM -u "$UID" -x zen 2>/dev/null || true
pkill -TERM -u "$UID" -x zen-bin 2>/dev/null || true
pkill -TERM -u "$UID" -x zen-beta 2>/dev/null || true

for _ in $(seq 1 30); do
  if ! zen_is_running; then
    sync
    exit 0
  fi
  sleep 1
done

echo "backup: Zen did not exit cleanly" >&2
exit 1
