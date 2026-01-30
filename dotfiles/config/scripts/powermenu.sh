#!/bin/bash

# Options
options=" Shutdown\n Reboot\n Sleep\n Logout"

# Show menu
choice=$(echo -e $options | rofi -dmenu -i  -p ""  -config ~/.config/rofi/power.rasi)

# Handle selection
case "$choice" in
" Shutdown") systemctl poweroff ;;
" Reboot") systemctl reboot ;;
" Sleep") systemctl suspend ;;
" Logout") pkill -KILL -u $USER ;;
esac
