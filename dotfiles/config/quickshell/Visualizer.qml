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
    // The player that's playing, for the bar's now-playing text
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null
    // 32 bands, 0..1, bass first
    property var levels: []
    // Same bands softened with their neighbours, packed four to a vec4 for
    // the wave shader. Worked out once here and shared by every screen's bar
    readonly property var packed: {
        const lv = levels
        const n = lv.length
        const out = []
        for (let q = 0; q < 8; q++) {
            const s = []
            for (let j = 0; j < 4; j++) {
                const i = q * 4 + j
                if (i >= n) { s.push(0); continue }
                const a = lv[Math.max(0, i - 1)], b = lv[i], c = lv[Math.min(n - 1, i + 1)]
                s.push((a + 2 * b + c) / 4)
            }
            out.push(Qt.vector4d(s[0], s[1], s[2], s[3]))
        }
        return out
    }
    // Loudest softened band this frame: the wave's outer side runs on
    // peak - level, the inverse of the inner side, and settles with it
    readonly property real peak: {
        let m = 0
        for (const v of packed) m = Math.max(m, v.x, v.y, v.z, v.w)
        return m
    }

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
