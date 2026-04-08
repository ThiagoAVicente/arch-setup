pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    required property bool isOpen
    property bool closeOnClickOut: true

    signal closeRequested()

    visible: isOpen
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { top: true; right: true }
    margins.top: 52
    margins.right: 8

    implicitWidth: 304
    implicitHeight: card.height + 8

    // ── Network state ──────────────────────────────────────────────────
    property bool wifiEnabled: true
    property bool scanning: false
    property var networks: []
    property var ethernetDevices: []
    property string view: "wireless"
    property string connectingToSsid: ""
    property bool showPasswordDialog: false
    property var pendingNet: null
    property string passwordValue: ""
    property string connectError: ""

    // ── Helpers ────────────────────────────────────────────────────────
    function parseNetworks(raw) {
        if (!raw || raw.trim().length === 0) return []
        const HOLD = "\u0001"
        const seen = {}
        const result = []
        for (const line of raw.trim().split("\n")) {
            if (!line.trim()) continue
            const safe = line.replace(/\\:/g, HOLD)
            const p = safe.split(":")
            if (p.length < 6) continue
            const ssid = (p[3] || "").replace(/\u0001/g, ":").trim()
            if (!ssid) continue
            const net = {
                active: p[0] === "yes",
                strength: parseInt(p[1]) || 0,
                frequency: parseInt(p[2]) || 0,
                ssid: ssid,
                bssid: (p[4] || "").replace(/\u0001/g, ":").trim(),
                security: (p[5] || "").trim(),
                isSecure: (p[5] || "").trim().length > 0
            }
            if (!seen[ssid]) {
                seen[ssid] = net
                result.push(net)
            } else {
                const idx = result.findIndex(n => n.ssid === ssid)
                if (idx >= 0 && (net.active || (!result[idx].active && net.strength > result[idx].strength)))
                    result[idx] = net
            }
        }
        return result.sort((a, b) => (b.active - a.active) || (b.strength - a.strength)).slice(0, 8)
    }

    function parseEthernet(raw) {
        if (!raw) return []
        const result = []
        for (const line of raw.trim().split("\n")) {
            const p = line.split(":")
            if (p.length < 4 || p[1] !== "ethernet") continue
            result.push({ interface: p[0], connected: p[2] === "connected", connection: p[3] || "" })
        }
        return result
    }

    function refreshAll() {
        networksProc.buf = ""
        networksProc.running = false
        networksProc.running = true
        ethernetProc.buf = ""
        ethernetProc.running = false
        ethernetProc.running = true
        wifiStatusProc.running = false
        wifiStatusProc.running = true
    }

    function doConnect() {
        if (!pendingNet) return
        connectingToSsid = pendingNet.ssid
        connectError = ""
        connectProc.ssid = pendingNet.ssid
        connectProc.bssid = pendingNet.bssid || ""
        connectProc.pwd = passwordValue
        connectProc.errBuf = ""
        connectProc.running = false
        connectProc.running = true
    }

    function handleNetworkClick(net) {
        if (net.active) {
            disconnectProc.running = false
            disconnectProc.running = true
            return
        }
        if (net.isSecure) {
            pendingNet = net
            showPasswordDialog = true
        } else {
            connectingToSsid = net.ssid
            connectError = ""
            connectProc.ssid = net.ssid
            connectProc.bssid = net.bssid || ""
            connectProc.pwd = ""
            connectProc.errBuf = ""
            connectProc.running = false
            connectProc.running = true
        }
    }

    // ── Processes ──────────────────────────────────────────────────────
    Process {
        id: networksProc
        property string buf: ""
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY",
                  "device", "wifi", "list", "--rescan", "no"]
        stdout: SplitParser { onRead: data => networksProc.buf += data + "\n" }
        onRunningChanged: {
            if (!running) {
                root.networks = root.parseNetworks(buf)
                buf = ""
            }
        }
    }

    Process {
        id: ethernetProc
        property string buf: ""
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: SplitParser { onRead: data => ethernetProc.buf += data + "\n" }
        onRunningChanged: {
            if (!running) {
                root.ethernetDevices = root.parseEthernet(buf)
                buf = ""
            }
        }
    }

    Process {
        id: wifiStatusProc
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: SplitParser { onRead: data => root.wifiEnabled = data.trim() === "enabled" }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onRunningChanged: {
            if (!running) {
                root.scanning = false
                root.refreshAll()
            }
        }
    }

    Process {
        id: toggleWifiProc
        property bool wantEnabled: true
        command: ["nmcli", "radio", "wifi", toggleWifiProc.wantEnabled ? "on" : "off"]
        onRunningChanged: { if (!running) root.refreshAll() }
    }

    Process {
        id: connectProc
        property string ssid: ""
        property string bssid: ""
        property string pwd: ""
        property string errBuf: ""
        command: {
            let args = ["nmcli", "--wait", "15", "device", "wifi", "connect", connectProc.ssid]
            if (connectProc.bssid) args = args.concat(["bssid", connectProc.bssid])
            if (connectProc.pwd) args = args.concat(["password", connectProc.pwd])
            return args
        }
        stdout: SplitParser { onRead: data => connectProc.errBuf += data + "\n" }
        stderr: SplitParser { onRead: data => connectProc.errBuf += data + "\n" }
        onRunningChanged: {
            if (!running) {
                const output = errBuf.toLowerCase()
                if (output.includes("error") || output.includes("failed") || output.includes("secrets")) {
                    root.connectError = "Connection failed. Check password."
                    root.connectingToSsid = ""
                } else {
                    root.connectError = ""
                    root.connectingToSsid = ""
                    root.showPasswordDialog = false
                    root.passwordValue = ""
                    root.pendingNet = null
                }
                root.refreshAll()
            }
        }
    }

    Process {
        id: disconnectProc
        command: ["sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE device | grep ':wifi:connected' | cut -d: -f1 | head -1 | xargs -r nmcli device disconnect"]
        onRunningChanged: { if (!running) root.refreshAll() }
    }

    Process {
        id: ethernetConnectProc
        property string connection: ""
        property string iface: ""
        command: ethernetConnectProc.connection
            ? ["nmcli", "con", "up", ethernetConnectProc.connection]
            : ["nmcli", "device", "connect", ethernetConnectProc.iface]
        onRunningChanged: { if (!running) root.refreshAll() }
    }

    Process {
        id: ethernetDisconnectProc
        property string connection: ""
        command: ["nmcli", "con", "down", ethernetDisconnectProc.connection]
        onRunningChanged: { if (!running) root.refreshAll() }
    }

    // Monitor nmcli events
    Process {
        running: root.isOpen
        command: ["nmcli", "m"]
        stdout: SplitParser { onRead: monDebounce.restart() }
    }

    Timer { id: monDebounce; interval: 400; onTriggered: root.refreshAll() }

    Timer {
        interval: 5000; running: root.isOpen; repeat: true
        triggeredOnStart: true; onTriggered: root.refreshAll()
    }

    onIsOpenChanged: {
        if (isOpen) {
            view = "wireless"
            connectError = ""
            showPasswordDialog = false
            passwordValue = ""
            pendingNet = null
            connectingToSsid = ""
            refreshAll()
        }
    }

    // ── UI ─────────────────────────────────────────────────────────────
    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 4

        width: 296
        height: mainCol.implicitHeight + 20
        radius: 14

        color: "#313244"
        border.width: 1
        border.color: "#45475a"

        // Smooth appear animation
        opacity: root.isOpen ? 1 : 0
        scale: root.isOpen ? 1 : 0.95
        transformOrigin: Item.TopRight

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: mainCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 6

            // ── Tabs ──────────────────────────────────────────────────
            RowLayout {
                Layout.topMargin: 4
                spacing: 6

                PopoutTab {
                    tabLabel: "  Wireless"
                    active: root.view === "wireless"
                    onTapped: root.view = "wireless"
                }
                PopoutTab {
                    tabLabel: "  Ethernet"
                    active: root.view === "ethernet"
                    onTapped: root.view = "ethernet"
                }
            }

            // ── Password dialog ───────────────────────────────────────
            Rectangle {
                id: pwDialog
                visible: root.showPasswordDialog && root.view === "wireless"
                Layout.fillWidth: true
                implicitHeight: visible ? (pwCol.implicitHeight + 20) : 0
                color: "#1e1e2e"
                radius: 10
                clip: true

                Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: pwCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 8

                    Text {
                        text: "󰌋  Enter Password"
                        color: "#cdd6f4"; font.family: "FiraCode Nerd Font"
                        font.pixelSize: 13; font.weight: Font.Medium
                    }

                    Text {
                        visible: root.pendingNet !== null
                        text: "Network: " + (root.pendingNet?.ssid ?? "")
                        color: "#a6adc8"; font.pixelSize: 11
                    }

                    Text {
                        visible: root.connectError.length > 0
                        text: root.connectError
                        color: "#f38ba8"; font.pixelSize: 11
                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    FocusScope {
                        id: pwScope
                        Layout.fillWidth: true; implicitHeight: 36
                        activeFocusOnTab: true

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                if (root.passwordValue.length > 0) root.doConnect()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Backspace) {
                                if (event.modifiers & Qt.ControlModifier)
                                    root.passwordValue = ""
                                else
                                    root.passwordValue = root.passwordValue.slice(0, -1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                root.showPasswordDialog = false
                                root.passwordValue = ""
                                root.pendingNet = null
                                root.connectError = ""
                                event.accepted = true
                            } else if (event.text.length > 0 && event.key !== Qt.Key_Tab) {
                                root.passwordValue += event.text
                                event.accepted = true
                            }
                        }

                        Rectangle {
                            anchors.fill: parent; radius: 8
                            color: "#1e1e2e"
                            border.width: pwScope.activeFocus ? 2 : 1
                            border.color: pwScope.activeFocus ? "#cba6f7" : "#45475a"
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.passwordValue.length > 0
                                    ? "•".repeat(root.passwordValue.length)
                                    : "Password..."
                                color: root.passwordValue.length > 0 ? "#cdd6f4" : "#6c7086"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: pwScope.forceActiveFocus()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8

                        ActionButton {
                            Layout.fillWidth: true; label: "Cancel"
                            onTapped: {
                                root.showPasswordDialog = false
                                root.passwordValue = ""
                                root.pendingNet = null
                                root.connectError = ""
                            }
                        }

                        ActionButton {
                            Layout.fillWidth: true
                            label: root.connectingToSsid.length > 0 ? "Connecting…" : "Connect"
                            primary: true
                            isEnabled: root.passwordValue.length > 0 && root.connectingToSsid.length === 0
                            onTapped: root.doConnect()
                        }
                    }
                }
            }

            // ── Wireless header ───────────────────────────────────────
            RowLayout {
                visible: root.view === "wireless" && !root.showPasswordDialog
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "󰤨  Wireless"
                    color: "#cdd6f4"; font.family: "FiraCode Nerd Font"
                    font.pixelSize: 13; font.weight: Font.Medium
                }

                PopoutToggle {
                    isChecked: root.wifiEnabled
                    onToggled: on => {
                        toggleWifiProc.wantEnabled = on
                        toggleWifiProc.running = false
                        toggleWifiProc.running = true
                    }
                }
            }

            Text {
                visible: root.view === "wireless" && !root.showPasswordDialog
                text: root.networks.length + " networks available"
                color: "#6c7086"; font.pixelSize: 11
            }

            // Network list
            Repeater {
                model: (root.view === "wireless" && !root.showPasswordDialog) ? root.networks : []

                delegate: WifiNetworkRow {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    net: modelData
                    isConnecting: root.connectingToSsid === modelData.ssid
                    onConnectClicked: net => root.handleNetworkClick(net)
                    onDisconnectClicked: {
                        disconnectProc.running = false
                        disconnectProc.running = true
                    }
                    onPasswordNeeded: net => {
                        root.pendingNet = net
                        root.showPasswordDialog = true
                    }
                }
            }

            // Rescan button
            Rectangle {
                visible: root.view === "wireless" && !root.showPasswordDialog
                Layout.fillWidth: true; implicitHeight: 34
                radius: 10; color: rescanMa.pressed ? "#585b70"
                    : rescanMa.containsMouse ? "#45475a" : "#1e1e2e"
                border.width: 1; border.color: "#45475a"
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent; spacing: 6

                    Text {
                        text: root.scanning ? "Scanning…" : "󰑓  Rescan networks"
                        color: root.scanning ? "#a6adc8" : "#cba6f7"
                        font.family: "FiraCode Nerd Font"; font.pixelSize: 12
                    }

                    // Spinner
                    Rectangle {
                        visible: root.scanning
                        width: 14; height: 14; radius: 7
                        color: "transparent"
                        border.width: 2; border.color: "#cba6f7"
                        RotationAnimation on rotation {
                            running: root.scanning; from: 0; to: 360
                            duration: 900; loops: Animation.Infinite
                        }
                    }
                }

                MouseArea {
                    id: rescanMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: root.scanning || !root.wifiEnabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root.scanning && root.wifiEnabled
                    onClicked: { root.scanning = true; rescanProc.running = false; rescanProc.running = true }
                }
            }

            // ── Ethernet header ───────────────────────────────────────
            Text {
                visible: root.view === "ethernet"
                text: "󰈀  Ethernet"; Layout.topMargin: 4
                color: "#cdd6f4"; font.family: "FiraCode Nerd Font"
                font.pixelSize: 13; font.weight: Font.Medium
            }

            Text {
                visible: root.view === "ethernet"
                text: root.ethernetDevices.length + " devices available"
                color: "#6c7086"; font.pixelSize: 11
            }

            // Ethernet device list
            Repeater {
                model: root.view === "ethernet" ? root.ethernetDevices : []

                delegate: EthernetRow {
                    required property var modelData
                    Layout.fillWidth: true
                    dev: modelData
                    onConnectClicked: d => {
                        ethernetConnectProc.connection = d.connection || ""
                        ethernetConnectProc.iface = d.interface || ""
                        ethernetConnectProc.running = false
                        ethernetConnectProc.running = true
                    }
                    onDisconnectClicked: d => {
                        ethernetDisconnectProc.connection = d.connection
                        ethernetDisconnectProc.running = false
                        ethernetDisconnectProc.running = true
                    }
                }
            }

            Item { implicitHeight: 4 }
        }
    }

    // ── Inline components ──────────────────────────────────────────────
    component PopoutTab: Item {
        id: tab
        property string tabLabel: ""
        property bool active: false
        signal tapped()

        implicitWidth: tabTxt.implicitWidth + 20
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent; radius: 8
            color: tab.active ? "#cba6f7" : (tMa.containsMouse ? "#45475a" : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: tabTxt
                anchors.centerIn: parent
                text: tab.tabLabel
                color: tab.active ? "#1e1e2e" : "#a6adc8"
                font.family: "FiraCode Nerd Font"; font.pixelSize: 12
            }
        }

        MouseArea { id: tMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: tab.tapped() }
    }

    component PopoutToggle: Item {
        id: tog
        property bool isChecked: false
        signal toggled(bool on)

        implicitWidth: 42; implicitHeight: 22

        Rectangle {
            anchors.fill: parent; radius: 11
            color: tog.isChecked ? "#cba6f7" : "#45475a"
            Behavior on color { ColorAnimation { duration: 200 } }

            Rectangle {
                id: thumb
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: tog.isChecked ? parent.width - width - 3 : 3
                color: "#cdd6f4"
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: tog.toggled(!tog.isChecked) }
    }

    component ActionButton: Item {
        id: btn
        property string label: ""
        property bool primary: false
        property bool isEnabled: true
        signal tapped()

        implicitHeight: 32

        Rectangle {
            anchors.fill: parent; radius: 8
            color: btn.isEnabled
                ? (bMa.pressed
                    ? (btn.primary ? "#a070d8" : "#585b70")
                    : (bMa.containsMouse
                        ? (btn.primary ? "#d4b0f8" : "#45475a")
                        : (btn.primary ? "#cba6f7" : "#45475a")))
                : "#2a2a3e"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: btn.label
                color: btn.primary ? "#1e1e2e" : (btn.isEnabled ? "#cdd6f4" : "#6c7086")
                font.pixelSize: 12
            }
        }

        MouseArea { id: bMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: btn.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: btn.isEnabled; onClicked: btn.tapped() }
    }

    component WifiNetworkRow: Item {
        id: netRow
        property var net: null
        property bool isConnecting: false
        signal connectClicked(var net)
        signal disconnectClicked()
        signal passwordNeeded(var net)

        implicitHeight: 38

        opacity: 0; scale: 0.95
        Component.onCompleted: { opacity = 1; scale = 1 }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent; radius: 8
            color: rowMa.pressed ? "#585b70"
                : rowMa.containsMouse ? "#45475a"
                : netRow.net && netRow.net.active ? Qt.rgba(0.537, 0.706, 0.980, 0.12)
                : "transparent"
            border.width: netRow.net && netRow.net.active ? 1 : 0
            border.color: "#89b4fa"
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 6

                Text {
                    text: {
                        if (!netRow.net) return "󰤭"
                        const s = netRow.net.strength
                        if (s >= 80) return "󰤨"
                        if (s >= 60) return "󰤥"
                        if (s >= 40) return "󰤢"
                        if (s >= 20) return "󰤟"
                        return "󰤯"
                    }
                    color: netRow.net && netRow.net.active ? "#89b4fa" : "#a6adc8"
                    font.family: "FiraCode Nerd Font"; font.pixelSize: 14
                }

                Text {
                    visible: netRow.net && netRow.net.isSecure
                    text: "󰌋"
                    color: "#6c7086"; font.family: "FiraCode Nerd Font"; font.pixelSize: 11
                }

                Text {
                    Layout.fillWidth: true
                    text: netRow.net ? netRow.net.ssid : ""
                    color: netRow.net && netRow.net.active ? "#cdd6f4" : "#a6adc8"
                    font.pixelSize: 12
                    font.weight: netRow.net && netRow.net.active ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }

                // Connect/disconnect button
                Item {
                    id: connBtn; implicitWidth: 26; implicitHeight: 26

                    Rectangle {
                        anchors.fill: parent; radius: 13
                        color: netRow.net && netRow.net.active
                            ? "#89b4fa"
                            : (connBtnMa.pressed ? "#585b70" : connBtnMa.containsMouse ? "#45475a" : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Connecting spinner
                    Rectangle {
                        visible: netRow.isConnecting
                        anchors.centerIn: parent; width: 16; height: 16; radius: 8
                        color: "transparent"; border.width: 2; border.color: "#cba6f7"
                        RotationAnimation on rotation {
                            running: netRow.isConnecting; from: 0; to: 360
                            duration: 800; loops: Animation.Infinite
                        }
                    }

                    Text {
                        visible: !netRow.isConnecting
                        anchors.centerIn: parent
                        text: netRow.net && netRow.net.active ? "󰌸" : "󰌷"
                        color: netRow.net && netRow.net.active ? "#1e1e2e" : "#cdd6f4"
                        font.family: "FiraCode Nerd Font"; font.pixelSize: 13
                    }

                    MouseArea {
                        id: connBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!netRow.net) return
                            if (netRow.net.active)
                                netRow.disconnectClicked()
                            else if (netRow.net.isSecure)
                                netRow.passwordNeeded(netRow.net)
                            else
                                netRow.connectClicked(netRow.net)
                        }
                    }
                }
            }
        }

        MouseArea {
            id: rowMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; z: -1
            onClicked: {
                if (!netRow.net) return
                if (netRow.net.active)
                    netRow.disconnectClicked()
                else if (netRow.net.isSecure)
                    netRow.passwordNeeded(netRow.net)
                else
                    netRow.connectClicked(netRow.net)
            }
        }
    }

    component EthernetRow: Item {
        id: ethRow
        property var dev: null
        signal connectClicked(var d)
        signal disconnectClicked(var d)

        implicitHeight: 38

        Rectangle {
            anchors.fill: parent; radius: 8
            color: ethMa.pressed ? "#585b70"
                : ethMa.containsMouse ? "#45475a"
                : ethRow.dev && ethRow.dev.connected ? Qt.rgba(0.537, 0.706, 0.980, 0.12) : "transparent"
            border.width: ethRow.dev && ethRow.dev.connected ? 1 : 0
            border.color: "#89b4fa"

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 6

                Text {
                    text: "󰈀"
                    color: ethRow.dev && ethRow.dev.connected ? "#89b4fa" : "#a6adc8"
                    font.family: "FiraCode Nerd Font"; font.pixelSize: 14
                }

                Text {
                    Layout.fillWidth: true
                    text: ethRow.dev ? (ethRow.dev.interface || "Unknown") : ""
                    color: ethRow.dev && ethRow.dev.connected ? "#cdd6f4" : "#a6adc8"
                    font.pixelSize: 12
                    font.weight: ethRow.dev && ethRow.dev.connected ? Font.Medium : Font.Normal
                }

                Item {
                    id: ethBtn; implicitWidth: 26; implicitHeight: 26

                    Rectangle {
                        anchors.fill: parent; radius: 13
                        color: ethRow.dev && ethRow.dev.connected
                            ? "#89b4fa"
                            : (ethBtnMa.pressed ? "#585b70" : ethBtnMa.containsMouse ? "#45475a" : "transparent")
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ethRow.dev && ethRow.dev.connected ? "󰌸" : "󰌷"
                        color: ethRow.dev && ethRow.dev.connected ? "#1e1e2e" : "#cdd6f4"
                        font.family: "FiraCode Nerd Font"; font.pixelSize: 13
                    }

                    MouseArea {
                        id: ethBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!ethRow.dev) return
                            if (ethRow.dev.connected) ethRow.disconnectClicked(ethRow.dev)
                            else ethRow.connectClicked(ethRow.dev)
                        }
                    }
                }
            }
        }

        MouseArea { id: ethMa; anchors.fill: parent; hoverEnabled: true; z: -1 }
    }
}
