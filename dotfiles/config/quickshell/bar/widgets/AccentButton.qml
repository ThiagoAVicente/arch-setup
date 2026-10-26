import Quickshell.Io
import QtQuick
import "../.." as Root

// Recolours the bar's border from a hex code on the clipboard (#rgb,
// #rrggbb or #rrggbbaa). Anything else leaves it alone and shakes the button.
Item {
    id: accentButton

    property bool vertical: false

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: abMa.containsMouse ? Root.Theme.barHover : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: "󰏘"
        color: abMa.containsMouse ? Root.Accent.color : Root.Theme.barMuted
        font.pixelSize: 14
        font.family: Root.Theme.fontFamily
        Behavior on color { ColorAnimation { duration: 130 } }

        transform: Translate { id: nudge }
    }

    MouseArea {
        id: abMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!paste.running) paste.running = true
    }

    Process {
        id: paste
        command: ["wl-paste", "--no-newline", "--type", "text"]
        stdout: StdioCollector { id: clip }
        onExited: if (!Root.Accent.apply(clip.text)) shake.restart()
    }

    // Not a colour on the clipboard
    SequentialAnimation {
        id: shake
        NumberAnimation { target: nudge; property: "x"; to: -3; duration: 50 }
        NumberAnimation { target: nudge; property: "x"; to: 3; duration: 70 }
        NumberAnimation { target: nudge; property: "x"; to: -2; duration: 60 }
        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 50 }
    }
}
