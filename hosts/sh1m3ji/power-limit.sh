#!/usr/bin/env bash
set -euo pipefail

action="${1:-apply}"
state_dir=/run/power-limit
zones=(/sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0)
ceiling_uw=30000000

mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock 9

constraints() {
  local zone constraint name found=0
  for zone in "${zones[@]}"; do
    [[ -d "$zone" ]] || continue
    found=1
    for constraint in 0 1; do
      name=$(<"$zone/constraint_${constraint}_name")
      case "$constraint:$name" in
        0:long_term|1:short_term) ;;
        *) echo "Unexpected RAPL constraint: $zone/$constraint ($name)" >&2; return 1 ;;
      esac
      printf '%s\n' "$zone/constraint_${constraint}_power_limit_uw"
    done
  done
  if (( ! found )); then
    echo "No Intel package RAPL interface found" >&2
    return 1
  fi
}

# Collect first so an invalid interface cannot leave a partially applied mode.
files=$(constraints)
mapfile -t limit_files <<<"$files"

save_mode() {
  printf '%s\n' "$1" >"$state_dir/mode.tmp"
  mv "$state_dir/mode.tmp" "$state_dir/mode"
}

cap() {
  local file current applied
  for file in "${limit_files[@]}"; do
    current=$(<"$file")
    if (( current > ceiling_uw )); then
      printf '%s\n' "$ceiling_uw" >"$file"
      applied=$(<"$file")
      if (( applied > ceiling_uw )); then
        echo "RAPL limit did not take effect: $file=$applied" >&2
        return 1
      fi
    fi
  done
}

baseline_file() {
  local file=$1
  printf '%s/baseline/%s-%s\n' "$state_dir" "$(basename "$(dirname "$file")")" "$(basename "$file")"
}

check_baseline() {
  local file saved value
  if [[ ! -f "$state_dir/baseline/ready" ]]; then
    echo "Firmware power limits have not been captured. Reboot once after installing this configuration." >&2
    return 1
  fi
  for file in "${limit_files[@]}"; do
    saved=$(baseline_file "$file")
    value=$(cat "$saved")
    if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value == 0 )); then
      echo "Invalid saved firmware power limit: $saved" >&2
      return 1
    fi
  done
}

restore() {
  local file value applied
  for file in "${limit_files[@]}"; do
    value=$(cat "$(baseline_file "$file")")
    printf '%s\n' "$value" >"$file"
    applied=$(<"$file")
    if [[ "$applied" != "$value" ]]; then
      echo "Firmware power limit did not restore: $file=$applied (expected $value)" >&2
      return 1
    fi
  done
}

rollback() {
  trap - ERR
  save_mode normal
  tlp balanced || true
  cap || true
  echo "Power mode change failed; returned to the normal power policy." >&2
  exit 1
}

case "$action" in
  capture)
    [[ ! -f "$state_dir/baseline/ready" ]] || exit 0
    if [[ -x /run/booted-system/sw/bin/apply-package-power-cap ]]; then
      echo "Reboot once to capture native firmware power limits."
      exit 0
    fi
    mkdir -p "$state_dir/baseline"
    for file in "${limit_files[@]}"; do
      cat "$file" >"$(baseline_file "$file")"
    done
    touch "$state_dir/baseline/ready"
    ;;
  apply)
    mode=normal
    [[ ! -r "$state_dir/mode" ]] || read -r mode <"$state_dir/mode"
    # In performance mode firmware and thermald own the limits.
    [[ "$mode" == performance ]] || cap
    ;;
  normal|eco|performance)
    if [[ "$action" == performance ]]; then
      check_baseline
    fi
    set -E
    trap rollback ERR
    case "$action" in
      performance) tlp performance; restore ;;
      normal) tlp balanced; cap ;;
      eco) tlp power-saver; cap ;;
    esac
    save_mode "$action"
    ;;
  *) echo "usage: power-limit [normal|eco|performance|apply|capture]" >&2; exit 2 ;;
esac
