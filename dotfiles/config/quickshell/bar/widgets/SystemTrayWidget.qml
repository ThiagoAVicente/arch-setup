pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 4

    Repeater {
        model: SystemTray.items
        delegate: TrayItemDelegate {}
    }

    component TrayItemDelegate: Item {
        id: trayItem
        property SystemTrayItem modelData

        implicitWidth: 22
        implicitHeight: 22

        // Background on hover
        Rectangle {
            anchors.fill: parent
            radius: 6
            color: tMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Icon
        IconImage {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: {
                const icon = trayItem.modelData?.icon ?? ""
                if (!icon) return ""
                if (icon.includes("?path=")) {
                    const [name, path] = icon.split("?path=")
                    return Qt.resolvedUrl(path + "/" + name.slice(name.lastIndexOf("/") + 1))
                }
                return icon
            }
            asynchronous: true
            smooth: true
            visible: status === Image.Ready
        }

        // ── Menu Anchor (Only loads when menu exists) ───────────────────
        Loader {
            active: trayItem.modelData?.menu !== undefined && trayItem.modelData?.menu !== null
            sourceComponent: QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.edges: Qt.BottomEdge
            }
        }

        MouseArea {
            id: tMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    // Try QsMenuAnchor first, fallback to direct open
                    if (trayItem.modelData?.menu) {
                        const anchor = trayItem.children.find(c => c.objectName === "menuAnchor" || c instanceof QsMenuAnchor)
                        if (anchor && anchor.active) {
                            anchor.item?.open?.()
                        } else {
                            trayItem.modelData.menu.open()
                        }
                    }
                } else {
                    trayItem.modelData?.activate?.()
                }
            }

            onPressAndHold: {
                if (trayItem.modelData?.menu) {
                    trayItem.modelData.menu.open()
                }
            }
        }
    }
}
