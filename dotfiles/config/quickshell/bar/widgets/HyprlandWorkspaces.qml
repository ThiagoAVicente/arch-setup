import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Row {
    spacing: 5

    // Collect which workspace is focused on each monitor
    property var monitorWorkspaces: {
        let map = {}
        for (let m of Hyprland.monitors.values) {
            if (m.activeWorkspace) map[m.activeWorkspace.id] = m.name
        }
        return map
    }

    property string thisMonitor: {
        for (let m of Hyprland.monitors.values) {
            if (m.focused) return m.name
        }
        return ""
    }

    Repeater {
        model: 8

        Item {
            required property int index
            property int wsId: index + 1
            property var workspace: Hyprland.workspaces.values.find(w => w.id === wsId)
            property bool isThisMonitorActive: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace !== undefined && Hyprland.focusedWorkspace.id === wsId
            property bool isOtherMonitorActive: !isThisMonitorActive && monitorWorkspaces[wsId] !== undefined
            property bool hasWindows: workspace !== null && workspace !== undefined && workspace.windows !== null && workspace.windows !== undefined && workspace.windows.length > 0

            width: isThisMonitorActive ? 28 : (isOtherMonitorActive ? 14 : (hasWindows ? 10 : 6))
            height: 6

            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: height / 2

                color: isThisMonitorActive
                    ? Qt.rgba(1, 1, 1, 0.9)
                    : isOtherMonitorActive
                        ? Qt.rgba(0.4, 0.7, 1, 0.85)
                        : (hasWindows ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.15))

                Behavior on color { ColorAnimation { duration: 180 } }
            }

        }
    }
}
