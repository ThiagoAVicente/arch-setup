import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../" as Root

// The bar while it is being dragged. Exists only during a drag: a
// full-screen, input-less overlay where the lifted pill springs after the
// cursor, swings with its speed, turns to match the edge it's heading for
// and previews the slot it will drop into.
PanelWindow {
    id: ghost

    // Pill rect at pickup, in screen coordinates
    required property rect fromRect
    // Cursor offset inside the pill at pickup, along and across the bar,
    // kept under the cursor whichever way the pill is turned
    required property real grabAlong
    required property real grabAcross
    // Slot the pill drops into if released now
    property rect targetRect: fromRect

    signal landed()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Same as the bar: no blur, no compositor layer anim
    WlrLayershell.namespace: "qs-drawer"
    WlrLayershell.layer: WlrLayer.Overlay
    // Pointer stays with the bar's grip (implicit grab), never this window
    mask: Region {}

    // Across the pill; the round widget hands in the bar's thickness
    property real thickness: Math.min(fromRect.width, fromRect.height)
    // Length of the pill while carried
    readonly property real carriedLen: 420
    // Pill lies the way the target slot does
    readonly property bool vertical: targetRect.height > targetRect.width
    property bool carrying: true
    // Shrinks from the bar's length to carriedLen on pickup
    property real len: Math.max(fromRect.width, fromRect.height)

    // Cursor target; the pill sits under it
    property real cursorX: fromRect.x + (fromRect.height > fromRect.width ? grabAcross : grabAlong)
    property real cursorY: fromRect.y + (fromRect.height > fromRect.width ? grabAlong : grabAcross)
    // Smoothed pointer velocity, px/s
    property real vx: 0
    property real vy: 0
    property real _lastT: 0

    function move(gx, gy) {
        const t = Date.now()
        const dt = Math.max(1, t - _lastT) / 1000
        if (_lastT > 0) {
            vx = vx * 0.6 + (gx - cursorX) / dt * 0.4
            vy = vy * 0.6 + (gy - cursorY) / dt * 0.4
        }
        _lastT = t
        cursorX = gx
        cursorY = gy
        settle.restart()
    }

    function drop() {
        carrying = false
        vx = vy = 0
        dropAnim.restart()
    }

    // Pointer stopped: let the swing come to rest
    Timer {
        id: settle
        interval: 60
        onTriggered: { ghost.vx = 0; ghost.vy = 0 }
    }

    // Lift: contract to the carried length
    Component.onCompleted: liftAnim.start()
    NumberAnimation {
        id: liftAnim
        target: ghost; property: "len"
        to: ghost.carriedLen
        duration: 260; easing.type: Easing.OutCubic
    }

    // ── Slot preview ───────────────────────────────────────────────────
    Rectangle {
        id: preview
        x: ghost.targetRect.x
        y: ghost.targetRect.y
        width: ghost.targetRect.width
        height: ghost.targetRect.height
        radius: Math.min(width, height) / 2
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1
        // Jumps to the new slot and fades in there; morphing between a
        // horizontal and a side slot ballooned through a big circle
        property real fadeIn: 1
        opacity: (ghost.carrying ? 1 : 0) * fadeIn
        Behavior on opacity { enabled: ghost.carrying === false; NumberAnimation { duration: 160 } }
        NumberAnimation { id: previewFade; target: preview; property: "fadeIn"; from: 0; to: 1; duration: 180 }
        Connections {
            target: ghost
            function onTargetRectChanged() { if (ghost.carrying) previewFade.restart() }
        }
    }

    // ── Carried pill ───────────────────────────────────────────────────
    Rectangle {
        id: pill
        // Grip end stays under the cursor while the pill shrinks and turns
        x: ghost.cursorX - (ghost.vertical ? ghost.grabAcross : ghost.grabAlong)
        y: ghost.cursorY - (ghost.vertical ? ghost.grabAlong : ghost.grabAcross)
        width: ghost.vertical ? ghost.thickness : ghost.len
        height: ghost.vertical ? ghost.len : ghost.thickness
        radius: Math.min(width, height) / 2
        color: Root.Theme.barBg
        border.color: Root.Theme.barBorderStrong
        border.width: 1
        // Swings from its grip end
        transformOrigin: ghost.vertical ? Item.Top : Item.Left

        // Position tracks the cursor directly (a spring here trailed tens of
        // px behind a fast drag); the swing and stretch below keep it lively
        // Turning between a horizontal and a side slot eases over
        Behavior on width { enabled: ghost.carrying; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: ghost.carrying; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // Swings with speed across its length, stretches along the motion
        rotation: ghost.carrying
            ? Math.max(-8, Math.min(8, (ghost.vertical ? -ghost.vy : ghost.vx) * 0.004)) : 0
        Behavior on rotation { SpringAnimation { spring: 3.5; damping: 0.22 } }
        transform: Scale {
            origin.x: pill.width / 2
            origin.y: pill.height / 2
            xScale: 1 + Math.min(0.08, Math.abs(ghost.vx) * 0.00003)
            yScale: 1 + Math.min(0.08, Math.abs(ghost.vy) * 0.00003)
            Behavior on xScale { SpringAnimation { spring: 4; damping: 0.3 } }
            Behavior on yScale { SpringAnimation { spring: 4; damping: 0.3 } }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: ghost.carrying ? 0.55 : 0
            shadowBlur: 0.8
            shadowVerticalOffset: 6
        }

        GripDots {
            vertical: ghost.vertical
            color: Root.Theme.barText
            x: ghost.vertical ? (pill.width - width) / 2 : 10
            y: ghost.vertical ? 10 : (pill.height - height) / 2
        }
    }

    // ── Drop: unfurl into the slot ─────────────────────────────────────
    SequentialAnimation {
        id: dropAnim
        ScriptAction { script: liftAnim.stop() }
        ParallelAnimation {
            NumberAnimation { target: pill; property: "x"; to: ghost.targetRect.x; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: pill; property: "y"; to: ghost.targetRect.y; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: pill; property: "width"; to: ghost.targetRect.width; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: pill; property: "height"; to: ghost.targetRect.height; duration: 260; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: ghost.landed() }
    }
}
