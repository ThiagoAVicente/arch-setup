import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "bar/widgets"

Scope {
    Calendar { id: cal }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property QtObject modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 40
            color: "transparent"

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                    topMargin: 4
                }
                radius: 12
                color: Qt.rgba(0.07, 0.07, 0.09, 0.88)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                // Left - Clock + calendar icon
                Item {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 16 }
                    width: 130

                    ClockCalendarWidget {
                        anchors.verticalCenter: parent.verticalCenter
                        calendarOpen: cal.visible
                        onCalHoverChanged: (hovered) => {
                            cal.iconHovered = hovered
                            if (hovered) cal.open()
                        }
                    }
                }

                // Center - Workspaces
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    HyprlandWorkspaces {}
                }

                // Right - Status
                Item {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 12 }
                    width: 280

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 4

                        SystemTrayWidget {}

                        Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.1); anchors.verticalCenter: parent.verticalCenter }

                        CpuWidget {}
                        BatteryWidget {}
                        VolumeWidget {}

                        Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.1); anchors.verticalCenter: parent.verticalCenter }

                        NotificationsToggle {}
                    }
                }
            }
        }
    }
}
