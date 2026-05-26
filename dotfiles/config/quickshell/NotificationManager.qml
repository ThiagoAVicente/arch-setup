import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import "notifications"
import "." as Root

Scope {
    id: notifManager

    // Single sweep timer fires every second, dismisses expired notifs.
    // Replaces per-notification Qt.createQmlObject Timer leak.
    property var _expiry: ({})

    Timer {
        id: expirySweep
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            const now = Date.now()
            let any = false
            for (const n of server.trackedNotifications.values) {
                any = true
                const due = notifManager._expiry[n.id]
                if (due !== undefined && now >= due) n.dismiss()
            }
            if (!any) running = false
        }
    }

    NotificationServer {
        id: server

        onNotification: notification => {
            if (Root.State.notificationsMuted) {
                notification.dismiss()
                return
            }
            notification.tracked = true
            const ms = notification.expireTimeout > 0 ? notification.expireTimeout : 5000
            notifManager._expiry[notification.id] = Date.now() + ms
            expirySweep.running = true
        }
    }

    // One popup panel per screen, only visible on the focused monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property QtObject modelData
            screen: modelData

            anchors { top: true; right: true }
            implicitWidth: 400
            implicitHeight: popupCol.childrenRect.height + 20
            margins { top: 48; right: 16 }

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
