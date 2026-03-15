import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: popup
    property var notification

    visible: notification !== null && notification !== undefined
    height: visible ? layout.implicitHeight + 20 : 0
    color: Qt.rgba(0.1, 0.1, 0.1, 0.9)
    border.color: Qt.rgba(1, 1, 1, 0.15)
    border.width: 1
    radius: 10

    opacity: 0
    Component.onCompleted: if (notification) fadeIn.start()

    NumberAnimation {
        id: fadeIn
        target: popup
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        visible: popup.notification !== null

        Image {
            source: popup.notification?.icon?.toString() ?? ""
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop
            fillMode: Image.PreserveAspectFit
            visible: source !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: popup.notification?.summary ?? "Notification"
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: "✕"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (popup.notification) popup.notification.dismiss()
                        hoverEnabled: true
                        onEntered: parent.color = Qt.rgba(1, 1, 1, 0.8)
                        onExited: parent.color = Qt.rgba(1, 1, 1, 0.4)
                    }
                }
            }

            Text {
                text: popup.notification?.body ?? ""
                color: Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            RowLayout {
                visible: (popup.notification?.actions?.length ?? 0) > 0
                spacing: 6

                Repeater {
                    model: popup.notification?.actions ?? []

                    Rectangle {
                        required property var modelData

                        Layout.preferredHeight: 24
                        Layout.preferredWidth: actionText.implicitWidth + 16
                        color: Qt.rgba(1, 1, 1, 0.1)
                        radius: 4

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.modelData?.text ?? ""
                            color: Qt.rgba(1, 1, 1, 0.8)
                            font.pixelSize: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (parent.modelData) parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
