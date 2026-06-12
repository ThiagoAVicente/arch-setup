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

                // Pass pixmap sources directly
                if (!raw.startsWith("image://icon/")) {
                    resolvedIcon = raw
                    return
                }

                const stripped = raw.slice(13) // remove "image://icon/"

                // ?path= means icon lives in a specific dir (e.g. Steam)
                if (stripped.includes("?path=")) {
                    const [namePart, dirPath] = stripped.split("?path=")
                    const iconName = namePart.slice(namePart.lastIndexOf("/") + 1)
                    resolvedIcon = "file://" + dirPath + "/" + iconName + ".png"
                    return
                }

                if (root.iconCache[stripped] !== undefined) {
                    resolvedIcon = root.iconCache[stripped]
                    return
                }

                finder.iconName = stripped
                finder.running = true
            }

            Component.onCompleted: resolve()
            onModelDataChanged: resolve()

            Process {
                id: clickRunner
                running: false
            }

            Process {
                id: finder
                property string iconName: ""
                running: false
                command: ["sh", "-c",
                    "find /usr/share/icons /usr/local/share/icons -maxdepth 6 \\( -path '*/cursors' -o -path '*/emblems' -o -path '*/mimetypes' \\) -prune -o -name '" + finder.iconName + ".*' -print 2>/dev/null | grep -E '\\.(svg|png)$' | grep -E '(22x22|24x24|16x16|scalable|panel|status|apps)' | head -1"
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
                asynchronous: true
                implicitSize: 32
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
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: event => {
                    const item = trayItem.modelData
                    if (!item) return
                    const id = (item.id || "").toLowerCase()
                    // Normalize tray id → process basename (e.g. "spotify_client" → "spotify")
                    const proc = id.replace(/[_-]?(client|app|tray)$/, "")
                    if (event.button === Qt.RightButton) {
                        // Right-click → kill
                        if (proc) {
                            clickRunner.command = ["sh", "-c",
                                "pkill -x '" + proc + "' || pkill -if '" + proc + "'"]
                            clickRunner.running = true
                        }
                    } else if (event.button === Qt.MiddleButton) {
                        item.secondaryActivate()
                    } else {
                        if (id === "steam") {
                            clickRunner.command = ["steam", "steam://open/main"]
                            clickRunner.running = true
                        } else if (id.includes("spotify")) {
                            // Raise via MPRIS (works even when window is hidden in tray)
                            clickRunner.command = ["sh", "-c",
                                "playerctl -p spotify raise 2>/dev/null || (hyprctl clients -j | grep -qi '\"class\": \"[Ss]potify\"' && hyprctl dispatch focuswindow class:Spotify) || spotify"]
                            clickRunner.running = true
                        } else {
                            item.activate()
                        }
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
