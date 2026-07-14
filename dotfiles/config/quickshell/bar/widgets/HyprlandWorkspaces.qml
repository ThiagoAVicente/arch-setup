import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../.." as Root

Row {
    spacing: 7

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

            width: isThisMonitorActive ? 24 : (isOtherMonitorActive ? 12 : 5)
            height: 5
            anchors.verticalCenter: parent.verticalCenter

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

            // Soft halo under the active dot — the one lit element on the bar
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 10
                height: parent.height + 10
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.08)
                opacity: isThisMonitorActive ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2

                color: isThisMonitorActive
                    ? Root.Theme.barText
                    : isOtherMonitorActive
                        ? Qt.rgba(1, 1, 1, 0.6)
                        : (hasWindows ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.22))

                Behavior on color { ColorAnimation { duration: 200 } }
            }

        }
    }
}
