import Quickshell
import Quickshell.Io
import QtQuick
import "../.." as Root

Text {
    id: cpu
    text: "󰍛"
    color: Root.Theme.subtext
    font.pixelSize: 14
    font.family: Root.Theme.fontFamily

    Process {
        id: cpuProc
        command: ["foot", "--app-id", "R.float", "--", "btop"]
    }

    MouseArea {
        anchors.fill: parent
        onClicked: cpuProc.startDetached()
    }
}
