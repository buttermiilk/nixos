#!/usr/bin/env bash
set -euo pipefail

if pgrep -x 'osu!' >/dev/null; then
  exec 'osu!' "$@"
fi

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/osu-lazer"
mkdir -p "$log_dir"

register_with_gamemode() {
  local -A registered=()
  local pid
  while true; do
    for pid in $(pgrep -x 'osu!'); do
      if [[ -z "${registered[$pid]:-}" ]]; then
        registered[$pid]=1
        gamemoded -r"$pid" >/dev/null 2>&1 || true
      fi
    done
    sleep 2
  done
}

helpers=()
trap 'kill "${helpers[@]}" 2>/dev/null || true' EXIT
if ! pgrep -f '/libexec/tosu/tosu' >/dev/null; then
  tosu >"$log_dir/tosu.log" 2>&1 &
  helpers+=("$!")
fi
register_with_gamemode &
helpers+=("$!")

'osu!' "$@" || true
