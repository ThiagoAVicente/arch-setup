import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: musicPlayerInline
    property var player: Mpris.players.values[0]
    visible: player !== undefined && player.playbackState === MprisPlaybackState.Playing
    spacing: 6

    Text {
        text: player?.playbackState === MprisPlaybackState.Playing ? "󰎆" : "󰏤"
        color: Qt.rgba(0.4, 0.6, 1, 1)
        font.pixelSize: 14
        font.family: "FiraCode Nerd Font"
    }

    Text {
        property string artist: player?.trackArtist || ""
        property string title: player?.trackTitle || ""
        text: {
            if (!artist && !title) return "No media"
            if (artist && title) return artist + " - " + title
            return title || artist
        }
        color: Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 11
        Layout.maximumWidth: 250
        elide: Text.ElideRight
    }

    // Play/Pause button
    Text {
        text: player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
        color: Qt.rgba(1, 1, 1, 0.5)
        font.pixelSize: 12
        font.family: "FiraCode Nerd Font"

        MouseArea {
            anchors.fill: parent
            onClicked: player?.togglePlaying()
        }
    }
}