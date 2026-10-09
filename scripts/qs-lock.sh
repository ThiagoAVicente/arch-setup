#!/bin/sh
# Lock the session with the quickshell bar-curtain lock.
# Falls back to hyprlock if the shell isn't there to take the request —
# an idle/suspend lock must never silently do nothing.
sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/qs.sock"

if [ -S "$sock" ] && printf 'lock\n' | timeout 1 socat - UNIX-CONNECT:"$sock" 2>/dev/null; then
  exit 0
fi

pidof hyprlock >/dev/null || exec hyprlock
