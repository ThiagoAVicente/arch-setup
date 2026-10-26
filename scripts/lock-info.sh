#!/bin/bash
# Text for hyprlock's labels (hypr/hyprlock.conf). Kept out of the config
# because hyprlang mangles shell syntax like ${var:-…} and the label falls
# back to "Sample Text".
case "$1" in
    greeting)
        # Full name from the account (chfn -f), else the login name
        n=$(getent passwd "$(id -un)" | cut -d: -f5 | cut -d, -f1)
        echo "welcome back, ${n:-$(id -un)}"
        ;;
    music)
        t=$(playerctl metadata --format '{{artist}} · {{title}}' 2>/dev/null)
        if [ -n "$t" ]; then echo "󰎆  ${t:0:48}"; else echo "󰎊  nothing playing"; fi
        ;;
    battery)
        b=/sys/class/power_supply/BAT0
        [ "$(cat $b/status)" = Charging ] && i=󰂄 || i=󰁹
        echo "$i  $(cat $b/capacity)%"
        ;;
esac
