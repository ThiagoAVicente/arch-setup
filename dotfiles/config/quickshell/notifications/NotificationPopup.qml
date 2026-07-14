import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import ".." as Root

Item {
    id: popup
    property var notification

    readonly property bool isCritical:
        (popup.notification?.urgency ?? NotificationUrgency.Normal) === NotificationUrgency.Critical

    // Mono by default; urgency shows only when it matters
    property color accentColor: isCritical ? Root.Theme.critical : Qt.rgba(1, 1, 1, 0.35)

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
        implicitHeight: inner.implicitHeight + 26
        color: Root.Theme.panelFrost
        border.color: popup.isCritical ? Qt.rgba(0.85, 0.48, 0.55, 0.4) : Root.Theme.hairline
        border.width: 1
        radius: 14

        // Inset top highlight
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
            height: 1
            color: Root.Theme.panelHi
        }

        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 13; leftMargin: 15 }
            spacing: 8

            // Header: icon + text + close
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // App icon in a tile — same treatment as launcher rows
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    radius: 9
                    color: Qt.rgba(1, 1, 1, 0.05)
                    visible: appIcon.source.toString() !== ""

                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: popup.notification?.icon?.toString() ?? ""
                        fillMode: Image.PreserveAspectFit
                    }
                }

                // App name + summary
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: (popup.notification?.appName ?? "").toUpperCase()
                        color: popup.isCritical ? Root.Theme.critical : Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 9
                        font.letterSpacing: 1.4
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

                    // Ghost buttons — hairline outline, invert to white on hover
                    Rectangle {
                        id: actionBtn
                        required property var modelData

                        Layout.preferredHeight: 26
                        Layout.preferredWidth: Math.max(actionLabel.implicitWidth + 26, 60)
                        color: actionMouse.containsMouse ? "#eeeef0" : "transparent"
                        radius: 8
                        border.color: actionMouse.containsMouse ? "transparent" : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 130 } }

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData?.text ?? ""
                            color: actionMouse.containsMouse ? "#0e0e10" : Qt.rgba(1, 1, 1, 0.78)
                            font.pixelSize: 11
                            font.family: "FiraCode Nerd Font"

                            Behavior on color { ColorAnimation { duration: 130 } }
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

        // Timeout progress hairline
        Rectangle {
            id: progressTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 1 }
            height: 2
            color: Qt.rgba(1, 1, 1, 0.06)
            radius: 1

            Rectangle {
                id: progressFill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: parent.width
                color: popup.isCritical ? Root.Theme.critical : Qt.rgba(1, 1, 1, 0.35)
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
