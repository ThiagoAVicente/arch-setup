import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: osdScope

    property int volume: 0
    property int brightness: 0
    property bool muted: false
    property int lastVolume: 0
    property int lastBrightness: 0
    property bool lastMuted: false
    property string osdType: ""

    // Poll for changes
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            volumeMonitor.running = true
            muteMonitor.running = true
            brightnessMonitor.running = true
        }
    }

    // Volume monitor
    Process {
        id: volumeMonitor
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data.trim())
                if (!isNaN(val)) {
                    if (val !== osdScope.lastVolume) {
                        osdScope.volume = val
                        osdScope.lastVolume = val
                        osdScope.showOSD("volume")
                    }
                }
            }
        }
    }

    Process {
        id: muteMonitor
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                let m = data.trim() === "1"
                if (m !== osdScope.lastMuted) {
                    osdScope.muted = m
                    osdScope.lastMuted = m
                    osdScope.showOSD("volume")
                }
            }
        }
    }

    // Brightness monitor
    Process {
        id: brightnessMonitor
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data.trim())
                if (!isNaN(val)) {
                    if (val !== osdScope.lastBrightness) {
                        osdScope.brightness = val
                        osdScope.lastBrightness = val
                        osdScope.showOSD("brightness")
                    }
                }
            }
        }
    }

    function showOSD(type) {
        osdType = type
        osdWindow.visible = true
        hideTimer.restart()
    }

    PanelWindow {
        id: osdWindow
        visible: false
        exclusiveZone: 0

        anchors {
            bottom: true
        }

        margins {
            bottom: 100
        }

        implicitWidth: 220
        implicitHeight: 80
        color: "transparent"

        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: osdWindow.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 200
            height: 70
            color: Qt.rgba(0.1, 0.1, 0.1, 0.85)
            radius: 16
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (osdScope.osdType === "volume") {
                            if (osdScope.muted) return "󰝟"
                            if (osdScope.volume > 66) return "󰕾"
                            if (osdScope.volume > 33) return "󰖀"
                            return "󰕿"
                        } else {
                            if (osdScope.brightness > 66) return "󰃠"
                            if (osdScope.brightness > 33) return "󰃟"
                            return "󰃞"
                        }
                    }
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.pixelSize: 26
                    font.family: "FiraCode Nerd Font"
                }

                Rectangle {
                    width: 160
                    height: 6
                    color: Qt.rgba(1, 1, 1, 0.15)
                    radius: 3
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: parent.width * (osdScope.osdType === "volume" ? osdScope.volume : osdScope.brightness) / 100
                        height: parent.height
                        color: osdScope.muted ? Qt.rgba(1, 0.4, 0.4, 0.8) : Qt.rgba(0.4, 0.6, 1, 0.8)
                        radius: 3

                        Behavior on width {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }
            }
        }
    }
}
