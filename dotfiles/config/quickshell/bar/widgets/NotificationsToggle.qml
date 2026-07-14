import QtQuick
import "../.." as Root

Rectangle {
    id: notifToggle
    width: 24
    height: 24
    radius: height / 2
    color: Root.State.notificationsMuted ? Qt.rgba(0.85, 0.48, 0.55, 0.14)
        : ntMa.containsMouse ? Root.Theme.barHover : "transparent"
    Behavior on color { ColorAnimation { duration: 130 } }

    Text {
        anchors.centerIn: parent
        text: Root.State.notificationsMuted ? "󰂛" : "󰂚"
        color: Root.State.notificationsMuted ? Root.Theme.critical
            : ntMa.containsMouse ? Root.Theme.barAccent : Root.Theme.barMuted
        font.pixelSize: 14
        font.family: Root.Theme.fontFamily
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    MouseArea {
        id: ntMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Root.State.notificationsMuted = !Root.State.notificationsMuted
    }
}
