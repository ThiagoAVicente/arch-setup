import Quickshell.Io
import QtQuick
import "../.." as Root

// Red webcam icon while any process (browser, PipeWire, ...) has /dev/video* open.
Item {
    id: root
    property bool vertical: false
    property bool active: false

    visible: active
    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(0.85, 0.3, 0.35, 0.12)
    }

    Text {
        anchors.centerIn: parent
        text: "󰖠" // nf-md-webcam
        color: Root.Theme.critical
        font.pixelSize: 14
        font.family: Root.Theme.fontFamily
    }

    // fuser exits 0 when some process holds a video device open
    Process {
        id: check
        command: ["sh", "-c", "fuser /dev/video* >/dev/null 2>&1"]
        onExited: code => {
            root.active = code === 0; console.warn("CAMTEST", root.active)
            // an event arrived mid-check: re-check so a fast open+close isn't stuck on
            if (root.pending) { root.pending = false; check.running = true }
        }
    }
    property bool pending: false
    function recheck() { if (check.running) pending = true; else check.running = true }

    // Kernel open/close events on the camera nodes; each one re-runs the fuser check.
    // shortcut: watches devices present at start, a camera plugged in later needs a bar reload
    Process {
        command: ["sh", "-c", "exec inotifywait -mq -e open,close --format x /dev/video*"]
        running: true
        stdout: SplitParser { onRead: root.recheck() }
    }

    Component.onCompleted: recheck()
}
