import QtQuick
import "../.." as Root

Rectangle {
    id: notifToggle
    width: 20
    height: 20
    radius: 4
    color: Root.State.notificationsMuted ? Qt.rgba(0.85, 0.48, 0.55, 0.18) : "transparent"

    Text {
        anchors.centerIn: parent
        text: Root.State.notificationsMuted ? "󰂛" : "󰂚"
        color: Root.State.notificationsMuted ? Root.Theme.critical : Root.Theme.barSubtext
        font.pixelSize: 14
        font.family: Root.Theme.fontFamily
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Root.State.notificationsMuted = !Root.State.notificationsMuted
    }
}
