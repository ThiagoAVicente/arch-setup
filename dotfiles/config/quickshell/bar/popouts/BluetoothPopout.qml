pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../.." as Root

PanelWindow {
    id: root

    required property bool isOpen
    required property bool anchorLeft
    // Owner of popoutSurface/popoutScreen, shared by all bar popouts
    required property var hub

    signal closeRequested()

    // Lazily created already open, so the first open has no change signal
    Component.onCompleted: if (isOpen) isOpenChanged()
    onIsOpenChanged: {
        if (isOpen) {
            shown = true
            // Switching popouts on the same screen: grow out of the open one
            const prev = hub.popoutSurface
            const swap = prev && prev !== goo && hub.popoutSurfaceScreen === root.screen
                && prev.revealH > 0
            goo.fromW = swap ? Math.round(prev.revealW) : 0
            goo.fromH = swap ? Math.round(prev.revealH) : 0
            if (swap) prev.handOff(goo.fullW, goo.fullH)
            hub.popoutSurface = goo
            hub.popoutSurfaceScreen = root.screen
            goo.open()
        } else {
            // The next popout may still take over the draining surface
            goo.close()
        }
        // Don't leave the radio scanning after the popout closes
        const adapter = Bluetooth.defaultAdapter
        if (!isOpen && adapter && adapter.discovering) adapter.discovering = false
    }

    // Stays mapped while the surface drains back into the bar
    property bool shown: false
    visible: shown
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Same drawer surface as the launcher/todo: no blur, no compositor
    // layer anim, and above the bar so the drop fuses with the pill
    WlrLayershell.namespace: "qs-drawer"
    WlrLayershell.layer: WlrLayer.Overlay

    // Hang below the pill's flat bottom edge, clear of its rounded end
    anchors { top: true; left: anchorLeft; right: !anchorLeft }
    margins.left: anchorLeft ? Root.Theme.barMarginSide + Root.Theme.barThickness / 2 : 0
    margins.right: anchorLeft ? 0 : Root.Theme.barMarginSide + Root.Theme.barThickness / 2

    // Room for the fillets at the join and the overshoot/ripple below
    implicitWidth: goo.fullW + 40
    implicitHeight: goo.topY + goo.fullH + 72
    // Only the card takes input; the rest of the window is see-through
    mask: Region { item: card }

    Root.LiquidSurface {
        id: goo
        fullW: 296
        fullH: card.height + 1
        onClosed: root.shown = false
    }

    // ── Helpers ────────────────────────────────────────────────────────
    function btIcon(iconStr) {
        if (!iconStr) return "󰂯"
        const s = iconStr.toLowerCase()
        if (s.includes("headset") || s.includes("headphone")) return "󰋋"
        if (s.includes("audio") || s.includes("speaker")) return "󰓃"
        if (s.includes("phone")) return "󰄜"
        if (s.includes("mouse")) return "󰍽"
        if (s.includes("keyboard")) return "󰌌"
        if (s.includes("joystick") || s.includes("game")) return "󰊖"
        return "󰂯"
    }

    function batteryIcon(pct) {
        if (pct < 0) return ""
        if (pct >= 95) return "󰁹"
        if (pct >= 80) return "󰂂"
        if (pct >= 65) return "󰂀"
        if (pct >= 50) return "󰁿"
        if (pct >= 35) return "󰁽"
        if (pct >= 20) return "󰁼"
        if (pct >= 5)  return "󰁻"
        return "󰁺"
    }

    // ── UI ─────────────────────────────────────────────────────────────
    Item {
        id: card

        // Content only — the LiquidSurface is its surface
        x: goo.cardX
        y: goo.cardY
        width: goo.fullW
        height: mainCol.implicitHeight + 20
        opacity: goo.contentOpacity

        ColumnLayout {
            id: mainCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 6

            // ── Header ────────────────────────────────────────────────
            Text {
                Layout.topMargin: 4
                text: "󰂯  Bluetooth"
                color: Root.Theme.text; font.family: "FiraCode Nerd Font"
                font.pixelSize: 13; font.weight: Font.Medium
            }

            // Enabled toggle
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Enabled"
                    color: Root.Theme.subtext; font.pixelSize: 12
                }

                BtToggle {
                    isChecked: Bluetooth.defaultAdapter?.enabled ?? false
                    onToggled: on => {
                        const adapter = Bluetooth.defaultAdapter
                        if (adapter) adapter.enabled = on
                    }
                }
            }

            // Discovering toggle
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Scan for devices"
                    color: Root.Theme.subtext; font.pixelSize: 12
                }

                BtToggle {
                    isChecked: Bluetooth.defaultAdapter?.discovering ?? false
                    onToggled: on => {
                        const adapter = Bluetooth.defaultAdapter
                        if (adapter) adapter.discovering = on
                    }
                }
            }

            // Device count
            Text {
                text: {
                    const devs = Bluetooth.devices.values
                    const total = devs.length
                    const conn = devs.filter(d => d.connected).length
                    let s = total + " device" + (total !== 1 ? "s" : "")
                    if (conn > 0) s += " · " + conn + " connected"
                    return s
                }
                color: Root.Theme.muted; font.pixelSize: 11; Layout.topMargin: 2
            }

            // ── Device list ───────────────────────────────────────────
            Repeater {
                model: ScriptModel {
                    values: [...Bluetooth.devices.values]
                        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
                        .slice(0, 6)
                }

                delegate: BtDeviceRow {
                    required property BluetoothDevice modelData
                    Layout.fillWidth: true
                    device: modelData
                    iconText: root.btIcon(modelData.icon)
                    battText: {
                        if (!modelData.connected || !modelData.batteryAvailable) return ""
                        return root.batteryIcon(Math.round(modelData.battery * 100))
                    }
                    battLow: modelData.batteryAvailable && modelData.battery < 0.2
                }
            }

            // ── Settings button ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.topMargin: 6
                implicitHeight: 34; radius: 10
                color: settingsMa.pressed ? Root.Theme.overlay
                    : settingsMa.containsMouse ? Root.Theme.surface2 : Root.Theme.bg
                border.width: 1; border.color: Root.Theme.surface2
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒓  Open Settings"
                    color: Root.Theme.accent; font.family: "FiraCode Nerd Font"; font.pixelSize: 12
                }

                MouseArea {
                    id: settingsMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["blueman-manager"])
                }
            }

            Item { implicitHeight: 4 }
        }
    }

    // ── Inline components ──────────────────────────────────────────────
    component BtToggle: Item {
        id: btTog
        property bool isChecked: false
        signal toggled(bool on)

        implicitWidth: 42; implicitHeight: 22

        Rectangle {
            anchors.fill: parent; radius: 11
            color: btTog.isChecked ? Root.Theme.text : Root.Theme.surface2
            Behavior on color { ColorAnimation { duration: 200 } }

            Rectangle {
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: btTog.isChecked ? parent.width - width - 3 : 3
                color: Root.Theme.text
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: btTog.toggled(!btTog.isChecked) }
    }

    component BtDeviceRow: Item {
        id: devRow
        property BluetoothDevice device: null
        property string iconText: "󰂯"
        property string battText: ""
        property bool battLow: false

        readonly property bool isConnecting: device?.state === BluetoothDeviceState.Connecting
            || device?.state === BluetoothDeviceState.Disconnecting
        readonly property bool isConnected: device?.state === BluetoothDeviceState.Connected

        implicitHeight: 40

        opacity: 0; scale: 0.95
        Component.onCompleted: { opacity = 1; scale = 1 }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent; radius: 8
            color: devMa.pressed ? Root.Theme.overlay
                : devMa.containsMouse ? Root.Theme.surface2
                : devRow.isConnected ? Qt.rgba(0.537, 0.706, 0.980, 0.12) : "transparent"
            border.width: devRow.isConnected ? 1 : 0
            border.color: Root.Theme.text
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8

                Text {
                    text: devRow.iconText
                    color: devRow.isConnected ? Root.Theme.text : Root.Theme.subtext
                    font.family: "FiraCode Nerd Font"; font.pixelSize: 15
                }

                Text {
                    Layout.fillWidth: true
                    text: devRow.device?.name ?? ""
                    color: devRow.isConnected ? Root.Theme.text : Root.Theme.subtext
                    font.pixelSize: 12
                    font.weight: devRow.isConnected ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }

                // Battery
                Text {
                    visible: devRow.battText.length > 0
                    text: devRow.battText
                    color: devRow.battLow ? Root.Theme.critical : Root.Theme.muted
                    font.family: "FiraCode Nerd Font"; font.pixelSize: 12
                }

                // Connect button
                Item {
                    id: connBtn; implicitWidth: 26; implicitHeight: 26

                    Rectangle {
                        anchors.fill: parent; radius: 13
                        color: devRow.isConnected
                            ? Root.Theme.text
                            : (cBtnMa.pressed ? Root.Theme.overlay : cBtnMa.containsMouse ? Root.Theme.surface2 : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Connecting spinner
                    Rectangle {
                        visible: devRow.isConnecting
                        anchors.centerIn: parent; width: 16; height: 16; radius: 8
                        color: "transparent"; border.width: 2; border.color: Root.Theme.accent
                        RotationAnimation on rotation {
                            running: devRow.isConnecting; from: 0; to: 360
                            duration: 800; loops: Animation.Infinite
                        }
                    }

                    Text {
                        visible: !devRow.isConnecting
                        anchors.centerIn: parent
                        text: devRow.isConnected ? "󰌸" : "󰌷"
                        color: devRow.isConnected ? Root.Theme.bg : Root.Theme.text
                        font.family: "FiraCode Nerd Font"; font.pixelSize: 13
                    }

                    MouseArea {
                        id: cBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (devRow.device) devRow.device.connected = !devRow.device.connected
                    }
                }

                // Forget button (only for bonded devices)
                Loader {
                    active: devRow.device?.bonded ?? false
                    visible: status === Loader.Ready
                    asynchronous: true

                    sourceComponent: Item {
                        implicitWidth: 26; implicitHeight: 26

                        Rectangle {
                            anchors.fill: parent; radius: 13
                            color: forgMa.pressed ? Root.Theme.critical : (forgMa.containsMouse ? "#4a1c2a" : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent; text: "󰆴"
                            color: forgMa.containsMouse ? Root.Theme.critical : Root.Theme.muted
                            font.family: "FiraCode Nerd Font"; font.pixelSize: 13
                        }

                        MouseArea {
                            id: forgMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devRow.device?.forget()
                        }
                    }
                }
            }
        }

        MouseArea { id: devMa; anchors.fill: parent; hoverEnabled: true; z: -1 }
    }
}
