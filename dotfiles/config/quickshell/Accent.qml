pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "." as Root

// Colour of the bar's hairline and the music wave's rim. Set from a hex code
// on the clipboard (bar/widgets/AccentButton.qml) and persisted, so it comes
// back after a restart. Each colour is also remembered for the wallpaper that
// was on screen when it was set, and comes back whenever that wallpaper is
// applied again. A wallpaper with no colour of its own keeps the current one.
Singleton {
    id: accent

    readonly property color fallback: "#e6383f"
    property color color: fallback
    // Wallpaper path to the hex set while it was applied
    property var byWallpaper: ({})

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "") + "/.local/state")
        + "/quickshell"
    readonly property string storePath: stateDir + "/accent.json"

    // Applied wallpaper. State has it once the wallpaper picker has loaded or
    // set one; until then it is read from the picker's own state file
    property string savedWallpaper: ""
    readonly property string wallpaper: Root.State.appliedWallpaper || savedWallpaper
    onWallpaperChanged: {
        const hex = parse(byWallpaper[wallpaper])
        if (hex && hex !== String(color)) {
            color = hex
            save()
        }
    }

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

    // Applies and saves `text` if it is a colour, tied to the current
    // wallpaper; returns whether it was
    function apply(text) {
        const hex = parse(text)
        if (!hex) return false
        color = hex
        if (wallpaper !== "") {
            const map = Object.assign({}, byWallpaper)
            map[wallpaper] = hex
            byWallpaper = map
        }
        save()
        return true
    }

    function save() {
        store.setText(JSON.stringify({ color: String(color), byWallpaper: byWallpaper }) + "\n")
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
                const data = JSON.parse(text() || "{}")
                accent.byWallpaper = data.byWallpaper ?? {}
                const hex = accent.parse(data.color)
                if (hex) accent.color = hex
            } catch (e) {
                console.warn("accent: ignoring unparsable", accent.storePath, e)
            }
        }
    }

    // Written by WallpaperSelector.qml when a wallpaper is applied
    FileView {
        path: accent.stateDir + "/wallpaper"
        blockLoading: true
        printErrors: false
        onLoaded: accent.savedWallpaper = text().trim()
    }
}
