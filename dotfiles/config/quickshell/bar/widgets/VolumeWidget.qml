import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../.." as Root

Item {
    id: root

    property int volume: 0
    property bool muted: false

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent; radius: 9
        color: volMa.containsMouse ? Root.Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: Root.IconMaps.volumeIcon(root.volume, root.muted)
            color: root.muted ? Root.Theme.muted : Root.Theme.text
            font.family: Root.Theme.fontFamily
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            text: root.muted ? "mute" : root.volume + "%"
            color: root.muted ? Root.Theme.muted : Root.Theme.subtext
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // Single Process reads vol + mute in one shot
    Process {
        id: sinkCheck
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
                if (!isNaN(v)) root.volume = v
                root.muted = parts[1] === "1"
            }
        }
    }

    // Event-driven: pactl subscribe
    Process {
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: data => { if (data.includes("sink")) sinkCheck.running = true }
        }
    }

    Component.onCompleted: sinkCheck.running = true

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
