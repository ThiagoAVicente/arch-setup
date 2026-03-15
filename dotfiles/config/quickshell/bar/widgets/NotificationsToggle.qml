import QtQuick
import "../.." as Root

Rectangle {
    id: notifToggle
    width: 20
    height: 20
    radius: 4
    color: Root.State.notificationsMuted ? Qt.rgba(1, 0.4, 0.4, 0.2) : "transparent"

    Text {
        anchors.centerIn: parent
        text: Root.State.notificationsMuted ? "󰂛" : "󰂚"
        color: Root.State.notificationsMuted ? Qt.rgba(1, 0.4, 0.4, 1) : Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 14
        font.family: "FiraCode Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Root.State.notificationsMuted = !Root.State.notificationsMuted
    }
}
