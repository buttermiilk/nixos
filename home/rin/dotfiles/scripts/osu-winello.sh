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

# osu-wine subcommands (--changedir, --fixprefix, `n ...`) go straight
# through; only game launches need tosu and the client switch below.
if [[ "${1:-}" == n || ("${1:-}" == --* && "$1" != --tourney) ]]; then
  exec "$osu_wine" "$@"
fi

client_dir="$HOME/Documents/osu"
if [[ "${1:-}" == "--tourney" ]]; then
  client_dir="$HOME/Documents/osu-tourney"
  shift
fi

# Both clients share one Wine prefix. osu-wine launches whatever osupath
# names, and the prefix maps it to D: so song paths stay short. Retarget
# both per launch instead of `osu-wine --changedir`, which rewrites them for
# good and runs wineboot. While osu! is up (the tourney client is several
# osu!.exe processes), leave them alone: a beatmap or osu:// link handed to
# this wrapper then goes to the running client.
first_instance=
if ! pgrep -x 'osu!.exe' >/dev/null; then
  first_instance=1
  echo "$client_dir" >"$osuconfig/osupath"
  ln -sfn "$client_dir" "$wineprefix/dosdevices/d:"

  # osu! empties Logs/ on every start and osu-wine overwrites winello.log,
  # so relaunching after a crash used to erase the evidence. Keep the last
  # few sessions' logs.
  archive="$osuconfig/old-logs/$(date +%F_%H-%M-%S)"
  mkdir -p "$archive"
  cp -r "$client_dir/Logs" "$archive/osu-logs" 2>/dev/null || true
  cp "$osuconfig/winello.log" "$osuconfig/tosu.log" "$archive/" 2>/dev/null || true
  # Globs sort, and the timestamped names sort oldest first.
  old_logs=("$osuconfig"/old-logs/*)
  if ((${#old_logs[@]} > 5)); then
    rm -rf "${old_logs[@]:0:${#old_logs[@]}-5}"
  fi
fi

# Wine routes every key press through XIM when XMODIFIERS points at fcitx5,
# which delays or drops taps under load. osu! does not need the IME.
unset XMODIFIERS

# osu-winello's own memory-reader launcher polls with tasklist/find/ping
# inside Wine every few seconds. Each spawn goes through the single-threaded
# wineserver that osu! also needs, causing periodic input/frame hitches.
# tosu runs natively below instead, so keep that launcher from coming back.
rm -f "$(<"$osuconfig/osupath")/launch_with_memory.bat"

# osu-wine runs Wine inside the Steam Linux Runtime container, where
# gamemoderun's preloaded library cannot find libgamemode.so: only processes
# outside the container got registered, never osu! itself. Register every
# osu!.exe from out here instead (the tourney client starts several); the
# first registration applies gamemode's governor (see programs.gamemode).
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

# Opening a beatmap or osu:// link while osu! runs re-enters this wrapper and
# only hands the link over; the first instance owns tosu and the gamemode
# watcher. tosu's process is named MainThread, so match its path.
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

# Keep tosu and the gamemode watcher alive while any osu!.exe remains, e.g.
# when the client is relaunched before a crashed window has fully exited;
# the new launch then sees osu! running and starts no tosu of its own.
while pgrep -x 'osu!.exe' >/dev/null; do
  sleep 2
done
