import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import "notifications"
import "." as Root

Scope {
    id: notifManager

    // Single sweep timer (4x/s, keeps dismissal in sync with the progress bar) dismisses expired notifs.
    // Replaces per-notification Qt.createQmlObject Timer leak.
    property var _expiry: ({})

    Timer {
        id: expirySweep
        interval: 250
        repeat: true
        running: false
        onTriggered: {
            const now = Date.now()
            let any = false
            // Drop entries for notifications closed elsewhere (X button, app, replace)
            const live = {}
            for (const n of server.trackedNotifications.values) live[n.id] = true
            for (const id in notifManager._expiry)
                if (!live[id]) delete notifManager._expiry[id]

            for (const n of server.trackedNotifications.values) {
                const due = notifManager._expiry[n.id]
                if (due === undefined) continue
                if (now >= due) {
                    delete notifManager._expiry[n.id]
                    n.dismiss()
                } else {
                    any = true
                }
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
            // expireTimeout 0 = never expire (spec); critical = user must dismiss
            if (Root.NotifTimeout.persistent(notification)) {
                delete notifManager._expiry[notification.id]
                return
            }
            notifManager._expiry[notification.id] = Date.now() + Root.NotifTimeout.ms(notification)
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
            WlrLayershell.namespace: "qs-overlay"

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
