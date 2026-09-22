#!/usr/bin/env bash
set -euo pipefail

action="${1:-toggle}"
runtime_root="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
runtime_dir="$runtime_root/inhibit-clicker"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/inhibit-clicker"
pid_file="$runtime_dir/pid"
lock_file="$runtime_dir/lock"
log_file="$state_dir/inhibit-clicker.log"
click_interval="${INHIBIT_CLICK_INTERVAL:-0.05}"

mkdir -p "$runtime_dir" "$state_dir"

notify() {
  notify-send "Inhibit clicker" "$1" >/dev/null 2>&1 || true
}

is_running() {
  [[ -s "$pid_file" ]] || return 1

  read -r clicker_pid clicker_start <"$pid_file" || return 1
  [[ "$clicker_pid" =~ ^[0-9]+$ && "$clicker_start" =~ ^[0-9]+$ ]] || return 1
  [[ -r "/proc/$clicker_pid/stat" ]] || return 1

  current_start=$(awk '{ print $22 }' "/proc/$clicker_pid/stat") || return 1
  [[ "$current_start" == "$clicker_start" ]]
}

stop_clicker() {
  if ! is_running; then
    rm -f "$pid_file"
    notify "Already stopped"
    return
  fi

  # systemd-inhibit and the input loop share a dedicated process group.
  kill -TERM -- "-$clicker_pid" 2>/dev/null || kill -TERM "$clicker_pid" 2>/dev/null || true

  for _ in {1..20}; do
    if ! kill -0 "$clicker_pid" 2>/dev/null; then
      break
    fi
    sleep 0.05
  done

  if kill -0 "$clicker_pid" 2>/dev/null; then
    kill -KILL -- "-$clicker_pid" 2>/dev/null || true
  fi

  rm -f "$pid_file"
  notify "Stopped"
}

start_clicker() {
  if is_running; then
    notify "Already running"
    return
  fi

  rm -f "$pid_file"
  setsid systemd-inhibit \
    --what=idle:sleep \
    --mode=block \
    --who="inhibit-clicker" \
    --why="Automated mouse clicks are active" \
    "$0" run >>"$log_file" 2>&1 9>&- &
  clicker_pid=$!

  for _ in {1..10}; do
    if [[ -r "/proc/$clicker_pid/stat" ]]; then
      break
    fi
    sleep 0.01
  done

  if [[ ! -r "/proc/$clicker_pid/stat" ]]; then
    notify "Failed to start; see $log_file"
    return 1
  fi

  clicker_start=$(awk '{ print $22 }' "/proc/$clicker_pid/stat")
  printf '%s %s\n' "$clicker_pid" "$clicker_start" >"$pid_file"

  sleep 0.1
  if ! is_running; then
    rm -f "$pid_file"
    notify "Failed to start; see $log_file"
    return 1
  fi

  notify "Started: 10 clicks/s, 5% chance of W"
}

run_clicker() {
  trap 'exit 0' HUP INT TERM

  # Give the toggle chord time to be fully released before synthesizing input.
  sleep 0.15
  while true; do
    # click does not reposition the pointer; it uses its current location.
    xdotool click --clearmodifiers 1 || exit 1
    if ((RANDOM % 100 < 5)); then
      xdotool key --clearmodifiers w || exit 1
    fi
    sleep "$click_interval"
  done
}

case "$action" in
  toggle | start | stop)
    exec 9>"$lock_file"
    flock -x 9

    case "$action" in
      toggle)
        if is_running; then
          stop_clicker
        else
          start_clicker
        fi
        ;;
      start) start_clicker ;;
      stop) stop_clicker ;;
    esac
    ;;
  run) run_clicker ;;
  *)
    echo "usage: inhibit-clicker [toggle|start|stop]" >&2
    exit 2
    ;;
esac
