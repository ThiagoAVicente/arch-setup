pragma Singleton
import QtQuick

QtObject {
    property bool notificationsMuted: false
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
