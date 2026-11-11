import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Workspaces 1–8 as a strip of marks. They are shared by all monitors (see
// hypr/parts/workspaces.lua), so every bar shows all eight, each in the
// colour of the monitor it is on: the laptop panel white, the other monitors
// blue, green, … (sorted by name). With more than one monitor a line in this
// monitor's own colour runs along the strip, as the key.
//   shown on this monitor    → long lit pill
//   shown on another monitor → shorter pill in that monitor's colour
//   has windows              → solid dot in its monitor's colour
//   empty                    → faint small dot
// Right after a switch on this monitor the shown workspaces carry their
// numbers for a moment, then settle back. Hovering numbers every mark.
// Root is a Grid positioner so it sizes itself from its children and the bar
// can read its implicitWidth/implicitHeight directly via the positioner bounds.
Grid {
    id: root
    spacing: 4
    // The key line sits above the strip, or beside it on a vertical bar
    columns: root.vertical ? 2 : 1
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    property bool vertical: false

    // Monitor this bar sits on
    readonly property string thisMonitor: QsWindow.window?.screen?.name ?? ""
    // Whether this monitor has focus: its current workspace pill is lit only then
    readonly property bool monitorFocused: Hyprland.focusedMonitor?.name === thisMonitor

    // Colour of each monitor (MonitorColors.qml)
    function monitorColor(name) { return Root.MonitorColors.of(name) }
    readonly property color hereColor: monitorColor(thisMonitor)

    // Workspace id to the monitor showing it right now
    readonly property var shownOn: {
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

    // This monitor's colour, only worth showing with more than one monitor
    Rectangle {
        visible: Root.MonitorColors.order.length > 1
        width: root.vertical ? 2 : strip.width
        height: root.vertical ? strip.height : 2
        radius: 1
        color: root.hereColor
        opacity: root.monitorFocused ? 0.9 : 0.5
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Grid {
        id: strip
        spacing: 6
        // Horizontal: 8 side-by-side; Vertical: stacked in one column
        columns: root.vertical ? 1 : 8
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: 8

            Item {
                id: slot
                required property int index
                readonly property int wsId: index + 1
                readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === wsId)
                readonly property string monitor: root.shownOn[wsId] ?? workspace?.monitor?.name ?? ""
                readonly property color tint: root.monitorColor(monitor)
                readonly property bool isHere: root.shownOn[wsId] === root.thisMonitor
                readonly property bool isElsewhere: !isHere && (root.shownOn[wsId] ?? "") !== ""
                readonly property bool hasWindows: (workspace?.toplevels?.values?.length ?? 0) > 0
                readonly property bool showNumber: root.numbered || (root.flashing && (isHere || isElsewhere))

                // Long side runs along the bar
                readonly property real len: isHere ? 28 : showNumber ? 16 : isElsewhere ? 14 : hasWindows ? 7 : 5
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
                    color: Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, 0.1)
                    opacity: slot.isHere && root.monitorFocused ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(width, height) / 2

                    color: {
                        const t = slot.tint
                        if (slot.isHere) return Qt.rgba(t.r, t.g, t.b, root.monitorFocused ? 1 : 0.5)
                        if (slot.isElsewhere) return Qt.rgba(t.r, t.g, t.b, 0.75)
                        if (slot.hasWindows) return Qt.rgba(t.r, t.g, t.b, slot.showNumber ? 0.32 : 0.7)
                        return Qt.rgba(Root.Theme.barText.r, Root.Theme.barText.g, Root.Theme.barText.b, slot.showNumber ? 0.1 : 0.22)
                    }

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
}
