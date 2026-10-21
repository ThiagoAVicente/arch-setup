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
            readonly property bool vertical: Root.BarLayout.isVertical(edge)

            // Drag state; the ghost overlay exists only while this is set
            property bool dragging: false
            // Real bar hidden: the ghost is carrying it
            property bool carried: false
            // Grip held: the bar window covers the whole screen so the pointer
            // never leaves it. Hyprland drops the press grab when the cursor
            // leaves a layer surface over a workspace that has no windows yet.
            property bool holding: false
            readonly property bool fullSurface: holding || dragging
            property rect dragFrom
            property real grabAlong: 0
            property real grabAcross: 0
            property string dropEdge: edge

            // Pill rect for an edge, in screen coordinates
            function slotRect(e) {
                const side = Root.Theme.barMarginSide
                const gap = Root.Theme.barMarginTop
                const t = barScope.barThickness
                const w = modelData.width, h = modelData.height
                switch (e) {
                case "bottom": return Qt.rect(side, h - gap - t, w - 2 * side, t)
                case "left":   return Qt.rect(gap, side, t, h - 2 * side)
                case "right":  return Qt.rect(w - gap - t, side, t, h - 2 * side)
                default:       return Qt.rect(side, gap, w - 2 * side, t)
                }
            }

            // Nearest edge, relative to the screen's shape (diagonal split)
            function edgeAt(gx, gy) {
                const w = modelData.width, h = modelData.height
                const d = { top: gy / h, bottom: (h - gy) / h, left: gx / w, right: (w - gx) / w }
                return Object.keys(d).reduce((best, e) => d[e] < d[best] ? e : best, "top")
            }

            // Pointer feed, in screen coordinates (also driven by tests)
            function dragStart(gx, gy) {
                console.info("bar-drag:", modelData.name, "start", edge, Math.round(gx), Math.round(gy))
                barScope.openPopout = ""
                const r = slotRect(edge)
                dragFrom = r
                grabAlong = vertical ? gy - r.y : gx - r.x
                grabAcross = vertical ? gx - r.x : gy - r.y
                dropEdge = edge
                carried = true
                dragging = true
            }
            function dragMove(gx, gy) {
                if (!dragging || !ghostLoader.item) return
                // Retarget only when the edge changes, so the preview fades
                // in once per slot rather than on every pointer move
                const e = edgeAt(gx, gy)
                if (e !== dropEdge) {
                    dropEdge = e
                    ghostLoader.item.targetRect = slotRect(e)
                }
                ghostLoader.item.move(gx, gy)
            }
            function dragEnd() {
                console.info("bar-drag:", modelData.name, "end", dragging, carried, !!ghostLoader.item, dropEdge)
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
            // Ghost reached the slot: show the real bar once its window has
            // actually been re-anchored and resized (the compositor answers a
            // few frames later), then drop the ghost a beat after that, so
            // there is never a frame without a bar or a half-sized one
            function landed() { settleCheck.start() }
            Timer {
                id: settleCheck
                interval: 16; repeat: true
                property int tries: 0
                onTriggered: {
                    const ready = hBar.width === perScreen.modelData.width && hBar.height === perScreen.modelData.height
                    if (ready || ++tries > 30) {
                        stop(); tries = 0
                        perScreen.carried = false
                        ghostRelease.restart()
                    }
                }
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
                    grabAlong: perScreen.grabAlong
                    grabAcross: perScreen.grabAcross
                    onLanded: perScreen.landed()
                }
            }

            // Music lip: its own surface on the layer under windows, so it
            // shows in the gap below the bar and slips behind windows.
            // Exists only while something plays.
            LazyLoader {
                active: Root.Visualizer.playing && !barScope.barHidden
                PanelWindow {
                    id: lipWin
                    screen: perScreen.modelData
                    anchors {
                        top: perScreen.edge !== "bottom"
                        bottom: perScreen.edge !== "top"
                        left: perScreen.edge !== "right"
                        right: perScreen.edge !== "left"
                    }
                    readonly property real depth: barScope.barThickness + 8 + lip.maxDepth
                    implicitWidth: perScreen.vertical ? depth : perScreen.modelData.width
                    implicitHeight: perScreen.vertical ? perScreen.modelData.height : depth
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.namespace: "qs-drawer"
                    WlrLayershell.layer: WlrLayer.Bottom
                    mask: Region {}

                    // Hangs off the pill's inner edge (same geometry as the bar)
                    MusicRipple {
                        id: lip
                        edge: perScreen.edge
                        screenName: perScreen.modelData.name
                        alongOrigin: side
                        // Out of the way while the bar is carried
                        opacity: perScreen.carried ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        readonly property int gap: Root.Theme.barMarginTop
                        readonly property int side: Root.Theme.barMarginSide
                        readonly property int t: barScope.barThickness
                        x: perScreen.edge === "left" ? gap + t : perScreen.edge === "right" ? lipWin.width - gap - t - maxDepth : side
                        y: perScreen.edge === "top" ? gap + t : perScreen.edge === "bottom" ? lipWin.height - gap - t - maxDepth : side
                        width: perScreen.vertical ? maxDepth : lipWin.width - 2 * side
                        height: perScreen.vertical ? lipWin.height - 2 * side : maxDepth
                    }
                }
            }

            PanelWindow {
                id: hBar
                screen: perScreen.modelData
                visible: !barScope.barHidden

                anchors {
                    top: perScreen.edge !== "bottom"
                    bottom: perScreen.edge !== "top"
                    left: perScreen.edge !== "right"
                    right: perScreen.edge !== "left"
                }
                // Full length along the edge even before the compositor
                // stretches it, so a re-anchor never renders a stub of a bar
                implicitWidth: perScreen.fullSurface || !perScreen.vertical ? perScreen.modelData.width : barScope.barThickness + 8
                implicitHeight: perScreen.fullSurface || perScreen.vertical ? perScreen.modelData.height : barScope.barThickness + 8
                color: "transparent"
                exclusiveZone: barScope.barThickness
                // No compositor layer anim: re-anchoring on drop must not slide
                WlrLayershell.namespace: "qs-drawer"

                onVisibleChanged: if (visible) barPill.show()

                MouseArea { anchors.fill: parent; z: -1; onClicked: barScope.openPopout = "" }

                Rectangle {
                    id: barPill
                    readonly property int gap: Root.Theme.barMarginTop
                    readonly property int side: Root.Theme.barMarginSide
                    x: perScreen.vertical ? (perScreen.edge === "right" ? parent.width - gap - width : gap) : side
                    y: perScreen.vertical ? side : (perScreen.edge === "bottom" ? parent.height - gap - height : gap)
                    width: perScreen.vertical ? barScope.barThickness : parent.width - 2 * side
                    height: perScreen.vertical ? parent.height - 2 * side : barScope.barThickness
                    radius: Math.min(width, height) / 2
                    color: Root.Theme.barBg

                    // Hidden while the ghost carries it. Opacity only: an invisible
                    // item would cancel the grip's pointer grab mid-drag
                    opacity: perScreen.carried ? 0 : reveal

                    // Slide + fade in from the screen edge when the bar is shown
                    property real reveal: 1
                    property real slide: 0
                    transform: Translate {
                        x: perScreen.edge === "left" ? -barPill.slide : perScreen.edge === "right" ? barPill.slide : 0
                        y: perScreen.edge === "top" ? -barPill.slide : perScreen.edge === "bottom" ? barPill.slide : 0
                    }
                    function show() {
                        reveal = 0
                        slide = barScope.barThickness
                        showAnim.restart()
                    }
                    Component.onCompleted: show()
                    ParallelAnimation {
                        id: showAnim
                        NumberAnimation { target: barPill; property: "reveal"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { target: barPill; property: "slide"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                    }

                    // Inset top highlight — glass depth without a second border.
                    // On a bottom bar the top is the edge the music lip hangs
                    // from, so it goes while the lip is out
                    Rectangle {
                        visible: !perScreen.vertical
                            && !(perScreen.edge === "bottom" && Root.Visualizer.playing)
                        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                        height: 1
                        color: Root.Theme.panelHi
                    }

                    // Hairline drawn separately so its inner-edge row can be
                    // clipped off while the music lip hangs there: the lip sits
                    // on a lower layer, so it can't cover the line itself, and
                    // painting over it would stack two translucent fills
                    Item {
                        readonly property int cut: Root.Visualizer.playing ? 1 : 0
                        clip: true
                        x: perScreen.edge === "right" ? cut : 0
                        y: perScreen.edge === "bottom" ? cut : 0
                        width: parent.width - (perScreen.vertical ? cut : 0)
                        height: parent.height - (perScreen.vertical ? 0 : cut)
                        Rectangle {
                            x: -parent.x
                            y: -parent.y
                            width: barPill.width
                            height: barPill.height
                            radius: barPill.radius
                            color: "transparent"
                            border.color: Root.Theme.hairline
                            border.width: 1
                        }
                    }

                    // ── Start: grip + clock ────────────────────────────────
                    GridLayout {
                        id: startGroup
                        x: perScreen.vertical ? (parent.width - width) / 2 : 6
                        y: perScreen.vertical ? 6 : (parent.height - height) / 2
                        flow: perScreen.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                        rows: perScreen.vertical ? -1 : 1
                        columns: perScreen.vertical ? 1 : -1
                        rowSpacing: 4
                        columnSpacing: 2

                        // Grip: press and drag to move the bar to another edge
                        Item {
                            id: grip
                            Layout.alignment: Qt.AlignCenter
                            implicitWidth: perScreen.vertical ? 30 : 22
                            implicitHeight: perScreen.vertical ? 22 : 30

                            GripDots {
                                anchors.centerIn: parent
                                vertical: perScreen.vertical
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
                                // This press picked the bar up (not one made while
                                // the previous drop is still landing)
                                property bool lifting: false

                                // Screen coordinates: the bar window sits flush with
                                // its edge, so its origin is known
                                function toScreen(m) {
                                    const p = mapToItem(null, m.x, m.y)
                                    const ox = perScreen.edge === "right" ? perScreen.modelData.width - hBar.width : 0
                                    const oy = perScreen.edge === "bottom" ? perScreen.modelData.height - hBar.height : 0
                                    return Qt.point(p.x + ox, p.y + oy)
                                }
                                onPressed: m => {
                                    pressX = m.x; pressY = m.y
                                    perScreen.holding = true
                                    console.info("bar-drag:", perScreen.modelData.name, "press", perScreen.dragging, perScreen.carried)
                                }
                                // The window grows to the whole screen while held,
                                // so motion keeps arriving wherever the cursor goes
                                onPositionChanged: m => {
                                    if (!pressed) return
                                    const g = toScreen(m)
                                    if (!lifting) {
                                        if (perScreen.dragging) return
                                        if (Math.hypot(m.x - pressX, m.y - pressY) < 6) return
                                        lifting = true
                                        perScreen.dragStart(g.x, g.y)
                                    }
                                    perScreen.dragMove(g.x, g.y)
                                }
                                onReleased: {
                                    if (lifting) perScreen.dragEnd()
                                    lifting = false
                                    perScreen.holding = false
                                }
                                onCanceled: {
                                    console.info("bar-drag:", perScreen.modelData.name, "canceled")
                                    if (lifting) perScreen.dragEnd()
                                    lifting = false
                                    perScreen.holding = false
                                }
                            }
                        }

                        ClockCalendarWidget {
                            Layout.alignment: Qt.AlignCenter
                            vertical: perScreen.vertical
                        }
                        NowPlayingWidget {
                            Layout.alignment: Qt.AlignCenter
                            vertical: perScreen.vertical
                        }
                    }

                    // ── Centre: workspaces ─────────────────────────────────
                    HyprlandWorkspaces {
                        anchors.centerIn: parent
                        vertical: perScreen.vertical
                    }

                    // ── End: tray, status, network, notifications ──────────
                    GridLayout {
                        x: perScreen.vertical ? (parent.width - width) / 2 : parent.width - width - 8
                        y: perScreen.vertical ? parent.height - height - 8 : (parent.height - height) / 2
                        flow: perScreen.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                        rows: perScreen.vertical ? -1 : 1
                        columns: perScreen.vertical ? 1 : -1
                        rowSpacing: 2
                        columnSpacing: 2

                        RecordingWidget { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
                        SystemTrayWidget { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
                        Item { Layout.preferredWidth: perScreen.vertical ? 1 : 10; Layout.preferredHeight: perScreen.vertical ? 10 : 1 }
                        CpuWidget { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
                        BatteryWidget { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
                        VolumeWidget { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
                        Item { Layout.preferredWidth: perScreen.vertical ? 1 : 10; Layout.preferredHeight: perScreen.vertical ? 10 : 1 }
                        NetworkWidget {
                            Layout.alignment: Qt.AlignCenter
                            vertical: perScreen.vertical
                            popoutOpen: barScope.openPopout === "network" && barScope.popoutScreen === perScreen.modelData
                            onTogglePopout: barScope.togglePopout("network", perScreen.modelData)
                        }
                        BluetoothWidget {
                            Layout.alignment: Qt.AlignCenter
                            vertical: perScreen.vertical
                            popoutOpen: barScope.openPopout === "bluetooth" && barScope.popoutScreen === perScreen.modelData
                            onTogglePopout: barScope.togglePopout("bluetooth", perScreen.modelData)
                        }
                        Item { Layout.preferredWidth: perScreen.vertical ? 1 : 10; Layout.preferredHeight: perScreen.vertical ? 10 : 1 }
                        NotificationsToggle { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
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
