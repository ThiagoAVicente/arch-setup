import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../.." as Root

// GridLayout with flow switched at runtime so a single Repeater handles both
// orientations without duplicating Process/Loader instances per item.
GridLayout {
    id: root
    // Horizontal: left-to-right row; Vertical: top-to-bottom column
    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    columnSpacing: 4
    rowSpacing: 4

    property bool vertical: false
    property var iconCache: ({})
    // Full edge string: "top" | "bottom" | "left" | "right"
    readonly property string barEdge: Root.BarLayout.dockEdgeOf(QsWindow.window?.screen?.name ?? "")

    Repeater {
        model: SystemTray.items

        TrayItem {
            iconCache: root.iconCache
            barEdge: root.barEdge
        }
    }
}
