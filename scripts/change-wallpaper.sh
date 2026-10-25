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
      mpvpaper -o "no-audio --loop --hwdec=auto --vo=gpu --panscan=1.0 --scale=spline36" '*' "$WALLPAPER" &
      disown
      # Lock screen gets a still from the video
      ffmpeg -loglevel error -y -ss 1 -i "$WALLPAPER" -frames:v 1 "$HOME/.cache/lock-wallpaper-frame.jpg" \
        && ln -sfn "$HOME/.cache/lock-wallpaper-frame.jpg" "$HOME/.cache/lock-wallpaper"
      ;;
    *)
      # Static wallpaper: swww (awww) as before
      pkill -x mpvpaper
      if ! pgrep -x awww-daemon >/dev/null; then
        awww-daemon &disown
        sleep 1
      fi
      awww img "$WALLPAPER" --transition-type grow --transition-duration 0.5
      # Lock screen background (hyprlock.conf)
      ln -sfn "$WALLPAPER" "$HOME/.cache/lock-wallpaper"
      wal -i "$WALLPAPER"
      ;;
  esac

  # reload waybar
  pkill waybar && waybar &
  swaync-client -rs

fi
