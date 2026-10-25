#!/bin/sh
# Start quickshell with only the EGL driver of the GPU driving the laptop
# panel. glvnd otherwise loads both vendors, and Mesa alone costs ~40MB of
# LLVM/gallium inside quickshell. Picking the wrong one leaves the bar blank,
# so ask the hardware: in Discrete mode the panel hangs off the NVIDIA card,
# in Switchable mode off the Intel one.
vendor=/usr/share/glvnd/egl_vendor.d
# Both cards list an eDP connector; only the one wired to the panel in the
# current mode is connected (and card numbers shift between boots)
driver=
for panel in /sys/class/drm/card*-eDP-*; do
    [ "$(cat "$panel/status" 2>/dev/null)" = connected ] || continue
    driver=$(basename "$(readlink -f "$panel/../device/driver")")
    break
done
# Mesa unless NVIDIA drives the panel: loading NVIDIA's EGL opens the card
# and keeps it from runtime-suspending in Switchable/UMA mode
if [ "$driver" = nvidia ]; then
    export __EGL_VENDOR_LIBRARY_FILENAMES="$vendor/10_nvidia.json"
else
    export __EGL_VENDOR_LIBRARY_FILENAMES="$vendor/50_mesa.json"
fi
pkill -x quickshell
exec quickshell -d "$@"
