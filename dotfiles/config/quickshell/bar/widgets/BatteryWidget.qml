import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: batteryWidget
    spacing: 4

    property int percentage: 0
    property bool charging: false

    Process {
        id: batteryCheck
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                batteryWidget.percentage = parseInt(data.trim()) || 0
            }
        }
    }

    Process {
        id: chargeCheck
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Discharging"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                batteryWidget.charging = data.trim() === "Charging"
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            batteryCheck.running = true
            chargeCheck.running = true
        }
    }

    Text {
        text: {
            if (batteryWidget.charging) return "󰂄"
            let pct = batteryWidget.percentage
            if (pct > 90) return "󰁹"
            if (pct > 80) return "󰂂"
            if (pct > 70) return "󰂁"
            if (pct > 60) return "󰂀"
            if (pct > 50) return "󰁿"
            if (pct > 40) return "󰁾"
            if (pct > 30) return "󰁽"
            if (pct > 20) return "󰁼"
            if (pct > 10) return "󰁻"
            return "󰁺"
        }
        color: batteryWidget.percentage < 20 && !batteryWidget.charging
               ? Qt.rgba(1, 0.4, 0.4, 1) : Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 14
        font.family: "FiraCode Nerd Font"
    }

    Text {
        text: batteryWidget.percentage + "%"
        color: Qt.rgba(1, 1, 1, 0.7)
        font.pixelSize: 11
    }
}
