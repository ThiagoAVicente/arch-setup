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

    // Subscribe to PipeWire/PulseAudio sink events (event-driven)
    Process {
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink")) sinkMonitor.running = true
            }
        }
    }

    Component.onCompleted: sinkMonitor.running = true

    // Single Process reads vol + mute in one shot, replaces two parallel Processes
    Process {
        id: sinkMonitor
        command: ["sh", "-c",
            "out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null);" +
            "v=$(echo \"$out\" | awk '{print int($2*100)}');" +
            "m=0; echo \"$out\" | grep -q MUTED && m=1;" +
            "echo \"$v $m\""]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length !== 2) return
                const v = parseInt(parts[0])
                const m = parts[1] === "1"
                let changed = false
                if (!isNaN(v) && v !== osdScope.lastVolume) {
                    osdScope.volume = v
                    osdScope.lastVolume = v
                    changed = true
                }
                if (m !== osdScope.lastMuted) {
                    osdScope.muted = m
                    osdScope.lastMuted = m
                    changed = true
                }
                if (changed) osdScope.showOSD("volume")
            }
        }
    }

    // Brightness monitor (2s poll — brightness is user-initiated, no subscribe API)
    Process {
        id: brightnessMonitor
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data.trim())
                if (!isNaN(val) && val !== osdScope.lastBrightness) {
                    osdScope.brightness = val
                    osdScope.lastBrightness = val
                    osdScope.showOSD("brightness")
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: brightnessMonitor.running = true
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
