pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "bar/widgets"
import "bar/popouts"

Scope {
    id: barScope

    // Which popout is currently open: "", "network", "bluetooth"
    property string openPopout: ""
    property bool barVisible: true

    function togglePopout(name) {
        openPopout = (openPopout === name) ? "" : name
    }

    function toggleBar() {
        barVisible = !barVisible
    }

    Calendar { id: cal }

    // ── Main bar ───────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            visible: barScope.barVisible

            anchors { top: true; left: true; right: true }
            implicitHeight: 44
            color: "transparent"

            // Close popout when clicking outside
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: barScope.openPopout = ""
            }

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 8; rightMargin: 8; topMargin: 4
                }
                radius: 12
                color: "#1e1e2e"
                border.color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1

                // ── Left: Clock ───────────────────────────────────────
                Item {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 14 }
                    width: clkCal.implicitWidth

                    ClockCalendarWidget {
                        id: clkCal
                        anchors.verticalCenter: parent.verticalCenter
                        calendarOpen: cal.visible
                        onCalHoverChanged: hovered => {
                            cal.iconHovered = hovered
                            if (hovered) cal.open()
                        }
                    }
                }

                // ── Center: Workspaces ────────────────────────────────
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    HyprlandWorkspaces {}
                }

                // ── Right: Status icons ───────────────────────────────
                RowLayout {
                    anchors {
                        right: parent.right; top: parent.top; bottom: parent.bottom
                        rightMargin: 12
                    }
                    spacing: 4

                    // System tray
                   // SystemTrayWidget {}

                    // Separator
                    Rectangle {
                        width: 1; height: 14
                        color: Qt.rgba(1,1,1,0.1)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // CPU
                    CpuWidget {}

                    // Battery
                    BatteryWidget {}

                    // Volume
                    VolumeWidget {}

                    // Separator
                    Rectangle {
                        width: 1; height: 14
                        color: Qt.rgba(1,1,1,0.1)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Network
                    NetworkWidget {
                        popoutOpen: barScope.openPopout === "network"
                        onTogglePopout: barScope.togglePopout("network")
                    }

                    // Bluetooth
                    BluetoothWidget {
                        popoutOpen: barScope.openPopout === "bluetooth"
                        onTogglePopout: barScope.togglePopout("bluetooth")
                    }

                    // Separator
                    Rectangle {
                        width: 1; height: 14
                        color: Qt.rgba(1,1,1,0.1)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Notifications
                    NotificationsToggle {}
                }
            }
        }
    }

    // ── Network popout window ──────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        NetworkPopout {
            required property var modelData
            screen: modelData
            isOpen: barScope.openPopout === "network"
            onCloseRequested: barScope.openPopout = ""
        }
    }

    // ── Bluetooth popout window ────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        BluetoothPopout {
            required property var modelData
            screen: modelData
            isOpen: barScope.openPopout === "bluetooth"
            onCloseRequested: barScope.openPopout = ""
        }
    }
}
