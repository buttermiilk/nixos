#!/usr/bin/env bash
set -euo pipefail

# osu!lazer allows one instance. A second launch (a beatmap or osu:// link)
# hands its arguments to the running client and exits, so only the first
# launch starts tosu and the gamemode watcher.
if pgrep -x 'osu!' >/dev/null; then
  exec 'osu!' "$@"
fi

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/osu-lazer"
mkdir -p "$log_dir"

# The AppImage runs in its own PID namespace, so gamemoderun's preload would
# register a PID gamemoded cannot see. Register the game from out here, the
# same way osu-winello does for osu!.exe.
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

# tosu's process is named MainThread, so match its path. If osu-winello
# already started one, it serves lazer as well.
helpers=()
trap 'kill "${helpers[@]}" 2>/dev/null || true' EXIT
if ! pgrep -f '/libexec/tosu/tosu' >/dev/null; then
  tosu >"$log_dir/tosu.log" 2>&1 &
  helpers+=("$!")
fi
register_with_gamemode &
helpers+=("$!")

'osu!' "$@" || true
