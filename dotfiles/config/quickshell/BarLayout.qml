pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Which screen edge the bar sits on, per monitor (keyed by screen name).
// Persisted so the bar comes back where it was dropped.
Singleton {
    id: layout

    // { "eDP-1": "bottom", ... }; missing screens use the default edge
    property var edges: ({})
    readonly property string defaultEdge: "top"

    readonly property string storePath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "") + "/.local/state")
        + "/quickshell/bar.json"

    // "top", "bottom", "left", "right", or "center": dropped in the middle
    // of the screen as a round desktop widget
    function edgeOf(screenName) {
        return edges[screenName] ?? defaultEdge
    }

    // Edge that drawers and popouts hang from: a centred bar has none, so
    // they drop from the top as if the bar were hidden
    function dockEdgeOf(screenName) {
        const e = edgeOf(screenName)
        return e === "center" ? "top" : e
    }

    function isCentered(screenName) {
        return edgeOf(screenName) === "center"
    }

    function setEdge(screenName, edge) {
        if (!screenName || edgeOf(screenName) === edge) return
        const next = Object.assign({}, edges)
        next[screenName] = edge
        edges = next
        store.setText(JSON.stringify(edges) + "\n")
    }

    // Screen of the focused monitor: drawers open there, hanging off that
    // screen's bar
    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name
        for (const s of Quickshell.screens)
            if (s.name === name) return s
        return null
    }

    function isVertical(edge) {
        return edge === "left" || edge === "right"
    }

    FileView {
        id: store
        path: layout.storePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text() || "{}")
                if (parsed && typeof parsed === "object") layout.edges = parsed
            } catch (e) {
                console.warn("bar: ignoring unparsable", layout.storePath, e)
            }
        }
    }
}
