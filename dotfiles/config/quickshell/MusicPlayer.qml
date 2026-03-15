import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

FloatingWindow {
    id: musicWindow
    property var player: Mpris.players.values[0]

    visible: player && (player.playbackState === MprisPlaybackState.Playing || player.playbackState === MprisPlaybackState.Paused)
    implicitWidth: 350
    implicitHeight: 100

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.1, 0.1, 0.1, 0.85)
        radius: 12
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Album art
            Image {
                property var artUrl: musicWindow.player?.trackArtUrl || ""
                source: artUrl
                Layout.preferredWidth: 76
                Layout.preferredHeight: 76
                fillMode: Image.PreserveAspectCrop
                smooth: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.2, 0.2, 0.2, 0.3)
                    visible: parent.source == ""

                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.pixelSize: 32
                        font.family: "FiraCode Nerd Font"
                    }
                }
            }

            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Text {
                    text: musicWindow.player?.trackTitle || "No title"
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: musicWindow.player?.trackArtist || "Unknown artist"
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: musicWindow.player?.trackAlbum || ""
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: text !== ""
                }

                Item { Layout.fillHeight: true }

                // Controls
                RowLayout {
                    spacing: 8

                    Text {
                        text: "󰒮"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 18
                        font.family: "FiraCode Nerd Font"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: musicWindow.player?.previous()
                        }
                    }

                    Text {
                        text: musicWindow.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                        color: Qt.rgba(0.4, 0.6, 1, 1)
                        font.pixelSize: 22
                        font.family: "FiraCode Nerd Font"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: musicWindow.player?.togglePlaying()
                        }
                    }

                    Text {
                        text: "󰒭"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 18
                        font.family: "FiraCode Nerd Font"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: musicWindow.player?.next()
                        }
                    }
                }
            }
        }
    }
}
