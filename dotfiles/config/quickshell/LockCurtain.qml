pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "." as Root

// Main-shell half of the lock. Pulls the bar down over the live desktop,
// then hands off to the lock process (lock.qml), which holds the real
// ext-session-lock and draws the identical final frame. These windows stay
// mapped underneath the whole time, so after unlock the bar can rise back
// over the desktop. This side never decides whether the session is locked.
Scope {
    id: curtain

    property real progress: 0
    property real morph: 0
    // descending | handoff | locked | ascending
    property string phase: ""

    signal finished()

    function lockDown() {
        if (phase !== "") return
        phase = "descending"
        downAnim.start()
    }

    // From the lock process once its session lock is confirmed
    function secured() {
        watchdog.stop()
        if (phase === "handoff") phase = "locked"
    }

    // From the lock process (or hyprlock fallback) after a successful unlock
    function liftUp() {
        if (phase === "ascending" || phase === "") return
        watchdog.stop()
        downAnim.stop()
        phase = "ascending"
        upAnim.start()
    }

    function notifyCmd(cmd) {
        return "printf '%s\\n' " + cmd + " | timeout 2 socat - UNIX-CONNECT:\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/qs.sock\""
    }

    SequentialAnimation {
        id: downAnim
        NumberAnimation { target: curtain; property: "progress"; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
        NumberAnimation { target: curtain; property: "morph"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        ScriptAction {
            script: {
                curtain.phase = "handoff"
                // Detached: must outlive a reload of this shell
                Quickshell.execDetached(["quickshell", "-p", Quickshell.shellDir + "/lock.qml"])
                watchdog.start()
            }
        }
    }

    SequentialAnimation {
        id: upAnim
        NumberAnimation { target: curtain; property: "morph"; to: 0; duration: 200; easing.type: Easing.InOutCubic }
        NumberAnimation { target: curtain; property: "progress"; to: 0; duration: 520; easing.type: Easing.InOutCubic }
        ScriptAction { script: { curtain.phase = ""; curtain.finished() } }
    }

    // Lock process never confirmed: lock with hyprlock instead, and lift the
    // curtain once it exits
    Timer {
        id: watchdog
        interval: 6000
        onTriggered: Quickshell.execDetached(["sh", "-c",
            "pidof hyprlock >/dev/null || hyprlock; " + curtain.notifyCmd("lock-done")])
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            color: "transparent"
            WlrLayershell.namespace: "qs-lock"
            WlrLayershell.layer: WlrLayer.Overlay
            // Swallow typing while the lock process starts so a password typed
            // early can't land in the focused app
            WlrLayershell.keyboardFocus: curtain.phase === "ascending"
                ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

            readonly property var monitor: Hyprland.monitorFor(modelData)

            Root.LockScene {
                anchors.fill: parent
                focus: true
                progress: curtain.progress
                morph: curtain.morph
                barVisible: !Root.State.barHidden
                    && !(win.monitor?.activeWorkspace?.hasFullscreen ?? false)
                Keys.onPressed: event => event.accepted = true
            }
        }
    }
}
