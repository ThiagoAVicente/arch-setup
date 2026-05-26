import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import ".." as Root

Item {
    id: popup
    property var notification

    property color accentColor: {
        let u = popup.notification?.urgency ?? NotificationUrgency.Normal
        if (u === NotificationUrgency.Critical) return Qt.rgba(1, 0.36, 0.36, 1)
        if (u === NotificationUrgency.Low)      return Qt.rgba(0.55, 0.55, 0.65, 1)
        return Qt.rgba(0.49, 0.66, 1, 1)
    }

    visible: notification !== null && notification !== undefined
    height: visible ? card.implicitHeight : 0
    opacity: 0
    x: 40

    Component.onCompleted: if (notification) enterAnim.start()

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: popup; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: popup; property: "x";       from: 40; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card
        anchors { left: parent.left; right: parent.right }
        implicitHeight: inner.implicitHeight + 24
        color: Root.Theme.bg
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        radius: 12

        // Left accent strip
        Rectangle {
            width: 3
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 0 }
            radius: 12
            color: popup.accentColor
        }

        // Clip the left strip corners
        Rectangle {
            width: 3
            height: parent.radius
            anchors { left: parent.left; top: parent.top }
            color: Root.Theme.bg
        }
        Rectangle {
            width: 3
            height: parent.radius
            anchors { left: parent.left; bottom: parent.bottom }
            color: Root.Theme.bg
        }

        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 16 }
            spacing: 8

            // Header: icon + text + close
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // App icon
                Image {
                    source: popup.notification?.icon?.toString() ?? ""
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    fillMode: Image.PreserveAspectFit
                    visible: source !== ""

                    layer.enabled: true
                    layer.effect: null
                }

                // App name + summary
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: popup.notification?.appName ?? ""
                        color: popup.accentColor
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.family: "FiraCode Nerd Font"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text !== ""
                    }

                    Text {
                        text: popup.notification?.summary ?? "Notification"
                        color: Qt.rgba(1, 1, 1, 0.92)
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.family: "FiraCode Nerd Font"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Close button
                Rectangle {
                    id: closeBtn
                    width: 20; height: 20
                    radius: 10
                    color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Layout.alignment: Qt.AlignTop

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 10

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: if (popup.notification) popup.notification.dismiss()
                    }
                }
            }

            // Body
            Text {
                text: popup.notification?.body ?? ""
                color: Qt.rgba(1, 1, 1, 0.62)
                font.pixelSize: 12
                font.family: "FiraCode Nerd Font"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: text !== ""
                lineHeight: 1.3
            }

            // Action buttons
            RowLayout {
                visible: (popup.notification?.actions?.length ?? 0) > 0
                spacing: 6
                Layout.bottomMargin: 2

                Repeater {
                    model: popup.notification?.actions ?? []

                    Rectangle {
                        id: actionBtn
                        required property var modelData

                        Layout.preferredHeight: 26
                        Layout.preferredWidth: Math.max(actionLabel.implicitWidth + 20, 60)
                        color: actionMouse.containsMouse ? popup.accentColor : Qt.rgba(1, 1, 1, 0.08)
                        radius: 6
                        border.color: actionMouse.containsMouse ? "transparent" : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData?.text ?? ""
                            color: actionMouse.containsMouse ? Root.Theme.bg : Qt.rgba(1, 1, 1, 0.75)
                            font.pixelSize: 11
                            font.family: "FiraCode Nerd Font"

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: if (parent.modelData) parent.modelData.invoke()
                        }
                    }
                }
            }
        }

        // Timeout progress bar
        Rectangle {
            id: progressTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 1; rightMargin: 1; bottomMargin: 1 }
            height: 2
            color: Qt.rgba(1, 1, 1, 0.07)
            radius: 1

            Rectangle {
                id: progressFill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: parent.width
                color: popup.accentColor
                opacity: 0.6
                radius: 1

                NumberAnimation on width {
                    id: progressAnim
                    from: progressTrack.width
                    to: 0
                    duration: {
                        let n = popup.notification
                        if (!n) return 5000
                        return n.expireTimeout > 0 ? n.expireTimeout : 5000
                    }
                    running: popup.visible && popup.notification !== null
                    easing.type: Easing.Linear
                }
            }
        }
    }
}
