#!/bin/bash

WALLPAPER="$1"

echo "Selected wallpaper: $WALLPAPER"
# Apply the wallpaper if selection is valid
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
  # Check if swww daemon is running, start it if not
  if ! pgrep -x awww-daemon >/dev/null; then
    awww-daemon &disown
    sleep 1
  fi

  # Set wallpaper with swww
  awww img "$WALLPAPER" --transition-type grow --transition-duration 0.5
  # Generate color scheme with pywal
  wal -i "$WALLPAPER"

  # reload waybar
  pkill waybar && waybar &
  swaync-client -rs

fi
