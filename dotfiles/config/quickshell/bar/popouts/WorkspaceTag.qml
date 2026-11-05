pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../.." as Root

// Small drawer under the middle of the bar on every monitor that is not
// focused, showing the number of the workspace that monitor shows, in the
// monitor's colour (MonitorColors.qml). The focused monitor never shows it.
// Only text, so clicks pass through. Shown over fullscreen windows too, like
// the launcher, dropping from the screen edge when no bar is showing.
PanelWindow {
    id: root

    readonly property string monitorName: screen?.name ?? ""
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === root.monitorName) ?? null
    readonly property int workspaceId: monitor?.activeWorkspace?.id ?? -1
    readonly property bool isOpen: Root.MonitorColors.order.length > 1
        && Hyprland.focusedMonitor !== null
        && Hyprland.focusedMonitor.name !== monitorName
        && workspaceId > 0
        && !Root.State.barHidden
        && !Root.BarLayout.isCentered(monitorName)

    property bool shown: false
    visible: shown
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false
    WlrLayershell.namespace: "qs-drawer"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property string barEdge: Root.BarLayout.dockEdgeOf(monitorName)
    readonly property bool barVertical: Root.BarLayout.isVertical(barEdge)
    // Spans the whole bar edge so the drawer hangs from its middle
    anchors {
        top: barVertical || barEdge === "top"
        bottom: barVertical || barEdge === "bottom"
        left: !barVertical || barEdge === "left"
        right: !barVertical || barEdge === "right"
    }
    implicitWidth: barVertical ? goo.topY + goo.fullW + 40 : 0
    implicitHeight: barVertical ? 0 : goo.topY + goo.fullH + 40
    mask: Region {}

    Root.LiquidSurface {
        id: goo
        fullW: 64
        fullH: 46
        onClosed: root.shown = false
    }

    Component.onCompleted: if (isOpen) isOpenChanged()
    onIsOpenChanged: {
        if (isOpen) {
            shown = true
            goo.fromW = 0
            goo.fromH = 0
            goo.open()
        } else {
            goo.close()
        }
    }

    Text {
        x: goo.cardX
        y: goo.cardY
        width: goo.fullW
        height: goo.fullH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: goo.contentOpacity
        text: root.workspaceId > 0 ? root.workspaceId : ""
        color: Root.MonitorColors.of(root.monitorName)
        font.family: Root.Theme.fontFamily
        font.pixelSize: 24
        font.weight: Font.Bold
    }
}
