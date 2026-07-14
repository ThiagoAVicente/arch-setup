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

    readonly property int barThickness: 34

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

            onVisibleChanged: {
                if (visible) {
                    barPill.opacity = 0
                    barPill.anchors.topMargin = -barPill.height
                    showAnim.restart()
                }
            }

            MouseArea { anchors.fill: parent; z: -1; onClicked: barScope.openPopout = "" }

            Rectangle {
                id: barPill
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    leftMargin: 12; rightMargin: 12; topMargin: 4
                }
                height: barScope.barThickness
                radius: height / 2
                color: Root.Theme.barBg
                border.color: Root.Theme.hairline
                border.width: 1

                // Slide + fade in when the bar is shown
                opacity: 1
                Component.onCompleted: { opacity = 0; anchors.topMargin = -height; showAnim.start() }
                ParallelAnimation {
                    id: showAnim
                    NumberAnimation { target: barPill; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation { target: barPill; property: "anchors.topMargin"; to: 4; duration: 260; easing.type: Easing.OutCubic }
                }

                // Inset top highlight — glass depth without a second border
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                    height: 1
                    color: Root.Theme.panelHi
                }

                Item {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 8 }
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
                        rightMargin: 8
                    }
                    spacing: 2
                    SystemTrayWidget {}
                    Item { Layout.preferredWidth: 10 }
                    CpuWidget {}
                    BatteryWidget {}
                    VolumeWidget {}
                    Item { Layout.preferredWidth: 10 }
                    NetworkWidget {
                        popoutOpen: barScope.openPopout === "network"
                        onTogglePopout: barScope.togglePopout("network")
                    }
                    BluetoothWidget {
                        popoutOpen: barScope.openPopout === "bluetooth"
                        onTogglePopout: barScope.togglePopout("bluetooth")
                    }
                    Item { Layout.preferredWidth: 10 }
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
