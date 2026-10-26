import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Workspaces 1–8 as a strip of marks:
// Each monitor has its own 1–8 (laptop panel ids 1–8, other monitors 11–18,
// 21–28, …, same mapping as hypr/parts/monitor_ws.lua), so the strip only
// shows this monitor's block, numbered 1–8.
//   this monitor's workspace → lit pill
//   has windows              → solid dot
//   empty                    → faint small dot
// Right after a switch on this monitor the shown workspace carries its
// number for a moment, then settles back. Hovering numbers every mark.
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
    // Whether this monitor has focus: its current workspace pill is lit only then
    readonly property bool monitorFocused: Hyprland.focusedMonitor?.name === thisMonitor
    // First workspace id minus one for this monitor's block
    readonly property int offset: {
        if (thisMonitor === "" || thisMonitor.startsWith("eDP")) return 0
        const names = Hyprland.monitors.values.map(m => m.name).filter(n => !n.startsWith("eDP")).sort()
        const i = names.indexOf(thisMonitor)
        return i < 0 ? 10 : (i + 1) * 10
    }
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
            readonly property int wsId: root.offset + index + 1
            readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === wsId)
            readonly property string shownOn: root.monitorWorkspaces[wsId] ?? ""
            readonly property bool isHere: shownOn !== "" && shownOn === root.thisMonitor
            // The other monitors have their own blocks; nothing of theirs shows here
            readonly property bool isElsewhere: false
            readonly property bool hasWindows: (workspace?.toplevels?.values?.length ?? 0) > 0
            readonly property bool showNumber: root.numbered || (root.flashing && (isHere || isElsewhere))

            // Long side runs along the bar
            readonly property real len: isHere ? 28 : showNumber ? 16 : isElsewhere ? 12 : hasWindows ? 7 : 5
            readonly property real thick: showNumber ? 16 : isHere || isElsewhere ? 8 : hasWindows ? 7 : 5
            width: root.vertical ? thick : len
            height: root.vertical ? len : thick

            Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

            // Soft halo under this monitor's workspace, the one lit element on the bar
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                radius: Math.min(width, height) / 2
                color: Qt.rgba(1, 1, 1, 0.08)
                opacity: slot.isHere && root.monitorFocused ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.min(width, height) / 2

                color: slot.isHere
                    ? (root.monitorFocused ? Root.Theme.barText : Qt.rgba(1, 1, 1, 0.45))
                    : slot.isElsewhere
                        ? Qt.rgba(1, 1, 1, 0.55)
                        : slot.hasWindows
                            ? Qt.rgba(1, 1, 1, slot.showNumber ? 0.32 : 0.7)
                            : Qt.rgba(1, 1, 1, slot.showNumber ? 0.1 : 0.22)

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                anchors.centerIn: parent
                text: slot.index + 1
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
