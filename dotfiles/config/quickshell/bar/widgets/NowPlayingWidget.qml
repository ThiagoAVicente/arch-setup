import QtQuick
import QtQuick.Effects
import "../.." as Root

// "Title · Artist" of what Spotify is playing, after the clock, as dark text
// on a glowing white pill. Click it to open or close the lyrics drawer. Slides open while Spotify plays and closes when it stops; other
// players never show here. Hidden on a vertical bar, where there's no room
// for a line of text.
Item {
    id: root

    property bool vertical: false
    signal toggleLyrics()

    readonly property var player: Root.Lyrics.player
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property bool shown: !vertical && title !== "" && (player?.isPlaying ?? false)

    // Kept while closing, so the text doesn't vanish before the slide ends
    property string text: ""
    onTitleChanged: refresh()
    onArtistChanged: refresh()
    function refresh() {
        if (title === "") return
        const next = format()
        if (next === text) return
        pending = next
        swap.restart()
    }
    // Next text, faded in once the current one has faded out
    property string pending: ""
    SequentialAnimation {
        id: swap
        NumberAnimation { target: label; property: "opacity"; to: 0; duration: 90 }
        ScriptAction { script: root.text = root.pending }
        NumberAnimation { target: label; property: "opacity"; to: 1; duration: 140 }
    }

    function esc(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }
    function format() {
        return artist !== ""
            ? esc(title) + "<font color=\"#5c5c64\"> · " + esc(artist) + "</font>"
            : esc(title)
    }

    property int maxWidth: 260
    property int lead: 18 // same gap as clock → date
    readonly property int pad: 10

    implicitWidth: shown ? Math.min(label.implicitWidth, maxWidth) + 2 * pad + lead : 0
    implicitHeight: 36
    visible: implicitWidth > 0
    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // Drawn only through the glow effect below
    Rectangle {
        id: pill
        visible: false
        x: root.lead
        width: Math.max(0, root.width - root.lead)
        height: 22
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Root.Theme.barText
        clip: true

        Text {
            id: label
            x: root.pad
            width: pill.width - 2 * root.pad
            anchors.verticalCenter: parent.verticalCenter
            font.family: Root.Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
            color: Root.Theme.panelSolid
            textFormat: Text.StyledText
            elide: Text.ElideRight
            text: root.text
        }
    }

    MultiEffect {
        source: pill
        anchors.fill: pill
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        // Soft white halo around the pill
        shadowEnabled: true
        shadowColor: Qt.rgba(1, 1, 1, 0.45)
        shadowBlur: 0.9
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        blurMax: 10
        autoPaddingEnabled: true
    }

    MouseArea {
        anchors.fill: pill
        enabled: root.shown
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleLyrics()
    }
}
