import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property bool popoutOpen: false
    signal togglePopout()

    implicitWidth: row.implicitWidth + 14
    implicitHeight: 26

    // Background pill
    Rectangle {
        anchors.fill: parent; radius: 9
        color: root.popoutOpen ? "#cba6f7"
            : hovMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            id: wifiIcon
            text: "󰤭"
            color: root.popoutOpen ? "#1e1e2e" : "#cdd6f4"
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 150 } }

            // ── Added: Same blinking animation as Bluetooth widget ─────────
            SequentialAnimation on opacity {
                running: ssidLabel.text === "" && !root.popoutOpen
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
            }
        }

        Text {
            id: ssidLabel
            visible: text.length > 0
            text: ""
            color: root.popoutOpen ? "#1e1e2e" : "#a6adc8"
            font.pixelSize: 11
            elide: Text.ElideRight
            maximumLineCount: 1
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: hovMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePopout()
    }

    // Poll network status every 3 seconds
    Process {
        id: statusProc
        property string buf: ""
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "device", "wifi", "list", "--rescan", "no"]
        stdout: SplitParser { onRead: data => statusProc.buf += data + "\n" }
        onRunningChanged: {
            if (!running) {
                const lines = buf.trim().split("\n")
                buf = ""
                let found = false
                for (const line of lines) {
                    const p = line.split(":")
                    if (p[0] === "yes" && p.length >= 3) {
                        const strength = parseInt(p[1]) || 0
                        const ssid = p.slice(2).join(":").trim()
                        if (strength >= 80) wifiIcon.text = "󰤨"
                        else if (strength >= 60) wifiIcon.text = "󰤥"
                        else if (strength >= 40) wifiIcon.text = "󰤢"
                        else if (strength >= 20) wifiIcon.text = "󰤟"
                        else wifiIcon.text = "󰤯"
                        ssidLabel.text = ssid.length > 12 ? ssid.slice(0, 12) + "…" : ssid
                        found = true
                        break
                    }
                }
                if (!found) {
                    wifiIcon.text = "󰤭"
                    ssidLabel.text = ""
                }
            }
        }
    }

    // Event-driven: subscribe to NetworkManager events (replaces 15s poll)
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: netRefreshDebounce.restart() }
    }

    Timer {
        id: netRefreshDebounce
        interval: 800
        onTriggered: { statusProc.running = false; statusProc.running = true }
    }

    // Fallback slow poll (30s) in case monitor misses events
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statusProc.running = false; statusProc.running = true }
    }
}
