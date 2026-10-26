pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: state

    // Do not disturb. Saved, so it survives restarts and reboots
    property bool notificationsMuted: false
    onNotificationsMutedChanged: if (dndStore.loaded) dndStore.setText(JSON.stringify({ muted: notificationsMuted }) + "\n")
    property FileView dndStore: FileView {
        property bool loaded: false
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "") + "/.local/state")
            + "/quickshell/dnd.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try { state.notificationsMuted = JSON.parse(text() || "{}").muted === true }
            catch (e) { console.warn("dnd: ignoring unparsable", path, e) }
            loaded = true
        }
        // Nothing saved yet
        onLoadFailed: loaded = true
    }
    property string appliedWallpaper: ""
    property bool barHidden: false
    // Where open drawers/popouts meet the bar, so the music lip can part
    // around them: { key: { screen, c (centre along the edge, screen px), half } }
    property var holes: ({})
    function setHole(key, hole) {
        const next = Object.assign({}, holes)
        if (hole) next[key] = hole
        else delete next[key]
        holes = next
    }
}
