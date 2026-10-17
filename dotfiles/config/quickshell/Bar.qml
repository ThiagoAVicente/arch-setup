pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "bar"
import "bar/widgets"
import "bar/popouts"
import "." as Root

Scope {
    id: barScope

    property string openPopout: ""
    // Screen the open popout belongs to — popouts only show on this monitor
    property var popoutScreen: null
    // Surface of the popout on screen; the next one morphs out of it
    property var popoutSurface: null
    property var popoutSurfaceScreen: null
    readonly property bool barHidden: Root.State.barHidden

    readonly property int barThickness: Root.Theme.barThickness

    function togglePopout(name, scr) {
        if (openPopout === name && popoutScreen === scr) {
            openPopout = ""
        } else {
            popoutScreen = scr
            openPopout = name
        }
    }

    function toggleBar() {
        Root.State.barHidden = !Root.State.barHidden
        openPopout = ""
    }

    // ── Bar, one per screen ────────────────────────────────────────────
    // Sits on the screen edge stored in BarLayout; the grip at its start
    // picks it up and drops it on another edge.
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            readonly property string edge: Root.BarLayout.edgeOf(modelData.name)
            readonly property bool atBottom: edge === "bottom"

            // Drag state; the ghost overlay exists only while this is set
            property bool dragging: false
            // Real bar hidden: the ghost is carrying it
            property bool carried: false
            property rect dragFrom
            property real grabX: 0
            property real grabY: 0
            property string dropEdge: edge

            // Pill rect for an edge, in screen coordinates
            function slotRect(e) {
                const side = Root.Theme.barMarginSide
                const gap = Root.Theme.barMarginTop
                const t = barScope.barThickness
                const w = modelData.width, h = modelData.height
                return e === "bottom" ? Qt.rect(side, h - gap - t, w - 2 * side, t)
                                      : Qt.rect(side, gap, w - 2 * side, t)
            }

            function edgeAt(gx, gy) {
                return gy > modelData.height / 2 ? "bottom" : "top"
            }

            // Pointer feed, in screen coordinates (also driven by tests)
            function dragStart(gx, gy) {
                barScope.openPopout = ""
                const r = slotRect(edge)
                dragFrom = r
                grabX = gx - r.x
                grabY = gy - r.y
                dropEdge = edge
                carried = true
                dragging = true
            }
            function dragMove(gx, gy) {
                if (!dragging || !ghostLoader.item) return
                dropEdge = edgeAt(gx, gy)
                ghostLoader.item.targetRect = slotRect(dropEdge)
                ghostLoader.item.move(gx, gy)
            }
            function dragEnd() {
                if (!dragging) return
                // Released before the ghost existed: just put the bar down
                if (!ghostLoader.item) {
                    Root.BarLayout.setEdge(modelData.name, dropEdge)
                    carried = false
                    dragging = false
                    return
                }
                // Re-anchor now (bar is invisible) so windows retile once,
                // while the ghost unfurls into the new slot
                Root.BarLayout.setEdge(modelData.name, dropEdge)
                ghostLoader.item.drop()
            }
            // Ghost reached the slot: show the real bar, then drop the ghost
            // a beat later so there is never a frame without a bar
            function landed() {
                carried = false
                ghostRelease.restart()
            }

            Timer {
                id: ghostRelease
                interval: 120
                onTriggered: perScreen.dragging = false
            }

            LazyLoader {
                id: ghostLoader
                active: perScreen.dragging
                BarGhost {
                    screen: perScreen.modelData
                    fromRect: perScreen.dragFrom
                    grabX: perScreen.grabX
                    grabY: perScreen.grabY
                    onLanded: perScreen.landed()
                }
            }

            PanelWindow {
                id: hBar
                screen: perScreen.modelData
                visible: !barScope.barHidden

                anchors { top: !perScreen.atBottom; bottom: perScreen.atBottom; left: true; right: true }
                implicitHeight: barScope.barThickness + 8
                color: "transparent"
                exclusiveZone: barScope.barThickness
                // No compositor layer anim: re-anchoring on drop must not slide
                WlrLayershell.namespace: "qs-drawer"

                onVisibleChanged: if (visible) barPill.show()

                MouseArea { anchors.fill: parent; z: -1; onClicked: barScope.openPopout = "" }

                Rectangle {
                    id: barPill
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: Root.Theme.barMarginSide; rightMargin: Root.Theme.barMarginSide
                    }
                    y: perScreen.atBottom ? parent.height - Root.Theme.barMarginTop - height
                                          : Root.Theme.barMarginTop
                    height: barScope.barThickness
                    radius: height / 2
                    color: Root.Theme.barBg
                    border.color: Root.Theme.hairline
                    border.width: 1

                    // Hidden while the ghost carries it. Opacity only: an invisible
                    // item would cancel the grip's pointer grab mid-drag
                    opacity: perScreen.carried ? 0 : reveal

                    // Slide + fade in from the screen edge when the bar is shown
                    property real reveal: 1
                    property real slide: 0
                    transform: Translate { y: perScreen.atBottom ? barPill.slide : -barPill.slide }
                    function show() {
                        reveal = 0
                        slide = height
                        showAnim.restart()
                    }
                    Component.onCompleted: show()
                    ParallelAnimation {
                        id: showAnim
                        NumberAnimation { target: barPill; property: "reveal"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { target: barPill; property: "slide"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                    }

                    // Inset top highlight — glass depth without a second border
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                        height: 1
                        color: Root.Theme.panelHi
                    }

                    // Grip: press and drag to move the bar to another edge
                    Item {
                        id: grip
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 6 }
                        width: 18

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f01dd}"
                            font.family: Root.Theme.fontFamily
                            font.pixelSize: 15
                            color: gripMa.containsMouse || gripMa.pressed ? Root.Theme.barAccent : Root.Theme.barMuted
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        MouseArea {
                            id: gripMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real pressX: 0
                            property real pressY: 0

                            // Screen coordinates: the bar window sits flush with
                            // its edge, so its origin is known
                            function toScreen(m) {
                                const p = mapToItem(null, m.x, m.y)
                                const oy = perScreen.atBottom ? perScreen.modelData.height - hBar.height : 0
                                return Qt.point(p.x, p.y + oy)
                            }
                            onPressed: m => { pressX = m.x; pressY = m.y }
                            // Keeps receiving motion outside the bar while held
                            onPositionChanged: m => {
                                if (!pressed) return
                                const g = toScreen(m)
                                if (!perScreen.dragging) {
                                    if (Math.hypot(m.x - pressX, m.y - pressY) < 6) return
                                    perScreen.dragStart(g.x, g.y)
                                }
                                perScreen.dragMove(g.x, g.y)
                            }
                            onReleased: perScreen.dragEnd()
                            onCanceled: perScreen.dragEnd()
                        }
                    }

                    Item {
                        anchors { left: grip.right; top: parent.top; bottom: parent.bottom; leftMargin: 2 }
                        width: hClk.implicitWidth
                        ClockCalendarWidget {
                            id: hClk
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        HyprlandWorkspaces {}
                    }

                    RowLayout {
                        anchors {
                            right: parent.right; top: parent.top; bottom: parent.bottom
                            rightMargin: 8
                        }
                        spacing: 2
                        SystemTrayWidget {}
                        Item { Layout.preferredWidth: 10 }
                        CpuWidget {}
                        BatteryWidget {}
                        VolumeWidget {}
                        Item { Layout.preferredWidth: 10 }
                        NetworkWidget {
                            popoutOpen: barScope.openPopout === "network" && barScope.popoutScreen === perScreen.modelData
                            onTogglePopout: barScope.togglePopout("network", perScreen.modelData)
                        }
                        BluetoothWidget {
                            popoutOpen: barScope.openPopout === "bluetooth" && barScope.popoutScreen === perScreen.modelData
                            onTogglePopout: barScope.togglePopout("bluetooth", perScreen.modelData)
                        }
                        Item { Layout.preferredWidth: 10 }
                        NotificationsToggle {}
                    }
                }
            }
        }
    }

    // ── Network popout (lazy) ──────────────────────────────────────────
    property bool _networkLoaded: false
    onOpenPopoutChanged: {
        if (openPopout === "network") _networkLoaded = true
        else if (openPopout === "bluetooth") _bluetoothLoaded = true
    }
    Variants {
        model: Quickshell.screens
        Loader {
            required property var modelData
            active: barScope._networkLoaded
            sourceComponent: NetworkPopout {
                screen: modelData
                isOpen: barScope.openPopout === "network" && barScope.popoutScreen === modelData
                anchorLeft: false
                hub: barScope
                onCloseRequested: barScope.openPopout = ""
            }
        }
    }

    property bool _bluetoothLoaded: false
    Variants {
        model: Quickshell.screens
        Loader {
            required property var modelData
            active: barScope._bluetoothLoaded
            sourceComponent: BluetoothPopout {
                screen: modelData
                isOpen: barScope.openPopout === "bluetooth" && barScope.popoutScreen === modelData
                anchorLeft: false
                hub: barScope
                onCloseRequested: barScope.openPopout = ""
            }
        }
    }
}
