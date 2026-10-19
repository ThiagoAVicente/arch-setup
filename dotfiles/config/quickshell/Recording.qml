pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Screen recording state (wf-recorder, started by ~/scripts/record-toggle.sh).
// The script pings the IPC socket with "recording" on start/stop; while a
// recording runs it is also re-checked every few seconds in case it dies.
Singleton {
    id: rec

    property bool active: false
    // When the current recording started (ms since epoch)
    property real since: 0
    // Seconds recorded so far, ticking while active
    property int elapsed: 0

    function refresh() { check.running = true }
    function toggle() {
        Quickshell.execDetached(["sh", "-c", "\"$HOME/scripts/record-toggle.sh\""])
    }

    // Elapsed seconds of a running wf-recorder, empty when none
    Process {
        id: check
        command: ["ps", "-o", "etimes=", "-C", "wf-recorder"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const secs = parseInt((text || "").trim())
                rec.active = !isNaN(secs)
                if (rec.active) {
                    rec.since = Date.now() - secs * 1000
                    rec.elapsed = secs
                }
            }
        }
    }

    Timer {
        interval: 1000; repeat: true
        running: rec.active
        onTriggered: {
            rec.elapsed = Math.floor((Date.now() - rec.since) / 1000)
            if (rec.elapsed % 5 === 0) rec.refresh()
        }
    }
}
