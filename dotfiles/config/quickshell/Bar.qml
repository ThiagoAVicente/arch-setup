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

    property string openPopout: ""
    property bool barHidden: false

    readonly property int barThickness: 28

    function togglePopout(name) {
        openPopout = (openPopout === name) ? "" : name
    }

    function toggleBar() {
        barHidden = !barHidden
        openPopout = ""
    }

    Calendar { id: cal }

    // ── Horizontal bar (top) ───────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: hBar
            required property var modelData
            screen: modelData
            visible: !barScope.barHidden

            anchors { top: true; left: true; right: true }
            implicitHeight: barScope.barThickness + 8
            color: "transparent"
            exclusiveZone: barScope.barThickness

            MouseArea { anchors.fill: parent; z: -1; onClicked: barScope.openPopout = "" }

            Item {
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    leftMargin: 8; rightMargin: 8; topMargin: 4
                }
                height: barScope.barThickness
                Rectangle {
                    anchors.fill: parent; anchors.margins: -3
                    radius: Root.Theme.radiusMd + 3
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: -1
                    radius: Root.Theme.radiusMd + 1
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.55); border.width: 1
                }
            }

            Rectangle {
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    leftMargin: 8; rightMargin: 8; topMargin: 4
                }
                height: barScope.barThickness
                radius: Root.Theme.radiusMd
                color: Root.Theme.barBg

                Item {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 14 }
                    width: hClk.implicitWidth
                    ClockCalendarWidget {
                        id: hClk
                        anchors.verticalCenter: parent.verticalCenter
                        calendarOpen: cal.visible
                        showCalendar: true
                        onCalHoverChanged: hovered => {
                            cal.iconHovered = hovered
                            if (hovered) cal.open()
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    HyprlandWorkspaces {}
                }

                RowLayout {
                    anchors {
                        right: parent.right; top: parent.top; bottom: parent.bottom
                        rightMargin: 12
                    }
                    spacing: 4
                    SystemTrayWidget {}
                    Rectangle { width: 1; height: 14; color: Root.Theme.borderStrong; Layout.alignment: Qt.AlignVCenter }
                    CpuWidget {}
                    BatteryWidget {}
                    VolumeWidget {}
                    Rectangle { width: 1; height: 14; color: Root.Theme.borderStrong; Layout.alignment: Qt.AlignVCenter }
                    NetworkWidget {
                        popoutOpen: barScope.openPopout === "network"
                        onTogglePopout: barScope.togglePopout("network")
                    }
                    BluetoothWidget {
                        popoutOpen: barScope.openPopout === "bluetooth"
                        onTogglePopout: barScope.togglePopout("bluetooth")
                    }
                    Rectangle { width: 1; height: 14; color: Root.Theme.borderStrong; Layout.alignment: Qt.AlignVCenter }
                    NotificationsToggle {}
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
                anchorLeft: false
                onCloseRequested: barScope.openPopout = ""
            }
        }
    }

    property bool _bluetoothLoaded: false
    Variants {
        model: Quickshell.screens
        Loader {
            required property var modelData
            active: barScope._bluetoothLoaded
            sourceComponent: BluetoothPopout {
                screen: modelData
                isOpen: barScope.openPopout === "bluetooth"
                anchorLeft: false
                onCloseRequested: barScope.openPopout = ""
            }
        }
    }
}
