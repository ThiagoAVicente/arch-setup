import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 4

    property var iconCache: ({})

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property SystemTrayItem modelData

            readonly property bool hidden: ["nm-applet", "blueman"].includes(modelData?.id ?? "")
            implicitWidth: hidden ? 0 : 22
            implicitHeight: hidden ? 0 : 22
            visible: !hidden

            property string resolvedIcon: ""

            function resolve() {
                const raw = modelData?.icon ?? ""
                if (!raw) return

                // Pass pixmap/path sources directly
                if (!raw.startsWith("image://icon/")) {
                    resolvedIcon = raw
                    return
                }

                const name = raw.slice(13)

                if (root.iconCache[name] !== undefined) {
                    resolvedIcon = root.iconCache[name]
                    return
                }

                finder.iconName = name
                finder.running = true
            }

            Component.onCompleted: resolve()
            onModelDataChanged: resolve()

            Process {
                id: finder
                property string iconName: ""
                running: false
                command: ["sh", "-c",
                    "find /usr/share/icons /usr/local/share/icons -name '" + finder.iconName + ".*' 2>/dev/null | grep -E '\\.(svg|png)$' | grep -E '(22x22|24x24|16x16|scalable|panel|status|apps)' | head -1"
                ]
                stdout: SplitParser {
                    onRead: data => {
                        const path = data.trim()
                        const result = path ? "file://" + path : ""
                        root.iconCache[finder.iconName] = result
                        trayItem.resolvedIcon = result
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: tMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            IconImage {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: trayItem.resolvedIcon
                smooth: true
            }

            Loader {
                active: trayItem.modelData?.hasMenu ?? false
                sourceComponent: QsMenuAnchor {
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
                        if (trayItem.modelData?.menu)
                            trayItem.modelData.menu.open()
                    } else {
                        trayItem.modelData?.activate?.()
                    }
                }

                onPressAndHold: {
                    if (trayItem.modelData?.menu)
                        trayItem.modelData.menu.open()
                }
            }
        }
    }
}
