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
Item {
    id: goo
    anchors.fill: parent

    required property int fullW
    required property int fullH
    // Seed size when replacing another drawer; 0 = drip from the bar
    property int fromW: 0
    property int fromH: 0
    // Horizontal centre of the drop; -1 = middle of the parent
    property int centerX: -1

    signal closed()

    property real revealW: 36
    property real revealH: 0
    property real wave: 0
    property real contentOpacity: 0

    // Edge of this window's screen the bar sits on; the surface grows out of
    // it. Geometry below is written for the top edge and mirrored for bottom.
    readonly property var screen: QsWindow.window?.screen ?? null
    readonly property string edge: Root.BarLayout.edgeOf(screen?.name ?? "")
    readonly property bool fromBottom: edge === "bottom"
    function sy(v) { return fromBottom ? height - v : v }

    // No bar to hang from when it's toggled off or a fullscreen window covers
    // it — then the drawer drops from the top edge of the display instead
    readonly property bool barVisible: !Root.State.barHidden
        && !((screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor)
             ?.activeWorkspace?.hasFullscreen ?? false)
    // Overlap the pill's bottom hairline by 1px so the join is seamless
    readonly property int topY: barVisible
        ? Root.Theme.barMarginTop + Root.Theme.barThickness - 1 : 0
    readonly property int cx: centerX >= 0 ? centerX : Math.round(width / 2)
    // Where callers place their content (fixed size, never scaled)
    readonly property int cardX: cx - Math.round(fullW / 2)
    readonly property int cardY: fromBottom ? height - topY - fullH : topY + 1
    readonly property bool closing: closeAnim.running || handoffAnim.running
    // Fully grown; from here on reveal follows fullW/fullH
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
    // on screen, then goes — no blank frame between the two
    function handOff(toW, toH) {
        openAnim.stop()
        morphAnim.stop()
        resizeAnim.stop()
        closeAnim.stop()
        settled = false
        contentOpacity = 0
        handoffW = toW
        handoffH = toH
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
            NumberAnimation { target: goo; property: "revealW"; to: goo.fullW; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            NumberAnimation { target: goo; property: "revealH"; to: goo.fullH; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
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
        NumberAnimation { target: goo; property: "revealW"; to: goo.fullW; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        NumberAnimation { target: goo; property: "revealH"; to: goo.fullH; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        SequentialAnimation {
            NumberAnimation { target: goo; property: "wave"; to: goo.fullH >= goo.fromH ? 34 : -34; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: goo; property: "wave"; to: goo.fullH >= goo.fromH ? -14 : 14; duration: 120; easing.type: Easing.InOutSine }
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
        if (revealW !== fullW || revealH !== fullH) resizeAnim.restart()
    }
    onFullWChanged: if (settled) resizeAnim.restart()
    onFullHChanged: if (settled) resizeAnim.restart()

    ParallelAnimation {
        id: resizeAnim
        NumberAnimation { target: goo; property: "revealW"; to: goo.fullW; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        NumberAnimation { target: goo; property: "revealH"; to: goo.fullH; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
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
            strokeColor: Root.Theme.hairline
            strokeWidth: 1
            startX: goo.leftX - goo.fillet; startY: goo.sy(goo.topY)
            PathQuad { x: goo.leftX; y: goo.sy(goo.topY + goo.fillet); controlX: goo.leftX; controlY: goo.sy(goo.topY) }
            PathLine { x: goo.leftX; y: goo.sy(goo.bottomY - goo.corner) }
            PathQuad { x: goo.leftX + goo.corner; y: goo.sy(goo.bottomY); controlX: goo.leftX; controlY: goo.sy(goo.bottomY) }
            PathQuad { x: goo.rightX - goo.corner; y: goo.sy(goo.bottomY); controlX: goo.cx; controlY: goo.sy(goo.bottomY + goo.wave) }
            PathQuad { x: goo.rightX; y: goo.sy(goo.bottomY - goo.corner); controlX: goo.rightX; controlY: goo.sy(goo.bottomY) }
            PathLine { x: goo.rightX; y: goo.sy(goo.topY + goo.fillet) }
            PathQuad { x: goo.rightX + goo.fillet; y: goo.sy(goo.topY); controlX: goo.rightX; controlY: goo.sy(goo.topY) }
        }
    }
}
