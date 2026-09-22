#!/usr/bin/env bash
set -euo pipefail

osu_wine="$HOME/.local/bin/osu-wine"
if [[ ! -x "$osu_wine" ]]; then
  echo "osu-winello is not installed at $osu_wine" >&2
  exit 1
fi

exec steam-run "$osu_wine" "$@"
