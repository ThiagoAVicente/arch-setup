#!/usr/bin/env bash
# Toggle between awww-daemon and fogwall

if pgrep -x awww-daemon >/dev/null; then
  pkill -x awww-daemon
  "$HOME/.local/bin/fogwall" --color "#a0c8ff" &
  disown
  disown
else
  pkill -x fogwall
  awww-daemon &
  disown
fi
