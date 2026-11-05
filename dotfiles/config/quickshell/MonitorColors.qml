pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

// A colour per monitor, so the shared workspaces 1–8 can show which monitor
// each one is on (bar/widgets/HyprlandWorkspaces.qml, bar/popouts/WorkspaceTag.qml).
// The laptop panel is white, the other monitors blue, green, … sorted by name.
Singleton {
    readonly property var order: {
        const names = Hyprland.monitors.values.map(m => m.name)
        const panel = names.filter(n => n.startsWith("eDP"))
        return panel.concat(names.filter(n => !n.startsWith("eDP")).sort())
    }
    readonly property var palette: ["#eeeef0", "#5b9cff", "#6fdc8c", "#ffa657", "#f778ba"]

    function of(name) {
        const i = order.indexOf(name)
        return palette[Math.max(0, i) % palette.length]
    }
}
