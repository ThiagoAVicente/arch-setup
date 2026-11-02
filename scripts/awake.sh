#!/bin/sh
# Keep the PC awake: no lock, no screen off, no suspend, not even on closing
# the lid, for as long as this runs. hypridle honours logind inhibitors.
#   awake             until Ctrl+C
#   awake <command>   while the command runs, e.g. awake steamcmd ...
if [ $# -eq 0 ]; then
    echo "Staying awake. Ctrl+C to allow locking again."
    set -- sleep infinity
fi
exec systemd-inhibit --what=idle:sleep:handle-lid-switch \
    --who=awake --why="Kept awake from a terminal" "$@"
