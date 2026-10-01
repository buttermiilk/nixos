#!/usr/bin/env bash
set -euo pipefail

osu_wine="$HOME/.local/bin/osu-wine"
if [[ ! -x "$osu_wine" ]]; then
  echo "osu-winello is not installed at $osu_wine" >&2
  exit 1
fi

# Wine routes every key press through XIM when XMODIFIERS points at fcitx5,
# which delays or drops taps under load. osu! does not need the IME.
unset XMODIFIERS

# gamemoderun holds the performance CPU governor for the lifetime of the game.
exec gamemoderun steam-run "$osu_wine" "$@"
