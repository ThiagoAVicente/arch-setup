import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int volume: 0
    property bool muted: false

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent; radius: 9
        color: volMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: {
                if (root.muted) return "󰝟"
                if (root.volume > 66) return "󰕾"
                if (root.volume > 33) return "󰖀"
                if (root.volume > 0)  return "󰕿"
                return "󰕿"
            }
            color: root.muted ? "#45475a" : "#cba6f7"
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            text: root.muted ? "mute" : root.volume + "%"
            color: root.muted ? "#45475a" : "#a6adc8"
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // Processes
    Process {
        id: volumeCheck
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const val = parseInt(data.trim())
                if (!isNaN(val)) root.volume = val
            }
        }
    }

    Process {
        id: muteCheck
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && echo 1 || echo 0"]
        running: true
        stdout: SplitParser { onRead: data => root.muted = data.trim() === "1" }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { volumeCheck.running = true; muteCheck.running = true }
    }

    Process { id: openPavucontrol; command: ["pavucontrol"] }

    MouseArea {
        id: volMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: event => {
            if (event.button === Qt.LeftButton)
                openPavucontrol.startDetached()
        }

        onWheel: event => {
            const delta = event.angleDelta.y > 0 ? 5 : -5
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", delta + "%"])
        }
    }
}
