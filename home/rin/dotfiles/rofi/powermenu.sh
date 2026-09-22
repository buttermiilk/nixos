#!/usr/bin/env bash
# Bound to $mod+p in the i3 config. The old dots referenced this file
# but never shipped it — minimal stand-in, restyle at will.

chosen=$(printf 'Lock\nLogout\nSuspend\nBackup and reboot\nReboot\nShutdown' | rofi -dmenu -p 'power')

case "$chosen" in
  Lock)     i3lock -c 000000 ;;
  Logout)   i3-msg exit ;;
  Suspend)  systemctl suspend ;;
  "Backup and reboot") systemctl --user start backup-and-reboot.service ;;
  Reboot)   systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
esac
