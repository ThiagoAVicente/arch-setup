pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "bar/widgets"
import "bar/popouts"
import "." as Root

Scope {
    id: barScope

    // Which popout is currently open: "", "network", "bluetooth"
    property string openPopout: ""
    // "normal" = full-width top bar; "compact" = pill at top-left, overlay (no exclusion)
    property string barMode: "normal"

    function togglePopout(name) {
        openPopout = (openPopout === name) ? "" : name
    }

    function toggleBar() {
        barMode = (barMode === "normal") ? "compact" : "normal"
        openPopout = ""
    }

    Calendar { id: cal }

    // ── Main bar ───────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            visible: true

            readonly property bool compact: barScope.barMode === "compact"

            anchors { top: true; left: true; right: !compact }
            implicitHeight: 56
            implicitWidth: compact ? (compactRow.implicitWidth + 28) : 0
            color: "transparent"
            exclusiveZone: compact ? 0 : 44

            // Close popout when clicking outside
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: barScope.openPopout = ""
            }

            // Glow halo behind bar — stacked rings, no MultiEffect (lighter)
            Item {
                anchors {
                    fill: parent
                    leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 8
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: Root.Theme.radiusMd + 3
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: Root.Theme.radiusMd + 1
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.45)
                    border.width: 1
                }
            }

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 8
                }
                radius: Root.Theme.radiusMd
                color: Root.Theme.bg
                border.width: 0

                // ── Left: Clock (normal mode) ─────────────────────────
                Loader {
                    id: normalClockLoader
                    active: !barWindow.compact
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 14 }
                    sourceComponent: Item {
                        width: clkCalNormal.implicitWidth
                        ClockCalendarWidget {
                            id: clkCalNormal
                            anchors.verticalCenter: parent.verticalCenter
                            calendarOpen: cal.visible
                            showCalendar: true
                            onCalHoverChanged: hovered => {
                                cal.iconHovered = hovered
                                if (hovered) cal.open()
                            }
                        }
                    }
                }

                // ── Center workspaces (normal only) ───────────────────
                Loader {
                    active: !barWindow.compact
                    anchors.centerIn: parent
                    sourceComponent: Row {
                        spacing: 5
                        HyprlandWorkspaces {}
                    }
                }

                // ── Compact-mode single tight row (lazy) ──────────────
                Loader {
                    id: compactRow
                    active: barWindow.compact
                    anchors {
                        left: parent.left; top: parent.top; bottom: parent.bottom
                        leftMargin: 14
                    }
                    sourceComponent: RowLayout {
                        spacing: 14
                        ClockCalendarWidget {
                            calendarOpen: cal.visible
                            showCalendar: false
                            onCalHoverChanged: hovered => {
                                cal.iconHovered = hovered
                                if (hovered) cal.open()
                            }
                        }
                        NetworkWidget {
                            popoutOpen: barScope.openPopout === "network"
                            onTogglePopout: barScope.togglePopout("network")
                        }
                        BatteryWidget {}
                    }
                }

                // ── Right: Status icons (normal mode) ────────────────
                Loader {
                    active: !barWindow.compact
                    anchors {
                        right: parent.right; top: parent.top; bottom: parent.bottom
                        rightMargin: 12
                    }
                    sourceComponent: RowLayout {
                        spacing: 4

                        SystemTrayWidget {}
                        Rectangle {
                            width: 1; height: 14
                            color: Root.Theme.borderStrong
                            Layout.alignment: Qt.AlignVCenter
                        }
                        CpuWidget {}
                        BatteryWidget {}
                        VolumeWidget {}
                        Rectangle {
                            width: 1; height: 14
                            color: Root.Theme.borderStrong
                            Layout.alignment: Qt.AlignVCenter
                        }
                        NetworkWidget {
                            popoutOpen: barScope.openPopout === "network"
                            onTogglePopout: barScope.togglePopout("network")
                        }
                        BluetoothWidget {
                            popoutOpen: barScope.openPopout === "bluetooth"
                            onTogglePopout: barScope.togglePopout("bluetooth")
                        }
                        Rectangle {
                            width: 1; height: 14
                            color: Root.Theme.borderStrong
                            Layout.alignment: Qt.AlignVCenter
                        }
                        NotificationsToggle {}
                    }
                }
            }
        }
    }

    // ── Network popout (lazy) ──────────────────────────────────────────
    property bool _networkLoaded: false
    onOpenPopoutChanged: {
        if (openPopout === "network") _networkLoaded = true
        else if (openPopout === "bluetooth") _bluetoothLoaded = true
    }
    Variants {
        model: Quickshell.screens

        Loader {
            required property var modelData
            active: barScope._networkLoaded
            sourceComponent: NetworkPopout {
                screen: modelData
                isOpen: barScope.openPopout === "network"
                onCloseRequested: barScope.openPopout = ""
            }
        }
    }

    // ── Bluetooth popout (lazy) ────────────────────────────────────────
    property bool _bluetoothLoaded: false
    Variants {
        model: Quickshell.screens

        Loader {
            required property var modelData
            active: barScope._bluetoothLoaded
            sourceComponent: BluetoothPopout {
                screen: modelData
                isOpen: barScope.openPopout === "bluetooth"
                onCloseRequested: barScope.openPopout = ""
            }
        }
    }
}
