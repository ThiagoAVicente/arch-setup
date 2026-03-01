#!/bin/bash

# Toggle screen recording and notify waybar

if pgrep -x wf-recorder >/dev/null; then
  # Stop recording
  pkill -SIGINT wf-recorder
  while pgrep -x wf-recorder >/dev/null; do sleep 0.1; done
  pkill -42 waybar
else
  # Start recording
  FILENAME=~/Videos/Recordings/recording_$(date +'%Y-%m-%d_%H-%M-%S').mp4
  wf-recorder --no-dmabuf -x yuv420p -g "$(slurp)" -f "$FILENAME" &
  while ! pgrep -x wf-recorder >/dev/null; do sleep 0.1; done
  pkill -42 waybar
fi
