pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import "bar"
import "bar/widgets"
import "bar/popouts"
import "." as Root

Scope {
    id: barScope

    property string openPopout: ""
    // Screen the open popout belongs to. Popouts only show on this monitor
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
            // Dropped in the middle of the screen: a round widget on the
            // desktop, under the windows of every workspace
            readonly property bool centered: edge === "center"
            readonly property int circleSize: 240

            // Drag state; the ghost overlay exists only while this is set
            property bool dragging: false
            // Real bar hidden: the ghost is carrying it
            property bool carried: false
            // Grip held: the bar window covers the whole screen so the pointer
            // never leaves it. Hyprland drops the press grab when the cursor
            // leaves a layer surface over a workspace that has no windows yet.
            property bool holding: false
            // Ghost has unfurled into the new slot: the bar window shrinks back
            // to bar size while the ghost still covers it
            property bool landing: false
            readonly property bool fullSurface: holding || (dragging && !landing)
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
                case "center": return Qt.rect((w - circleSize) / 2, (h - circleSize) / 2, circleSize, circleSize)
                default:       return Qt.rect(side, gap, w - 2 * side, t)
                }
            }

            // Nearest edge, relative to the screen's shape (diagonal split);
            // the middle of the screen is the round widget's slot
            function edgeAt(gx, gy) {
                const w = modelData.width, h = modelData.height
                if (Math.abs(gx - w / 2) < w * 0.18 && Math.abs(gy - h / 2) < h * 0.22) return "center"
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
                // Lifted off the round widget: carry it by the pill's grip end
                if (centered) {
                    grabAlong = 14
                    grabAcross = barScope.barThickness / 2
                }
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
            // Ghost reached the slot: shrink the bar window to its final size
            // under the ghost, show the real bar once the compositor has
            // resized it (a few frames later), then drop the ghost a couple of
            // frames after that. Resizing only after the ghost left showed a
            // frame with no bar at all
            function landed() {
                landing = true
                settleCheck.start()
            }
            Timer {
                id: settleCheck
                interval: 16; repeat: true
                property int tries: 0
                onTriggered: {
                    const win = perScreen.centered ? cBarLoader.item : hBar
                    const ready = win && win.width === win.implicitWidth && win.height === win.implicitHeight
                    if (ready || ++tries > 30) {
                        stop(); tries = 0
                        perScreen.carried = false
                        ghostRelease.restart()
                    }
                }
            }

            Timer {
                id: ghostRelease
                interval: 50
                onTriggered: {
                    perScreen.dragging = false
                    perScreen.landing = false
                }
            }

            LazyLoader {
                id: ghostLoader
                active: perScreen.dragging
                BarGhost {
                    screen: perScreen.modelData
                    fromRect: perScreen.dragFrom
                    thickness: barScope.barThickness
                    grabAlong: perScreen.grabAlong
                    grabAcross: perScreen.grabAcross
                    onLanded: perScreen.landed()
                }
            }

            PanelWindow {
                id: hBar
                screen: perScreen.modelData
                visible: !barScope.barHidden && !perScreen.centered

                anchors {
                    top: perScreen.edge !== "bottom"
                    bottom: perScreen.edge !== "top"
                    left: perScreen.edge !== "right"
                    right: perScreen.edge !== "left"
                }
                // Full length along the edge even before the compositor
                // stretches it, so a re-anchor never renders a stub of a bar
                // Across: the pill with the wave's room on both sides
                readonly property int depth: barScope.barThickness + 2 * Root.Theme.barWaveRoom
                implicitWidth: perScreen.fullSurface || !perScreen.vertical ? perScreen.modelData.width : depth
                implicitHeight: perScreen.fullSurface || perScreen.vertical ? perScreen.modelData.height : depth
                color: "transparent"
                // Windows start just past the wave's reach (plus Hyprland's gap)
                exclusiveZone: depth - 10
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

                    // Music wave around both long sides, under the pill
                    MusicRipple {
                        z: -1
                        edge: perScreen.edge
                        screenName: perScreen.modelData.name
                        alongOrigin: barPill.side
                        x: -room
                        y: -room
                        width: barPill.width + 2 * room
                        height: barPill.height + 2 * room
                    }
                    // Its rim and glow, over the pill (and its contents, which
                    // stay clear of the edges)
                    MusicRipple {
                        z: 100
                        layerMode: 1
                        edge: perScreen.edge
                        screenName: perScreen.modelData.name
                        alongOrigin: barPill.side
                        x: -room
                        y: -room
                        width: barPill.width + 2 * room
                        height: barPill.height + 2 * room
                    }

                    // Inset top highlight for glass depth without a second border.
                    // Goes while the wave is out, its rim takes that edge
                    Rectangle {
                        visible: !perScreen.vertical && !Root.Visualizer.playing
                        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                        height: 1
                        color: Root.Theme.panelHi
                    }

                    // Hairline drawn separately so its long-side rows can be
                    // clipped off while the music wave is out: the wave sits
                    // under the pill, so it can't cover the line itself, and
                    // its rim takes over just outside. Only the stretch the
                    // wave spans (MusicRipple's inset) is cut, so the rounded
                    // ends stay whole and meet the rim
                    Repeater {
                        model: 3
                        Item {
                            required property int index
                            readonly property int inset: 17
                            readonly property int len: perScreen.vertical ? barPill.height : barPill.width
                            // Along the bar: start and length of this stretch
                            readonly property int a: index === 0 ? 0 : index === 1 ? inset : len - inset
                            readonly property int l: index === 1 ? len - 2 * inset : inset
                            readonly property int cut: index === 1 && Root.Visualizer.playing ? Root.Theme.barBorderWidth : 0
                            clip: true
                            x: perScreen.vertical ? cut : a
                            y: perScreen.vertical ? a : cut
                            width: perScreen.vertical ? barPill.width - 2 * cut : l
                            height: perScreen.vertical ? l : barPill.height - 2 * cut
                            Rectangle {
                                x: -parent.x
                                y: -parent.y
                                width: barPill.width
                                height: barPill.height
                                radius: barPill.radius
                                color: "transparent"
                                border.color: Root.Theme.barBorder
                                border.width: Root.Theme.barBorderWidth
                            }
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
                        AccentButton { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
                        NotificationsToggle { Layout.alignment: Qt.AlignCenter; vertical: perScreen.vertical }
                    }
                }
            }

            // ── Round widget in the middle of the screen ───────────────────
            // The bar dropped in the middle: a dial on the desktop layer,
            // behind the windows of every workspace. Reserves no space; its
            // music wave runs all the way round. Drag its grip to an edge to
            // turn it back into the bar.
            // Built only while the bar is in the middle, so the edge bar
            // doesn't carry a second set of widgets around
            LazyLoader {
                id: cBarLoader
                active: perScreen.centered
                PanelWindow {
                    id: cBar
                    screen: perScreen.modelData
                    visible: !barScope.barHidden

                    // No anchors: the compositor centres it. While held it covers
                    // the screen so the pointer never leaves it
                    anchors {
                        top: perScreen.fullSurface
                        bottom: perScreen.fullSurface
                        left: perScreen.fullSurface
                        right: perScreen.fullSurface
                    }
                    readonly property int box: perScreen.circleSize + 2 * Root.Theme.barWaveRoom
                    implicitWidth: perScreen.fullSurface ? perScreen.modelData.width : box
                    implicitHeight: perScreen.fullSurface ? perScreen.modelData.height : box
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.namespace: "qs-drawer"
                    WlrLayershell.layer: WlrLayer.Bottom

                    readonly property bool shown: !perScreen.carried
                    // Input only over the dial, except while held: then the whole
                    // screen, or pointer motion stops once it leaves the dial and
                    // the drop never moves off the middle
                    property Region dialRegion: Region { item: dial }
                    property Region screenRegion: Region { item: cBarArea }
                    mask: perScreen.fullSurface ? screenRegion : dialRegion

                    Item { id: cBarArea; anchors.fill: parent }

                    Rectangle {
                        id: dial
                        anchors.centerIn: parent
                        width: perScreen.circleSize
                        height: perScreen.circleSize
                        radius: width / 2
                        color: Root.Theme.barBg
                        // The wave's rim takes the border's place while it plays
                        border.color: Root.Theme.barBorder
                        border.width: Root.Visualizer.playing ? 0 : Root.Theme.barBorderWidth

                        opacity: cBar.shown ? 1 : 0
                        scale: cBar.shown ? 1 : 0.92
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        MusicRipple {
                            z: -1
                            edge: "center"
                            screenName: perScreen.modelData.name
                            x: -room
                            y: -room
                            width: dial.width + 2 * room
                            height: dial.height + 2 * room
                        }
                        MusicRipple {
                            z: 100
                            layerMode: 1
                            edge: "center"
                            screenName: perScreen.modelData.name
                            x: -room
                            y: -room
                            width: dial.width + 2 * room
                            height: dial.height + 2 * room
                        }

                        // Grip: drag to an edge to make it the bar again
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 16
                            implicitWidth: 30
                            implicitHeight: 22
                            width: implicitWidth
                            height: implicitHeight

                            GripDots {
                                anchors.centerIn: parent
                                vertical: false
                                color: cGripMa.containsMouse || cGripMa.pressed ? Root.Theme.barAccent : Root.Theme.barMuted
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            MouseArea {
                                id: cGripMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property real pressX: 0
                                property real pressY: 0
                                property bool lifting: false

                                // Screen coordinates: the window is centred, or
                                // covers the screen while held
                                function toScreen(m) {
                                    const p = mapToItem(null, m.x, m.y)
                                    return Qt.point(p.x + (perScreen.modelData.width - cBar.width) / 2,
                                                    p.y + (perScreen.modelData.height - cBar.height) / 2)
                                }
                                onPressed: m => {
                                    pressX = m.x; pressY = m.y
                                    perScreen.holding = true
                                }
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
                                    if (lifting) perScreen.dragEnd()
                                    lifting = false
                                    perScreen.holding = false
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 6
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatTime(dialClock.date, "HH:mm")
                                color: Root.Theme.barText
                                font.family: Root.Theme.fontFamily
                                font.pixelSize: 46
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDate(dialClock.date, "ddd, dd MMM")
                                color: Root.Theme.barMuted
                                font.family: Root.Theme.fontFamily
                                font.pixelSize: 13
                            }
                            NowPlayingWidget {
                                anchors.horizontalCenter: parent.horizontalCenter
                                maxWidth: 150
                                lead: 0
                            }
                            HyprlandWorkspaces {
                                anchors.horizontalCenter: parent.horizontalCenter
                                vertical: false
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                BatteryWidget { vertical: false }
                                VolumeWidget { vertical: false }
                                NetworkWidget {
                                    vertical: false
                                    popoutOpen: barScope.openPopout === "network" && barScope.popoutScreen === perScreen.modelData
                                    onTogglePopout: barScope.togglePopout("network", perScreen.modelData)
                                }
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                AccentButton { vertical: false }
                                NotificationsToggle { vertical: false }
                            }
                        }

                        // Tray icons round the rim, alternating left and right
                        // from the top down
                        Item {
                            id: dialTray
                            anchors.fill: parent
                            property var iconCache: ({})
                            readonly property var angles: [-32, -12, 8, 28]
                            readonly property var items: SystemTray.items.values
                                .filter(i => !["nm-applet", "blueman"].includes(i?.id ?? ""))
                                .slice(0, 2 * angles.length)

                            Repeater {
                                model: dialTray.items
                                TrayItem {
                                    required property int index
                                    iconCache: dialTray.iconCache
                                    barEdge: "top"
                                    readonly property real phi: dialTray.angles[Math.floor(index / 2)] * Math.PI / 180
                                    readonly property int side: index % 2 ? 1 : -1
                                    readonly property real rr: dial.width / 2 - 16
                                    x: dial.width / 2 + side * rr * Math.cos(phi) - width / 2
                                    y: dial.height / 2 + rr * Math.sin(phi) - height / 2
                                }
                            }
                        }

                        SystemClock {
                            id: dialClock
                            precision: SystemClock.Minutes
                        }
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
