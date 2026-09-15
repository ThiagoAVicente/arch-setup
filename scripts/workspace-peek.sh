#!/usr/bin/env bash
#
# Usage: workspace-peek-live.sh <workspace_id_or_name>
#
# Moves an inactive workspace onto a headless (virtual) output so Hyprland
# actually renders it, then opens a live mirror window (continuous
# screencopy, not a single frame) so you can watch it update in real time.
# When you close the mirror window, the workspace is moved back to wherever
# it came from and the headless output is destroyed.
#
# Requires: wl-mirror, jq

set -euo pipefail

WS="${1:?Usage: $0 <workspace_id_or_name>}"

# Always create a fresh headless output and tear it down on exit (even on
# Ctrl-C or wl-mirror crashing), so nothing lingers between runs.
hyprctl output create headless
sleep 0.2
HEADLESS=$(hyprctl -j monitors | jq -r '.[] | select(.name | test("HEADLESS")) | .name' | head -n1)

cleanup() {
  hyprctl output remove "$HEADLESS" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Remember which workspace was active where, so we can put everything back.
ORIG_MONITOR=$(hyprctl -j workspaces |
  jq -r --arg ws "$WS" '.[] | select((.id|tostring)==$ws or .name==$ws) | .monitor')
FOCUSED_MONITOR=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')

# hl.dsp.workspace.move only reassigns which monitor "owns" a workspace; it
# does NOT make the target monitor actually display it unless the workspace
# was already the active one on its old monitor (see moveWorkspaceToMonitor
# in Compositor.cpp). Since we're peeking at an inactive workspace, we have
# to briefly focus the headless output and switch its active workspace
# there instead, then focus back — this never touches the real monitor.
hyprctl repl "return hl.dispatch(hl.dsp.focus({monitor=\"$HEADLESS\"}))" >/dev/null
hyprctl repl "return hl.dispatch(hl.dsp.focus({workspace=\"$WS\", on_current_monitor=true}))" >/dev/null
hyprctl repl "return hl.dispatch(hl.dsp.focus({monitor=\"$FOCUSED_MONITOR\"}))" >/dev/null

# Live mirror: this keeps requesting screencopy frames and updating the
# window until you close it. That's the "real time" part grim can't do.
wl-mirror "$HEADLESS"

# Mirror window closed -> put the workspace back where it was.
# (cleanup trap removes the headless output below.)
if [[ -n "$ORIG_MONITOR" && "$ORIG_MONITOR" != "$HEADLESS" ]]; then
  hyprctl repl "return hl.dispatch(hl.dsp.workspace.move({workspace=\"$WS\", monitor=\"$ORIG_MONITOR\"}))" >/dev/null
fi
