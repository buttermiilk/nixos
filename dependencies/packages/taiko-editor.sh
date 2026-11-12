#!/usr/bin/env bash
set -euo pipefail

: "${TAIKO_EDITOR_JAVA:?}"
: "${TAIKO_EDITOR_LIBRARY_PATH:?}"
: "${TAIKO_EDITOR_PAYLOAD:?}"
: "${TAIKO_EDITOR_VERSION:?}"

osu_dir="${TAIKO_EDITOR_OSU_PATH:-$HOME/Documents/osu}"
state_dir="${XDG_DATA_HOME:-$HOME/.local/share}/taiko-editor"
runtime_lib="$state_dir/lib"
runtime_jar="$runtime_lib/desktop-1.0.jar"
packaged_version="$runtime_lib/.nix-package-version"

mkdir -p "$runtime_lib/update/alchyr" "$state_dir/settings"

if [[ ! -f "$packaged_version" ]] || [[ "$(<"$packaged_version")" != "$TAIKO_EDITOR_VERSION" ]]; then
  install -m0644 "$TAIKO_EDITOR_PAYLOAD/lib/desktop-1.0.jar" "$runtime_jar"
  install -m0644 \
    "$TAIKO_EDITOR_PAYLOAD/lib/update/alchyr/Updater.class" \
    "$runtime_lib/update/alchyr/Updater.class"
  printf '%s\n' "$TAIKO_EDITOR_VERSION" >"$packaged_version"
fi

if [[ ! -f "$state_dir/settings/config.cfg" ]]; then
  printf '%s\n' \
    false \
    960 \
    640 \
    "$osu_dir" \
    1 \
    120 \
    true \
    >"$state_dir/settings/config.cfg"
fi

export LD_LIBRARY_PATH="$TAIKO_EDITOR_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$state_dir"
exec "$TAIKO_EDITOR_JAVA" -jar "$runtime_jar" "$@"
