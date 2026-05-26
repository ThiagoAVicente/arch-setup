import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../.." as Root

Item {
    id: root

    property int percentage: 0
    property bool charging: false

    visible: percentage > 0 || charging

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent; radius: 9
        color: batMa.containsMouse ? Root.Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: Root.IconMaps.batteryIcon(root.percentage, root.charging)
            color: {
                if (root.charging) return Root.Theme.ok
                if (root.percentage <= 10) return Root.Theme.critical
                if (root.percentage <= 20) return Root.Theme.alert
                return Root.Theme.subtext
            }
            font.family: Root.Theme.fontFamily
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Text {
            text: root.percentage + "%"
            color: root.percentage <= 20 && !root.charging ? Root.Theme.critical : Root.Theme.subtext
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    // Read capacity + status in one shot
    Process {
        id: batteryCheck
        command: ["sh", "-c",
            "p=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0);" +
            "s=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Discharging);" +
            "echo \"$p $s\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length < 2) return
                root.percentage = parseInt(parts[0]) || 0
                root.charging = parts[1] === "Charging"
            }
        }
    }

    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: batteryCheck.running = true
    }

    MouseArea {
        id: batMa; anchors.fill: parent; hoverEnabled: true
    }
}
