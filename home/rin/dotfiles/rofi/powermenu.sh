#!/usr/bin/env bash

chosen=$(printf 'Lock\nLogout\nSuspend\nBackup and reboot\nReboot\nShutdown' | rofi -dmenu -p 'power')

case "$chosen" in
  Lock)     physlock ;;
  Logout)   i3-msg exit ;;
  Suspend)  systemctl suspend ;;
  "Backup and reboot") systemctl --user start backup-and-reboot.service ;;
  Reboot)   systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
esac
