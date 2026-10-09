//@ pragma Env __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json

// Secure half of the lock (see LockCurtain.qml). Runs as its own short-lived
// process — `quickshell -p <config>/lock.qml` — so a reload or crash of the main
// shell can never drop the session lock. Holds ext-session-lock from start-up,
// draws the same final frame as the curtain, authenticates through PAM and
// exits after unlocking.

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import "." as Root

ShellRoot {
    id: root

    property string buffer: ""
    // idle | checking | fail
    property string status: "idle"
    property string message: ""
    property string pending: ""

    function notifyMain(cmd) {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\n' \"$1\" | timeout 2 socat - UNIX-CONNECT:\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/qs.sock\"",
            "sh", cmd])
    }

    function handleKey(event) {
        event.accepted = true
        if (pam.active) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (buffer.length === 0) return
            pending = buffer
            buffer = ""
            status = "checking"
            message = ""
            pam.start()
        } else if (event.key === Qt.Key_Backspace) {
            buffer = (event.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1)
        } else if (event.key === Qt.Key_Escape) {
            buffer = ""
        } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 0x20) {
            buffer += event.text
            if (status === "fail") status = "idle"
            message = ""
        }
    }

    function fail(msg) {
        pending = ""
        status = "fail"
        message = msg
        for (const s of scenes) s.shake()
    }

    property var scenes: []

    PamContext {
        id: pam
        config: "hyprlock"

        onResponseRequiredChanged: {
            if (!responseRequired) return
            if (root.pending !== "") {
                respond(root.pending)
                root.pending = ""
            } else {
                // A second prompt (OTP, etc.) isn't supported — never send an
                // empty answer, that would burn a faillock attempt
                abort()
                root.fail("unsupported prompt")
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.status = "idle"
                lock.locked = false
                // Curtain in the main shell lifts the bar back up
                root.notifyMain("lock-done")
                quitTimer.start()
            } else if (result === PamResult.MaxTries) {
                root.fail("too many attempts")
            } else {
                root.fail("")
            }
        }

        onError: err => root.fail("auth error")
    }

    Timer {
        id: quitTimer
        interval: 300
        onTriggered: Qt.quit()
    }

    WlSessionLock {
        id: lock
        locked: true

        onSecureStateChanged: if (secure) root.notifyMain("lock-secure")

        WlSessionLockSurface {
            color: Root.Theme.panelSolid

            Root.LockScene {
                id: scene
                anchors.fill: parent
                focus: true
                progress: 1
                morph: 1
                dots: root.buffer.length
                status: root.status
                message: root.message
                Keys.onPressed: event => root.handleKey(event)
                Component.onCompleted: root.scenes = root.scenes.concat([scene])
                Component.onDestruction: root.scenes = root.scenes.filter(s => s !== scene)
            }
        }
    }
}
