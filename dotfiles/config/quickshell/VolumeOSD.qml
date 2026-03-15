import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

Scope {
    property var audioSink: Pipewire.defaultAudioSink
    property real lastVolume: audioSink?.audio.volume || 0
    property bool lastMuted: audioSink?.audio.muted || false

    Repeater {
        model: Quickshell.screens

        FloatingWindow {
            id: osd
            required property var modelData
            screen: modelData

            visible: false
            width: 200
            height: 100
            x: screen.geometry.width / 2 - width / 2
            y: screen.geometry.height - height - 100

            property string icon: ""
            property real value: 0

            function show(newIcon, newValue) {
                icon = newIcon
                value = newValue
                visible = true
                hideTimer.restart()
            }

            Timer {
                id: hideTimer
                interval: 1500
                onTriggered: osd.visible = false
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.1, 0.1, 0.1, 0.85)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                radius: 12

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: osd.icon
                        color: Qt.rgba(1, 1, 1, 0.9)
                        font.pixelSize: 32
                        font.family: "FiraCode Nerd Font"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        width: 160
                        height: 8
                        color: Qt.rgba(1, 1, 1, 0.15)
                        radius: 4
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: parent.width * osd.value
                            height: parent.height
                            color: Qt.rgba(0.4, 0.6, 1, 0.8)
                            radius: 4

                            Behavior on width {
                                NumberAnimation { duration: 100 }
                            }
                        }
                    }

                    Text {
                        text: Math.round(osd.value * 100) + "%"
                        color: Qt.rgba(1, 1, 1, 0.8)
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // Watch for volume changes
    Connections {
        target: audioSink?.audio

        function onVolumeChanged() {
            if (Math.abs(audioSink.audio.volume - lastVolume) > 0.01) {
                let icon = audioSink.audio.muted ? "󰝟" :
                          audioSink.audio.volume > 0.66 ? "󰕾" :
                          audioSink.audio.volume > 0.33 ? "󰖀" : "󰕿"

                // Show OSD on all screens
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    // Access OSD window for each screen and show
                    // Note: This is a simplified version
                }
                lastVolume = audioSink.audio.volume
            }
        }

        function onMutedChanged() {
            if (audioSink.audio.muted !== lastMuted) {
                // Show muted state
                lastMuted = audioSink.audio.muted
            }
        }
    }
}
