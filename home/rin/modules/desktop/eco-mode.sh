#!/usr/bin/env bash
set -euo pipefail

requested_mode="${POWER_MODE_TARGET:-eco}"
action="${1:-toggle}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_dir="$runtime_dir/eco-mode"
brightness_file="$state_dir/brightness"
mode_file=/run/power-limit/mode
power_limit=/run/current-system/sw/bin/power-limit
brightness_cap=40

current_mode=normal
[[ ! -r "$mode_file" ]] || read -r current_mode <"$mode_file"

is_on() { [[ "$current_mode" == "$requested_mode" ]]; }

# Bar status queries must not wait for an in-progress desktop update.
if [[ "$action" == status ]]; then
  if is_on; then echo on; else echo off; fi
  exit 0
fi

# Both shortcuts share this lock so a rapid switch cannot mix desktop effects.
exec 9>"$runtime_dir/power-mode.lock"
flock 9
current_mode=normal
[[ ! -r "$mode_file" ]] || read -r current_mode <"$mode_file"

bar() {
  local eco_hook=0 performance_hook=0
  [[ "$current_mode" != eco ]] || eco_hook=1
  [[ "$current_mode" != performance ]] || performance_hook=1
  polybar-msg action eco hook "$eco_hook" >/dev/null 2>&1 || true
  polybar-msg action performance hook "$performance_hook" >/dev/null 2>&1 || true
}

ensure_compositor() {
  # Retain VSync in every power mode; also recover from older eco mode state
  # that stopped the compositor.
  pgrep -x picom >/dev/null || i3-msg -q "exec --no-startup-id picom --config $HOME/.config/picom/picom.conf"
}

restore_desktop() {
  [[ -d "$state_dir" ]] || return 0
  if [[ -r "$brightness_file" ]]; then
    brightnessctl -q set "$(cat "$brightness_file")%"
  fi
  rm -rf "$state_dir"
}

set_mode() {
  local target=$1 output current
  if ! output=$(/run/wrappers/bin/sudo -n "$power_limit" "$target" 2>&1); then
    current_mode=normal
    [[ ! -r "$mode_file" ]] || read -r current_mode <"$mode_file"
    if [[ "$current_mode" != eco ]]; then
      ensure_compositor
      restore_desktop
    fi
    bar
    notify-send -u critical "Power mode" "$output"
    printf '%s\n' "$output" >&2
    return 1
  fi
  if [[ "$target" == eco ]]; then
    mkdir -p "$state_dir"
    current=$(brightnessctl -m | cut -d, -f4 | tr -d %)
    printf '%s\n' "$current" >"$brightness_file"
    if (( current > brightness_cap )); then
      brightnessctl -q set "${brightness_cap}%"
    fi
  else
    restore_desktop
  fi
  ensure_compositor
  current_mode=$target
  bar
  case "$target" in
    eco) notify-send -u low "Eco mode" "On: quiet profile, 30 W cap, VSync retained, brightness ≤ ${brightness_cap}%" ;;
    performance) notify-send -u low "Performance mode" "On: performance profile, firmware CPU power limits restored" ;;
    normal) notify-send -u low "Power mode" "Balanced profile, 30 W cap" ;;
  esac
}

case "$action" in
  on) is_on || set_mode "$requested_mode" ;;
  off) ! is_on || set_mode normal ;;
  toggle) if is_on; then set_mode normal; else set_mode "$requested_mode"; fi ;;
  *)
    echo "usage: ${requested_mode}-mode [on|off|toggle|status]" >&2
    exit 2
    ;;
esac
