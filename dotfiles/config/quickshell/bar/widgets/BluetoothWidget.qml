import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "../.." as Root

Item {
    id: root

    property bool popoutOpen: false
    signal togglePopout()

    implicitWidth: 30
    implicitHeight: 24

    function getBluetoothIcon() {
        const adapter = Bluetooth.defaultAdapter
        if (!adapter || !adapter.enabled) return "󰂲"
        for (const key in Bluetooth.devices) {
            if (Bluetooth.devices[key] && Bluetooth.devices[key].connected) return "󰂱"
        }
        return "󰂯"
    }

    function getBluetoothColor() {
        if (root.popoutOpen) return Root.Theme.panelSolid
        const adapter = Bluetooth.defaultAdapter
        if (!adapter || !adapter.enabled) return Root.Theme.barMuted
        if (hovMa.containsMouse) return Root.Theme.barAccent
        return Root.Theme.barSubtext
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.popoutOpen ? Root.Theme.barAccent
            : (hovMa.containsMouse ? Root.Theme.barHover : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        text: getBluetoothIcon()
        color: getBluetoothColor()
        font.family: Root.Theme.fontFamily
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 150 } }

        SequentialAnimation on opacity {
            running: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering && !root.popoutOpen
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        id: hovMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePopout()
    }
}
