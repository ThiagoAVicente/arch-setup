import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int percentage: 0
    property bool charging: false

    // Don't show if no battery found
    visible: percentage > 0 || charging

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent; radius: 9
        color: batMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: {
                if (root.charging) return "󰂄"
                const p = root.percentage
                if (p > 90) return "󰁹"
                if (p > 80) return "󰂂"
                if (p > 70) return "󰂁"
                if (p > 60) return "󰂀"
                if (p > 50) return "󰁿"
                if (p > 40) return "󰁾"
                if (p > 30) return "󰁽"
                if (p > 20) return "󰁼"
                if (p > 10) return "󰁻"
                return "󰁺"
            }
            color: {
                if (root.charging) return "#a6e3a1"
                if (root.percentage <= 10) return "#f38ba8"
                if (root.percentage <= 20) return "#fab387"
                return "#a6adc8"
            }
            font.family: "FiraCode Nerd Font"; font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Text {
            text: root.percentage + "%"
            color: root.percentage <= 20 && !root.charging ? "#f38ba8" : "#a6adc8"
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    Process {
        id: batteryCheck
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0"]
        running: true
        stdout: SplitParser { onRead: data => root.percentage = parseInt(data.trim()) || 0 }
    }

    Process {
        id: chargeCheck
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Discharging"]
        running: true
        stdout: SplitParser { onRead: data => root.charging = data.trim() === "Charging" }
    }

    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { batteryCheck.running = true; chargeCheck.running = true }
    }

    MouseArea {
        id: batMa; anchors.fill: parent; hoverEnabled: true
    }
}
