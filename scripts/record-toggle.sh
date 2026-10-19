#!/bin/bash

# Toggle screen recording and tell the quickshell bar (recording indicator)

if pgrep -x wf-recorder >/dev/null; then
  # Stop recording
  pkill -SIGINT wf-recorder
  while pgrep -x wf-recorder >/dev/null; do sleep 0.1; done
  "$HOME/scripts/qs-cmd.sh" recording
else
  # Start recording
  FILENAME=~/Videos/Recordings/recording_$(date +'%Y-%m-%d_%H-%M-%S').mp4
  # Capture system audio (games, videos) from the current output's monitor
  wf-recorder --no-dmabuf -x yuv420p -g "$(slurp)" \
    --audio="$(pactl get-default-sink).monitor" -f "$FILENAME" &
  while ! pgrep -x wf-recorder >/dev/null; do sleep 0.1; done
  "$HOME/scripts/qs-cmd.sh" recording
fi
