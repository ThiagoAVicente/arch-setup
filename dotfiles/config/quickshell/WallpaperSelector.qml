import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

Scope {
    id: wallpaperSelector
    property bool visible: false
    property string wallpaperDir: "/home/vcnt/Pictures/Wallpapers"
    property var wallpapers: []
    property int selectedIndex: 0
    property string appliedPath: ""

    readonly property int thumbH: 88   // thumbnail height
    readonly property int thumbW: 156  // thumbnail width

    function toggle() {
        visible = !visible
        if (visible) {
            selectedIndex = 0
            if (wallpapers.length === 0) wallpaperListProcess.running = true
            focusRetry.attempts = 0
            focusRetry.start()
        } else {
            focusRetry.stop()
        }
    }

    Process {
        id: wallpaperListProcess
        command: ["sh", "-c",
            "find " + wallpaperSelector.wallpaperDir +
            " -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' -o -name '*.webp' \\)" +
            " 2>/dev/null | sort"]
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim()
                if (p) wallpaperSelector.wallpapers = [...wallpaperSelector.wallpapers, { path: p }]
            }
        }
    }

    Process {
        id: setWallpaperProcess
        onExited: (code) => console.log("[wallpaper] set exited:", code)
    }

    function setWallpaper(path) {
        setWallpaperProcess.command = ["/home/vcnt/scripts/change-wallpaper.sh", path]
        setWallpaperProcess.running = true
        wallpaperSelector.appliedPath = path
        visible = false
    }

    PanelWindow {
        id: panelWindow
        visible: wallpaperSelector.visible
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: 0
        focusable: true
        color: Qt.rgba(0, 0, 0, 0.6)

        TextInput {
            id: focusInput
            visible: false; readOnly: true; text: ""; focus: false
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    wallpaperSelector.visible = false
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (wallpaperSelector.wallpapers.length > 0)
                        wallpaperSelector.setWallpaper(wallpaperSelector.wallpapers[wallpaperSelector.selectedIndex].path)
                } else if (event.key === Qt.Key_Down) {
                    if (wallpaperSelector.selectedIndex < wallpaperSelector.wallpapers.length - 1)
                        wallpaperSelector.selectedIndex++
                } else if (event.key === Qt.Key_Up) {
                    if (wallpaperSelector.selectedIndex > 0)
                        wallpaperSelector.selectedIndex--
                }
                event.accepted = true
            }
        }

        Timer {
            id: focusRetry
            property int attempts: 0
            interval: 60; repeat: false
            onTriggered: {
                attempts++
                try { focusInput.forceActiveFocus() } catch(e) {}
                if (!panelWindow.activeFocus && attempts < 6) focusRetry.start()
            }
        }

        onVisibleChanged: {
            if (visible) { focusRetry.attempts = 0; focusRetry.start() }
            else focusRetry.stop()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: wallpaperSelector.visible = false
            propagateComposedEvents: false
        }

        // ── Drum-roller strip — no background, thumbnails float ────────────
        Item {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: wallpaperSelector.thumbW

            // Stop click-through
            MouseArea { anchors.fill: parent; onClicked: {} }

            ListView {
                id: thumbList
                anchors.fill: parent
                clip: true
                spacing: 8
                model: wallpaperSelector.wallpapers
                currentIndex: wallpaperSelector.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                // Keep selected item locked in center — list scrolls, not cursor
                preferredHighlightBegin: (height - wallpaperSelector.thumbH) / 2
                preferredHighlightEnd:   (height + wallpaperSelector.thumbH) / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveVelocity: 1400
                highlightMoveDuration: -1  // velocity-controlled

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: wallpaperSelector.thumbW
                    height: wallpaperSelector.thumbH

                    readonly property bool isSel: index === wallpaperSelector.selectedIndex

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: "transparent"
                        border.color: isSel ? "#E0E0E0" : "#2A2A2A"
                        border.width: isSel ? 2 : 1
                        clip: true

                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: isSel ? 2 : 1
                            source: "file://" + modelData.path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            opacity: isSel ? 1.0 : 0.45

                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        // "applied" badge
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: 5
                            visible: modelData.path === wallpaperSelector.appliedPath
                            width: lbl.implicitWidth + 10
                            height: 17
                            radius: 2
                            color: "#0D0D0D"

                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text: "applied"
                                color: "#E0E0E0"
                                font.pixelSize: 9
                                font.family: "FiraCode Nerd Font"
                                font.letterSpacing: 1
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: wallpaperSelector.selectedIndex = index
                        onClicked: wallpaperSelector.setWallpaper(modelData.path)
                    }
                }
            }

            // Fade edges — top
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 60
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.6) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Fade edges — bottom
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 60
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
                }
            }
        }
    }
}
