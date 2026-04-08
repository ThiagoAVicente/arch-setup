import Quickshell
import Quickshell.Bluetooth
import QtQuick

Item {
    id: root

    property bool popoutOpen: false
    signal togglePopout()

    implicitWidth: 30
    implicitHeight: 26

    // ── Helper Functions (Avoids QML JS pitfalls) ─────────────────────────
    function getBluetoothIcon() {
        const adapter = Bluetooth.defaultAdapter
        if (!adapter || !adapter.enabled) return "󰂲"
        for (const key in Bluetooth.devices) {
            if (Bluetooth.devices[key] && Bluetooth.devices[key].connected) return "󰂱"
        }
        return "󰂯"
    }

    function getBluetoothColor() {
        if (root.popoutOpen) return "#1e1e2e"
        const adapter = Bluetooth.defaultAdapter
        if (!adapter || !adapter.enabled) return "#6c7086"
        for (const key in Bluetooth.devices) {
            if (Bluetooth.devices[key] && Bluetooth.devices[key].connected) return "#89b4fa"
        }
        return "#cdd6f4"
    }

    // ── Background Pill ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 9
        color: root.popoutOpen ? "#89b4fa"
            : (hovMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // ── Icon Text ────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: getBluetoothIcon()
        color: getBluetoothColor()
        font.family: "FiraCode Nerd Font"
        font.pixelSize: 14
        Behavior on color { ColorAnimation { duration: 150 } }

        // Blink when discovering
        SequentialAnimation on opacity {
            running: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering && !root.popoutOpen
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    // ── Click Handler ────────────────────────────────────────────────────
    MouseArea {
        id: hovMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePopout()
    }
}
