#!/usr/bin/env bash
set -euo pipefail

# Aggressive battery saving: TLP's power-saver profile (no turbo, EPP power,
# low-power platform profile), no compositor, and a brightness cap.
# The marker lives in the runtime dir, so it resets on reboot just like TLP.

action="${1:-toggle}"
state_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/eco-mode"
brightness_file="$state_dir/brightness"
tlp=/run/current-system/sw/bin/tlp
brightness_cap=40

is_on() { [[ -d "$state_dir" ]]; }

bar() { polybar-msg action eco hook "$1" >/dev/null 2>&1 || true; }

on_ac() {
  local supply
  for supply in /sys/class/power_supply/*; do
    [[ "$(cat "$supply/type" 2>/dev/null)" == Mains ]] || continue
    [[ "$(cat "$supply/online" 2>/dev/null)" == 1 ]] && return 0
  done
  return 1
}

enable() {
  mkdir -p "$state_dir"
  /run/wrappers/bin/sudo "$tlp" power-saver >/dev/null
  pkill -x picom || true

  current=$(brightnessctl -m | cut -d, -f4 | tr -d %)
  echo "$current" >"$brightness_file"
  if ((current > brightness_cap)); then
    brightnessctl -q set "${brightness_cap}%"
  fi

  bar 1
  notify-send -u low "Eco mode" "On: power-saver, no compositor, brightness ≤ ${brightness_cap}%"
}

disable() {
  if on_ac; then
    /run/wrappers/bin/sudo "$tlp" performance >/dev/null
  else
    /run/wrappers/bin/sudo "$tlp" balanced >/dev/null
  fi
  pgrep -x picom >/dev/null || i3-msg -q "exec --no-startup-id picom --config $HOME/.config/picom/picom.conf"

  if [[ -r "$brightness_file" ]]; then
    brightnessctl -q set "$(cat "$brightness_file")%"
  fi
  rm -rf "$state_dir"

  bar 0
  notify-send -u low "Eco mode" "Off"
}

case "$action" in
  on) is_on || enable ;;
  off) ! is_on || disable ;;
  toggle) if is_on; then disable; else enable; fi ;;
  status) if is_on; then echo on; else echo off; fi ;;
  *)
    echo "usage: eco-mode [on|off|toggle|status]" >&2
    exit 2
    ;;
esac
