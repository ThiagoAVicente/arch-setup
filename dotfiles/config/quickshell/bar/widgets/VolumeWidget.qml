import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../.." as Root

Item {
    id: root

    property int volume: 0
    property bool muted: false

    implicitWidth: row.implicitWidth + 18
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent; radius: height / 2
        color: volMa.containsMouse ? Root.Theme.barHover : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: Root.IconMaps.volumeIcon(root.volume, root.muted)
            color: root.muted ? Root.Theme.barMuted
                : volMa.containsMouse ? Root.Theme.barAccent : Root.Theme.barSubtext
            font.family: Root.Theme.fontFamily
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 130 } }
        }

        Text {
            id: volLabel
            visible: !root.muted
            text: root.volume
            color: volMa.containsMouse ? Root.Theme.barSubtext : Root.Theme.barMuted
            font.family: Root.Theme.fontMono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 130 } }

            // Quick dip on value change — same pattern as the clock flip
            onTextChanged: volDip.restart()
            SequentialAnimation {
                id: volDip
                NumberAnimation { target: volLabel; property: "opacity"; to: 0.5; duration: 80; easing.type: Easing.InCubic }
                NumberAnimation { target: volLabel; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            }
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
