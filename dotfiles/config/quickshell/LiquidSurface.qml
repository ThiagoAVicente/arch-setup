import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import "." as Root

// Drawer surface fused to the bar pill. Opening drips a drop out of the
// bar's bottom edge and spreads it into the card with an overshoot while the
// bottom edge ripples; closing drains it back. With fromW/fromH set it
// instead morphs from another drawer's size (launcher <-> todo swap).
// Once open, size changes (content-sized popouts) glide to the new size.
// Collapsed state is the default, since drawers are rebuilt on every open.
// Geometry is worked out in the bar's frame, "along" the edge and "depth"
// away from it (revealW/revealH, fromW/fromH), then mapped to the screen
// edge the bar sits on. fullW/fullH are the card's on-screen size.
Item {
    id: goo
    anchors.fill: parent

    required property int fullW
    required property int fullH
    // Seed size when replacing another drawer; 0 = drip from the bar
    property int fromW: 0
    property int fromH: 0
    // Centre of the drop along the edge; -1 = middle of the parent
    property int centerX: -1
    // Where this window starts along the edge, in screen px (popouts are
    // small windows; drawers cover the screen and leave it at 0)
    property real alongOffset: 0

    signal closed()

    // Tell the bar's music lip where this surface meets the bar, so it parts
    // around it instead of showing through
    readonly property string holeKey: "surface-" + Math.random().toString(36).slice(2)
    readonly property var hole: barVisible && revealH > 0.5
        ? { screen: screen?.name ?? "", c: alongOffset + cx, half: revealW / 2 + fillet }
        : null
    onHoleChanged: Root.State.setHole(holeKey, hole)
    Component.onDestruction: Root.State.setHole(holeKey, null)

    property real revealW: 36
    property real revealH: 0
    property real wave: 0
    property real contentOpacity: 0

    // Edge of this window's screen the bar sits on; the surface grows out of it
    readonly property var screen: QsWindow.window?.screen ?? null
    readonly property string edge: Root.BarLayout.dockEdgeOf(screen?.name ?? "")
    readonly property bool vertical: Root.BarLayout.isVertical(edge)
    readonly property int alongFull: vertical ? fullH : fullW
    readonly property int depthFull: vertical ? fullW : fullH
    // Bar frame (u along the edge, v away from it) -> window coordinates
    function px(u, v) { return edge === "left" ? v : edge === "right" ? width - v : u }
    function py(u, v) { return edge === "bottom" ? height - v : vertical ? u : v }

    // No bar to hang from when it's toggled off or a fullscreen window covers
    // it, and then the drawer drops from that edge of the display instead
    // A centred bar is a widget in the middle of the screen, nothing to
    // hang from: drop from the screen edge as if the bar were hidden
    readonly property bool barVisible: !Root.State.barHidden && !Root.BarLayout.isCentered(screen?.name ?? "")
        && !((screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor)
             ?.activeWorkspace?.hasFullscreen ?? false)
    // Overlap the pill's bottom hairline by 1px so the join is seamless
    readonly property int topY: barVisible
        ? Root.Theme.barMarginTop + Root.Theme.barThickness - 1 : 0
    readonly property int cx: centerX >= 0 ? centerX : Math.round((vertical ? height : width) / 2)
    // Where callers place their content (fixed size, never scaled)
    readonly property int cardX: edge === "left" ? topY + 1
        : edge === "right" ? width - topY - fullW
        : cx - Math.round(fullW / 2)
    readonly property int cardY: edge === "bottom" ? height - topY - fullH
        : vertical ? cx - Math.round(fullH / 2)
        : topY + 1
    readonly property bool closing: closeAnim.running || handoffAnim.running
    // Fully grown; from here on reveal follows the card size
    property bool settled: false

    readonly property real leftX: cx - revealW / 2
    readonly property real rightX: cx + revealW / 2
    readonly property real bottomY: topY + revealH
    readonly property real fillet: barVisible ? Math.min(18, revealH / 2) : 0
    readonly property real corner: Math.min(14, revealH / 2, revealW / 2)

    function open() {
        closeAnim.stop()
        handoffAnim.stop()
        resizeAnim.stop()
        settled = false
        contentOpacity = 0
        if (fromW > 0 && fromH > 0) {
            revealW = fromW
            revealH = fromH
            morphAnim.restart()
        } else {
            openAnim.restart()
        }
    }

    // Another drawer takes over: it morphs from this one's shape, so this
    // one tracks the same shape (content hidden) until the new window is
    // on screen, then goes, so there is no blank frame between the two
    function handOff(toW, toH) {
        openAnim.stop()
        morphAnim.stop()
        resizeAnim.stop()
        closeAnim.stop()
        settled = false
        contentOpacity = 0
        // Screen size of the incoming card, in this bar's frame
        handoffW = vertical ? toH : toW
        handoffH = vertical ? toW : toH
        handoffFromH = revealH
        handoffAnim.restart()
    }
    property int handoffW: 0
    property int handoffH: 0
    property real handoffFromH: 0

    function close() {
        if (closeAnim.running || handoffAnim.running) return
        openAnim.stop()
        morphAnim.stop()
        resizeAnim.stop()
        settled = false
        closeAnim.start()
    }

    SequentialAnimation {
        id: openAnim
        // drip
        ParallelAnimation {
            NumberAnimation { target: goo; property: "revealH"; to: 40; duration: 80; easing.type: Easing.OutQuad }
            NumberAnimation { target: goo; property: "revealW"; to: 60; duration: 80; easing.type: Easing.OutQuad }
            NumberAnimation { target: goo; property: "wave"; to: 22; duration: 80; easing.type: Easing.OutQuad }
        }
        // spread + ripple
        ParallelAnimation {
            NumberAnimation { target: goo; property: "revealW"; to: goo.alongFull; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            NumberAnimation { target: goo; property: "revealH"; to: goo.depthFull; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
            SequentialAnimation {
                NumberAnimation { target: goo; property: "wave"; to: 50;  duration: 100; easing.type: Easing.OutQuad }
                NumberAnimation { target: goo; property: "wave"; to: -20; duration: 130; easing.type: Easing.InOutSine }
                NumberAnimation { target: goo; property: "wave"; to: 6;   duration: 100; easing.type: Easing.InOutSine }
                NumberAnimation { target: goo; property: "wave"; to: 0;   duration: 80;  easing.type: Easing.OutSine }
            }
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { target: goo; property: "contentOpacity"; to: 1; duration: 130; easing.type: Easing.OutCubic }
            }
        }
        ScriptAction { script: goo.settle() }
    }

    // Reshape from the previous drawer's size; the edge sloshes the way it moved
    ParallelAnimation {
        id: morphAnim
        NumberAnimation { target: goo; property: "revealW"; to: goo.alongFull; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        NumberAnimation { target: goo; property: "revealH"; to: goo.depthFull; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        SequentialAnimation {
            NumberAnimation { target: goo; property: "wave"; to: goo.depthFull >= goo.fromH ? 34 : -34; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: goo; property: "wave"; to: goo.depthFull >= goo.fromH ? -14 : 14; duration: 120; easing.type: Easing.InOutSine }
            NumberAnimation { target: goo; property: "wave"; to: 0; duration: 90; easing.type: Easing.OutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 110 }
            NumberAnimation { target: goo; property: "contentOpacity"; to: 1; duration: 130; easing.type: Easing.OutCubic }
        }
        onFinished: goo.settle()
    }

    // Content grew or shrank after opening (list loaded, tab switched)
    function settle() {
        settled = true
        if (revealW !== alongFull || revealH !== depthFull) resizeAnim.restart()
    }
    onAlongFullChanged: if (settled) resizeAnim.restart()
    onDepthFullChanged: if (settled) resizeAnim.restart()

    ParallelAnimation {
        id: resizeAnim
        NumberAnimation { target: goo; property: "revealW"; to: goo.alongFull; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        NumberAnimation { target: goo; property: "revealH"; to: goo.depthFull; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    // Same curve as morphAnim so both surfaces stay in register
    ParallelAnimation {
        id: handoffAnim
        NumberAnimation { target: goo; property: "revealW"; to: goo.handoffW; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        NumberAnimation { target: goo; property: "revealH"; to: goo.handoffH; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        SequentialAnimation {
            NumberAnimation { target: goo; property: "wave"; to: goo.handoffH >= goo.handoffFromH ? 34 : -34; duration: 90; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 30 }
            ScriptAction { script: goo.closed() }
        }
    }

    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: goo; property: "contentOpacity"; to: 0; duration: 50 }
        ParallelAnimation {
            NumberAnimation { target: goo; property: "revealH"; to: 0;  duration: 170; easing.type: Easing.InCubic }
            NumberAnimation { target: goo; property: "revealW"; to: 36; duration: 170; easing.type: Easing.InCubic }
            SequentialAnimation {
                NumberAnimation { target: goo; property: "wave"; to: -24; duration: 85; easing.type: Easing.OutQuad }
                NumberAnimation { target: goo; property: "wave"; to: 0;   duration: 85; easing.type: Easing.InQuad }
            }
        }
        ScriptAction { script: goo.closed() }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: goo.revealH > 0.5

        // Path is left open along the top so the hairline isn't drawn
        // across the join with the bar
        ShapePath {
            fillColor: Root.Theme.barBg
            strokeColor: Root.Theme.barBorder
            strokeWidth: Root.Theme.barBorderWidth
            startX: goo.px(goo.leftX - goo.fillet, goo.topY); startY: goo.py(goo.leftX - goo.fillet, goo.topY)
            PathQuad {
                x: goo.px(goo.leftX, goo.topY + goo.fillet); y: goo.py(goo.leftX, goo.topY + goo.fillet)
                controlX: goo.px(goo.leftX, goo.topY); controlY: goo.py(goo.leftX, goo.topY)
            }
            PathLine { x: goo.px(goo.leftX, goo.bottomY - goo.corner); y: goo.py(goo.leftX, goo.bottomY - goo.corner) }
            PathQuad {
                x: goo.px(goo.leftX + goo.corner, goo.bottomY); y: goo.py(goo.leftX + goo.corner, goo.bottomY)
                controlX: goo.px(goo.leftX, goo.bottomY); controlY: goo.py(goo.leftX, goo.bottomY)
            }
            PathQuad {
                x: goo.px(goo.rightX - goo.corner, goo.bottomY); y: goo.py(goo.rightX - goo.corner, goo.bottomY)
                controlX: goo.px(goo.cx, goo.bottomY + goo.wave); controlY: goo.py(goo.cx, goo.bottomY + goo.wave)
            }
            PathQuad {
                x: goo.px(goo.rightX, goo.bottomY - goo.corner); y: goo.py(goo.rightX, goo.bottomY - goo.corner)
                controlX: goo.px(goo.rightX, goo.bottomY); controlY: goo.py(goo.rightX, goo.bottomY)
            }
            PathLine { x: goo.px(goo.rightX, goo.topY + goo.fillet); y: goo.py(goo.rightX, goo.topY + goo.fillet) }
            PathQuad {
                x: goo.px(goo.rightX + goo.fillet, goo.topY); y: goo.py(goo.rightX + goo.fillet, goo.topY)
                controlX: goo.px(goo.rightX, goo.topY); controlY: goo.py(goo.rightX, goo.topY)
            }
        }
    }
}
