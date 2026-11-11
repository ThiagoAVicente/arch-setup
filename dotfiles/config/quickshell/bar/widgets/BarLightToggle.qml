import QtQuick
import "../.." as Root

// Switches the whole shell between light and dark (Theme.qml)
Item {
    id: lightToggle

    property bool vertical: false

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: lightMa.containsMouse ? Root.Theme.barHover : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    Text {
        anchors.centerIn: parent
        text: Root.State.lightMode ? "󰖨" : "󰖔"
        color: lightMa.containsMouse ? Root.Theme.barAccent : Root.Theme.barSubtext
        font.pixelSize: 14
        font.family: Root.Theme.fontFamily
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    MouseArea {
        id: lightMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Root.State.lightMode = !Root.State.lightMode
    }
}
