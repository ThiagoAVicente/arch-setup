pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Colour of the bar's hairline and the music wave's rim. Set from a hex code
// on the clipboard (bar/widgets/AccentButton.qml) and persisted, so it comes
// back after a restart.
Singleton {
    id: accent

    readonly property color fallback: "#e6383f"
    property color color: fallback

    readonly property string storePath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "") + "/.local/state")
        + "/quickshell/accent.json"

    // "#rgb", "#rrggbb" or "#rrggbbaa", the "#" optional; null if it isn't one
    function parse(text) {
        const t = (text || "").trim()
        const m = /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.exec(t)
        if (!m) return null
        let h = m[1]
        if (h.length === 3) h = h.split("").map(c => c + c).join("")
        // Qt reads 8 digits as #aarrggbb; people paste #rrggbbaa
        if (h.length === 8) h = h.slice(6) + h.slice(0, 6)
        return "#" + h.toLowerCase()
    }

    // Applies and saves `text` if it is a colour; returns whether it was
    function apply(text) {
        const hex = parse(text)
        if (!hex) return false
        color = hex
        store.setText(JSON.stringify({ color: hex }) + "\n")
        return true
    }

    FileView {
        id: store
        path: accent.storePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const hex = accent.parse(JSON.parse(text() || "{}").color)
                if (hex) accent.color = hex
            } catch (e) {
                console.warn("accent: ignoring unparsable", accent.storePath, e)
            }
        }
    }
}
