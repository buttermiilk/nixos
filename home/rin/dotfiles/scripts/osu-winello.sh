#!/usr/bin/env bash
set -euo pipefail

osu_wine="$HOME/.local/bin/osu-wine"
if [[ ! -x "$osu_wine" ]]; then
  echo "osu-winello is not installed at $osu_wine" >&2
  exit 1
fi

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
osuconfig="$data_home/osuconfig"
wineprefix="$data_home/wineprefixes/osu-wineprefix"

if [[ "${1:-}" == n || ("${1:-}" == --* && "$1" != --tourney) ]]; then
  exec "$osu_wine" "$@"
fi

client_dir="$HOME/Documents/osu"
if [[ "${1:-}" == "--tourney" ]]; then
  client_dir="$HOME/Documents/osu-tourney"
  shift
fi

first_instance=
if ! pgrep -x 'osu!.exe' >/dev/null; then
  first_instance=1
  echo "$client_dir" >"$osuconfig/osupath"
  ln -sfn "$client_dir" "$wineprefix/dosdevices/d:"

  archive="$osuconfig/old-logs/$(date +%F_%H-%M-%S)"
  mkdir -p "$archive"
  cp -r "$client_dir/Logs" "$archive/osu-logs" 2>/dev/null || true
  cp "$osuconfig/winello.log" "$osuconfig/tosu.log" "$archive/" 2>/dev/null || true
  old_logs=("$osuconfig"/old-logs/*)
  if ((${#old_logs[@]} > 5)); then
    rm -rf "${old_logs[@]:0:${#old_logs[@]}-5}"
  fi
fi

unset XMODIFIERS

rm -f "$(<"$osuconfig/osupath")/launch_with_memory.bat"

register_with_gamemode() {
  local -A registered=()
  local pid
  while true; do
    for pid in $(pgrep -x 'osu!.exe'); do
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
if [[ -n "$first_instance" ]]; then
  if ! pgrep -f '/libexec/tosu/tosu' >/dev/null; then
    tosu >"$osuconfig/tosu.log" 2>&1 &
    helpers+=("$!")
  fi
  register_with_gamemode &
  helpers+=("$!")
fi

steam-run "$osu_wine" "$@" || true

while pgrep -x 'osu!.exe' >/dev/null; do
  sleep 2
done
