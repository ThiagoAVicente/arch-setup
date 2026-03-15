import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import "notifications"
import "." as Root

Scope {
    id: notifManager

    NotificationServer {
        id: server

        onNotification: notification => {
            if (Root.State.notificationsMuted) {
                notification.dismiss()
                return
            }
            notification.tracked = true

            // Auto-dismiss
            let ms = notification.expireTimeout > 0 ? notification.expireTimeout : 5000
            let t = Qt.createQmlObject(
                'import QtQuick; Timer { interval: ' + ms + '; running: true; repeat: false }',
                notifManager
            )
            t.triggered.connect(() => {
                if (notification.tracked) notification.dismiss()
                t.destroy()
            })
        }
    }

    // One popup panel per screen, only visible on the focused monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property QtObject modelData
            screen: modelData

            anchors { top: true; right: true }
            implicitWidth: 380
            implicitHeight: popupCol.childrenRect.height + 20
            margins { top: 40; right: 20 }

            exclusiveZone: 0
            color: "transparent"

            // Only show on the monitor with the focused workspace
            visible: {
                if (server.trackedNotifications.values.length === 0) return false
                let fw = Hyprland.focusedWorkspace
                if (!fw) return modelData === Quickshell.screens.values[0]
                for (let m of Hyprland.monitors.values) {
                    if (m.activeWorkspace && m.activeWorkspace.id === fw.id) {
                        return m.name === modelData.name
                    }
                }
                return false
            }

            Column {
                id: popupCol
                spacing: 10
                width: parent.width

                Repeater {
                    model: server.trackedNotifications

                    NotificationPopup {
                        required property var modelData
                        notification: modelData
                        width: popupCol.width
                    }
                }
            }
        }
    }
}
