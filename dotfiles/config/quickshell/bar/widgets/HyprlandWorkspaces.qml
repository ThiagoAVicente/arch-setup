import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Root is a Grid positioner so it sizes itself from its children and the bar
// can read its implicitWidth/implicitHeight directly via the positioner bounds.
Grid {
    id: root
    spacing: 7
    // Horizontal: 8 side-by-side; Vertical: stacked in one column
    columns: root.vertical ? 1 : 8
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    property bool vertical: false

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
            property bool isOtherMonitorActive: !isThisMonitorActive && root.monitorWorkspaces[wsId] !== undefined
            property bool hasWindows: workspace !== null && workspace !== undefined && workspace.windows !== null && workspace.windows !== undefined && workspace.windows.length > 0

            // Horizontal: pill animates WIDTH (24/12/5), height fixed 5
            // Vertical:   pill animates HEIGHT (24/12/5), width fixed 5
            width:  root.vertical ? 5 : (isThisMonitorActive ? 24 : (isOtherMonitorActive ? 12 : 5))
            height: root.vertical ? (isThisMonitorActive ? 24 : (isOtherMonitorActive ? 12 : 5)) : 5

            Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

            // Soft halo under the active dot — the one lit element on the bar
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 10
                height: parent.height + 10
                radius: Math.min(width, height) / 2
                color: Qt.rgba(1, 1, 1, 0.08)
                opacity: isThisMonitorActive ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.min(width, height) / 2

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
