#!/bin/bash

WALLPAPER="$1"

echo "Selected wallpaper: $WALLPAPER"
# Apply the wallpaper if selection is valid
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
  case "${WALLPAPER,,}" in
    *.mp4|*.mkv|*.webm|*.mov|*.gif)
      # Video wallpaper: mpvpaper decodes on GPU, no swww running underneath
      pkill -x mpvpaper
      pkill -x awww-daemon
      mpvpaper -o "no-audio --loop --hwdec=auto --vo=gpu --panscan=1.0" '*' "$WALLPAPER" &
      disown
      ;;
    *)
      # Static wallpaper: swww (awww) as before
      pkill -x mpvpaper
      if ! pgrep -x awww-daemon >/dev/null; then
        awww-daemon &disown
        sleep 1
      fi
      awww img "$WALLPAPER" --transition-type grow --transition-duration 0.5
      wal -i "$WALLPAPER"
      ;;
  esac

  # reload waybar
  pkill waybar && waybar &
  swaync-client -rs

fi
