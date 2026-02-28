#!/bin/bash

# Toggle screen recording and notify waybar

if pgrep -x wf-recorder >/dev/null; then
  # Stop recording
  pkill -SIGINT wf-recorder
  pkill -RTMIN+8 waybar
else
  # Start recording
  FILENAME=~/Videos/Recordings/recording_$(date +'%Y-%m-%d_%H-%M-%S').mp4
  wf-recorder --no-dmabuf -x yuv420p -g "$(slurp)" -f "$FILENAME" &
  sleep 0.5
  pkill -RTMIN+8 waybar
fi
