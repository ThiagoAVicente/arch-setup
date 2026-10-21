import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Workspaces 1–8 as a strip of marks:
//   this monitor's workspace → lit pill
//   the other monitor's      → dimmer short pill
//   has windows              → solid dot
//   empty                    → faint small dot
// Right after a switch on this monitor the two shown workspaces carry their
// numbers for a moment, then settle back. Hovering numbers every mark.
// Root is a Grid positioner so it sizes itself from its children and the bar
// can read its implicitWidth/implicitHeight directly via the positioner bounds.
Grid {
    id: root
    spacing: 6
    // Horizontal: 8 side-by-side; Vertical: stacked in one column
    columns: root.vertical ? 1 : 8
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    property bool vertical: false

    // Monitor this bar sits on, and the workspace each monitor shows
    readonly property string thisMonitor: QsWindow.window?.screen?.name ?? ""
    property var monitorWorkspaces: {
        let map = {}
        for (let m of Hyprland.monitors.values) {
            if (m.activeWorkspace) map[m.activeWorkspace.id] = m.name
        }
        return map
    }

    HoverHandler { id: hover }
    readonly property bool numbered: hover.hovered

    // Flash the numbers when this monitor changes workspace
    readonly property int hereId: Hyprland.monitors.values.find(m => m.name === root.thisMonitor)?.activeWorkspace?.id ?? -1
    property bool flashing: false
    onHereIdChanged: { flashing = true; flashTimer.restart() }
    Timer { id: flashTimer; interval: 1500; onTriggered: root.flashing = false }

    Repeater {
        model: 8

        Item {
            id: slot
            required property int index
            readonly property int wsId: index + 1
            readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === wsId)
            readonly property string shownOn: root.monitorWorkspaces[wsId] ?? ""
            readonly property bool isHere: shownOn !== "" && shownOn === root.thisMonitor
            readonly property bool isElsewhere: shownOn !== "" && !isHere
            readonly property bool hasWindows: (workspace?.toplevels?.values?.length ?? 0) > 0
            readonly property bool showNumber: root.numbered || (root.flashing && (isHere || isElsewhere))

            // Long side runs along the bar
            readonly property real len: isHere ? 28 : showNumber ? 16 : isElsewhere ? 12 : hasWindows ? 7 : 5
            readonly property real thick: showNumber ? 16 : isHere || isElsewhere ? 8 : hasWindows ? 7 : 5
            width: root.vertical ? thick : len
            height: root.vertical ? len : thick

            Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

            // Soft halo under this monitor's workspace — the one lit element on the bar
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                radius: Math.min(width, height) / 2
                color: Qt.rgba(1, 1, 1, 0.08)
                opacity: slot.isHere ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.min(width, height) / 2

                color: slot.isHere
                    ? Root.Theme.barText
                    : slot.isElsewhere
                        ? Qt.rgba(1, 1, 1, 0.55)
                        : slot.hasWindows
                            ? Qt.rgba(1, 1, 1, slot.showNumber ? 0.32 : 0.7)
                            : Qt.rgba(1, 1, 1, slot.showNumber ? 0.1 : 0.22)

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                anchors.centerIn: parent
                text: slot.wsId
                font.family: Root.Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Bold
                color: slot.isHere || slot.isElsewhere ? Root.Theme.panelSolid
                    : slot.hasWindows ? Root.Theme.barText : Root.Theme.barMuted
                opacity: slot.showNumber ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }
}
