#!/bin/sh
# Usage: qs-cmd.sh <command>
# Commands: launcher, wallpaper
timeout 0.1 sh -c "echo '$1' | socat - UNIX-CONNECT:/tmp/qs.sock" 2>/dev/null &
