#!/bin/bash
chosen=$(printf "󰐥  shutdown\n󰜉  reboot\n󰤄  sleep\n󰍃  logout" | rofi -dmenu \
    -p "" \
    -theme-str '
        window { width: 200px; }
        listview { lines: 4; fixed-height: true; }
        element { padding: 10px 14px; }
    ')

case "$chosen" in
    *shutdown) systemctl poweroff ;;
    *reboot)   systemctl reboot ;;
    *sleep)    systemctl suspend ;;
    *logout)   pkill -KILL -u "$(whoami)" ;;
esac
