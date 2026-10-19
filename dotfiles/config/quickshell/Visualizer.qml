pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Audio levels for the bar's music ripple. One cava process, run only while
// a media player is playing, so it costs nothing the rest of the time.
Singleton {
    id: viz

    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    // 48 bands, 0..1, bass first
    property var levels: []

    Process {
        id: cava
        running: viz.playing
        command: ["cava", "-p", Quickshell.shellDir + "/cava-bar.conf"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";")
                const out = []
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue
                    // sqrt lifts quiet passages so the ripple stays lively
                    out.push(Math.sqrt(Math.min(1, parseInt(parts[i]) / 100)))
                }
                viz.levels = out
            }
        }
        onRunningChanged: if (!running) viz.levels = []
    }
}
