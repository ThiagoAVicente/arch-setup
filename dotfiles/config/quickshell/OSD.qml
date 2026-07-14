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

    // Event-driven: udev fires a change event on the backlight device instantly
    Process {
        running: true
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("change")) brightnessMonitor.running = true
            }
        }
    }

    // Fallback slow poll in case udev misses something
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: brightnessMonitor.running = true
    }

    function showOSD(type) {
        osdType = type
        if (!osdWindow.visible) {
            osdWindow.visible = true
            capsule.opacity = 0
            capsule.yOffset = 8
            osdInAnim.restart()
        }
        hideTimer.restart()
    }

    PanelWindow {
        id: osdWindow
        visible: false
        exclusiveZone: 0
        WlrLayershell.namespace: "qs-overlay"

        anchors {
            bottom: true
        }

        margins {
            bottom: 100
        }

        implicitWidth: 280
        implicitHeight: 60
        color: "transparent"

        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: osdWindow.visible = false
        }

        ParallelAnimation {
            id: osdInAnim
            NumberAnimation { target: capsule; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: capsule; property: "yOffset"; to: 0; duration: 160; easing.type: Easing.OutCubic }
        }

        // ── Slim capsule: icon · track · value ─────────────────────────────
        Rectangle {
            id: capsule
            property real yOffset: 0
            anchors.centerIn: parent
            anchors.verticalCenterOffset: yOffset
            width: 250
            height: 42
            color: Qt.rgba(0.055, 0.055, 0.067, 0.72)
            radius: height / 2
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1

            // Inset top highlight
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            Row {
                anchors.centerIn: parent
                spacing: 13

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    horizontalAlignment: Text.AlignHCenter
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
                    color: osdScope.muted && osdScope.osdType === "volume"
                        ? "#d97a8e" : "#e9e9ec"
                    font.pixelSize: 16
                    font.family: "FiraCode Nerd Font"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    height: 4
                    color: Qt.rgba(1, 1, 1, 0.12)
                    radius: 2

                    Rectangle {
                        width: parent.width * Math.min(100, (osdScope.osdType === "volume" ? osdScope.volume : osdScope.brightness)) / 100
                        height: parent.height
                        color: osdScope.muted && osdScope.osdType === "volume"
                            ? Qt.rgba(0.85, 0.48, 0.55, 0.75) : "#f0f0f2"
                        radius: 2
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    horizontalAlignment: Text.AlignRight
                    text: osdScope.muted && osdScope.osdType === "volume"
                        ? "m" : (osdScope.osdType === "volume" ? osdScope.volume : osdScope.brightness)
                    color: osdScope.muted && osdScope.osdType === "volume" ? "#d97a8e" : "#8f8f96"
                    font.pixelSize: 12
                    font.family: "FiraCode Nerd Font Mono"
                }
            }
        }
    }
}
