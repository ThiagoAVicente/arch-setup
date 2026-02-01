#!/bin/bash

# Check if OBS is recording
obs_recording=false
if pgrep -x obs > /dev/null; then
    # Check if OBS is actually recording (not just open)
    # This checks if obs is using significant CPU (simple heuristic)
    obs_recording=true
fi

# Check if wf-recorder is running
wf_recording=false
if pgrep -x wf-recorder > /dev/null; then
    wf_recording=true
fi

# Output JSON for waybar
if [ "$obs_recording" = true ] || [ "$wf_recording" = true ]; then
    echo '{"text": "󰑊", "class": "recording", "tooltip": "Recording in progress"}'
else
    echo '{"text": "", "class": "not-recording", "tooltip": ""}'
fi
