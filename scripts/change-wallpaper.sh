#!/bin/bash

# Set your wallpaper directory
WALL_DIR="$HOME/Pictures/Wallpapers"

IMAGES=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.gif" \))
WAL_KITTY="$HOME/.cache/wal/colors-kitty.conf"
# Extract selected path
WALLPAPER="$(echo "$IMAGES" | imv -b 000000 -i wallpaper_selector)"

echo "Selected wallpaper: $WALLPAPER"
# Apply the wallpaper if selection is valid
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
  # Check if swww daemon is running, start it if not
  if ! pgrep -x swww-daemon >/dev/null; then
    swww-daemon &
    sleep 1
  fi

  # Set wallpaper with swww
  swww img "$WALLPAPER" --transition-type grow --transition-duration 0.5
  # Generate color scheme with pywal
  wal -i "$WALLPAPER"

  # reload waybar
  pkill waybar && waybar &
  swaync-client -rs
  # Update kitty colors
  kitty @ set-colors --all --config "$WAL_KITTY"

fi
