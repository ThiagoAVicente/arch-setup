import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 6

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property var modelData
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            visible: (modelData.icon ?? "").length > 0 && !(modelData.icon ?? "").includes("?")

            Image {
                anchors.fill: parent
                source: {
                    let icon = modelData.icon ?? ""
                    if (!icon || icon.includes("?")) return ""
                    return icon
                }
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: status === Image.Ready
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom | Edges.Right
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || trayItem.modelData.menu) {
                        menuAnchor.open()
                    } else {
                        trayItem.modelData.activate()
                    }
                }
            }
        }
    }
}
