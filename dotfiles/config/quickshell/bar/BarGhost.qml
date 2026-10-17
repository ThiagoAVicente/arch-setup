import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../" as Root

// The bar while it is being dragged. Exists only during a drag: a
// full-screen, input-less overlay where the lifted pill springs after the
// cursor, swings with its speed and previews the slot it will drop into.
PanelWindow {
    id: ghost

    // Pill rect at pickup, in screen coordinates
    required property rect fromRect
    // Cursor offset inside the pill at pickup
    required property real grabX
    required property real grabY
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

    // Length of the pill while carried
    readonly property real carriedLen: 420
    property bool carrying: true

    // Cursor target; the pill springs after it
    property real cursorX: fromRect.x + grabX
    property real cursorY: fromRect.y + grabY
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

    // ── Slot preview ───────────────────────────────────────────────────
    Rectangle {
        x: ghost.targetRect.x
        y: ghost.targetRect.y
        width: ghost.targetRect.width
        height: ghost.targetRect.height
        radius: Math.min(width, height) / 2
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.22)
        border.width: 1
        opacity: ghost.carrying ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on x { SpringAnimation { spring: 4; damping: 0.35 } }
        Behavior on y { SpringAnimation { spring: 4; damping: 0.35 } }
    }

    // ── Carried pill ───────────────────────────────────────────────────
    Rectangle {
        id: pill
        // Grip stays under the cursor while the pill shrinks to carried size
        x: ghost.cursorX - ghost.grabX
        y: ghost.cursorY - ghost.grabY
        width: ghost.fromRect.width
        height: ghost.fromRect.height
        radius: height / 2
        color: Root.Theme.barBg
        border.color: Root.Theme.barBorderStrong
        border.width: 1
        transformOrigin: Item.Left

        Behavior on x { enabled: ghost.carrying; SpringAnimation { spring: 6; damping: 0.38; mass: 0.7 } }
        Behavior on y { enabled: ghost.carrying; SpringAnimation { spring: 6; damping: 0.38; mass: 0.7 } }

        // Swings with horizontal speed, stretches along the motion
        rotation: ghost.carrying ? Math.max(-8, Math.min(8, ghost.vx * 0.004)) : 0
        Behavior on rotation { SpringAnimation { spring: 3.5; damping: 0.22 } }
        transform: Scale {
            origin.x: pill.width / 2
            origin.y: pill.height / 2
            xScale: 1 + Math.min(0.08, Math.abs(ghost.vx) * 0.00003)
            yScale: 1 - Math.min(0.12, Math.abs(ghost.vy) * 0.00004)
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

        // Lift: contract to the carried length
        Component.onCompleted: liftAnim.start()
        NumberAnimation {
            id: liftAnim
            target: pill; property: "width"
            to: ghost.carriedLen
            duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.3
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f01dd}"
            font.family: Root.Theme.fontFamily
            font.pixelSize: 15
            color: Root.Theme.barText
        }
    }

    // ── Drop: unfurl into the slot ─────────────────────────────────────
    SequentialAnimation {
        id: dropAnim
        ScriptAction { script: liftAnim.stop() }
        ParallelAnimation {
            NumberAnimation { target: pill; property: "x"; to: ghost.targetRect.x; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            NumberAnimation { target: pill; property: "y"; to: ghost.targetRect.y; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: pill; property: "width"; to: ghost.targetRect.width; duration: 360; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: ghost.landed() }
    }
}
