#!/bin/bash

# Path to a lock file to track state
STATE_FILE="/tmp/gammastep_on"

if pgrep -x "gammastep" > /dev/null; then
    # Gammastep is running, turn it off
    pkill gammastep
    rm -f "$STATE_FILE"
else
    # Gammastep is not running, turn it on with custom temperature
    gammastep -O 4500 &
    touch "$STATE_FILE"
fi
