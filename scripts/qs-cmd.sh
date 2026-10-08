#!/bin/sh
# Usage: qs-cmd.sh <command>
# Commands: launcher, wallpaper, powermenu, bar, todo
sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/qs.sock"
timeout 0.1 sh -c 'printf "%s\n" "$1" | socat - UNIX-CONNECT:"$2"' sh "$1" "$sock" 2>/dev/null &
