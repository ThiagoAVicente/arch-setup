import Quickshell
import Quickshell.Io
import QtQuick

Text {
    id: cpu
    text: "󰍛"
    color: Qt.rgba(1, 1, 1, 0.7)
    font.pixelSize: 14
    font.family: "FiraCode Nerd Font"

    Process {
        id: cpuProc
        command: ["foot", "--app-id", "R.float", "--", "btm"]
    }

    MouseArea {
        anchors.fill: parent
        onClicked: cpuProc.startDetached()
    }
}
