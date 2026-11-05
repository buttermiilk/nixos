#!/usr/bin/env bash
set -euo pipefail

if flatpak info --user org.vinegarhq.Sober >/dev/null 2>&1; then
  exit 0
fi

flatpak remote-add --user --if-not-exists --noninteractive flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user --noninteractive --assumeyes \
  flathub org.vinegarhq.Sober
