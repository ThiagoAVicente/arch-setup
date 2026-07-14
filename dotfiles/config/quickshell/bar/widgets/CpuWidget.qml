import Quickshell
import Quickshell.Io
import QtQuick
import "../.." as Root

Item {
    id: root

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent; radius: height / 2
        color: cpuMa.containsMouse ? Root.Theme.barHover : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    Text {
        anchors.centerIn: parent
        text: "󰍛"
        color: cpuMa.containsMouse ? Root.Theme.barAccent : Root.Theme.barMuted
        font.pixelSize: 14
        font.family: Root.Theme.fontFamily
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    Process {
        id: cpuProc
        command: ["foot", "--app-id", "R.float", "--", "btop"]
    }

    MouseArea {
        id: cpuMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cpuProc.startDetached()
    }
}
