import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: volumeWidget
    spacing: 4

    property int volume: 0
    property bool muted: false

    Process {
        id: volumeCheck
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let val = parseInt(data.trim())
                if (!isNaN(val)) volumeWidget.volume = val
            }
        }
    }

    Process {
        id: muteCheck
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && echo 1 || echo 0"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                volumeWidget.muted = data.trim() === "1"
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            volumeCheck.running = true
            muteCheck.running = true
        }
    }

    Process {
        id: openPavucontrol
        command: ["pavucontrol"]
    }

    Text {
        text: {
            if (volumeWidget.muted) return "󰝟"
            let v = volumeWidget.volume
            if (v > 66) return "󰕾"
            if (v > 33) return "󰖀"
            return "󰕿"
        }
        color: volumeWidget.muted ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 14
        font.family: "FiraCode Nerd Font"

        MouseArea {
            anchors.fill: parent
            onClicked: openPavucontrol.startDetached()
        }
    }

    Text {
        text: volumeWidget.volume + "%"
        color: Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 11
    }
}
