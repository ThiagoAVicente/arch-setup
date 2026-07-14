import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Scope {
    id: wallpaperSelector
    property bool visible: false
    property string wallpaperDir: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    property var wallpapers: []
    property int selectedIndex: 0
    property string appliedPath: ""

    readonly property int thumbH: 88   // thumbnail height
    readonly property int thumbW: 156  // thumbnail width

    function toggle() {
        visible = !visible
        if (visible) {
            wallpapers = []
            wallpaperListProcess.running = true
            // Start on the currently applied wallpaper
            const idx = wallpapers.findIndex(w => w.path === appliedPath)
            selectedIndex = idx >= 0 ? idx : 0
            jumpTimer.start()
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

    function setWallpaper(path) {
        // execDetached survives Loader unload (Process child would die when WallpaperSelector destroyed)
        Quickshell.execDetached(["sh", "-c", "\"$HOME/scripts/change-wallpaper.sh\" \"$1\"", "sh", path])
        wallpaperSelector.appliedPath = path
        visible = false
    }

    PanelWindow {
        id: panelWindow
        visible: wallpaperSelector.visible
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: -1
        focusable: true
        color: "transparent"
        WlrLayershell.namespace: "qs-overlay"

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

        Timer {
            id: jumpTimer
            interval: 30; repeat: false
            onTriggered: thumbList.positionViewAtIndex(wallpaperSelector.selectedIndex, ListView.Center)
        }

        ParallelAnimation {
            id: wsOpenAnim
            OpacityAnimator  { target: wsStrip;    from: 0;   to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation  { target: wsStrip; property: "anchors.leftMargin"; from: 0; to: 24; duration: 220; easing.type: Easing.OutCubic }
        }

        onVisibleChanged: {
            if (visible) {
                wsStrip.opacity = 0
                wsStrip.anchors.leftMargin = 0
                wsOpenAnim.start()
                focusRetry.attempts = 0
                focusRetry.start()
            } else {
                focusRetry.stop()
            }
        }

        // Click-away close (transparent)
        MouseArea {
            anchors.fill: parent
            onClicked: wallpaperSelector.visible = false
        }

        // ── Drum-roller strip — no background, thumbnails float ────────────
        Item {
            id: wsStrip
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: wallpaperSelector.thumbW
            opacity: 0

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
                    id: wpItem
                    required property var modelData
                    required property int index
                    width: wallpaperSelector.thumbW
                    height: wallpaperSelector.thumbH

                    readonly property bool isSel: index === wallpaperSelector.selectedIndex

                    scale: isSel ? 1.0 : 0.94
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    z: isSel ? 1 : 0

                    // Ambient backlight — the selected thumb glows with its own colors
                    MultiEffect {
                        anchors.fill: thumbClip
                        anchors.margins: -6
                        source: thumbClip
                        visible: wpItem.isSel
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 32
                        opacity: wpItem.isSel ? 0.5 : 0
                        scale: 1.15
                        z: -1
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    ClippingRectangle {
                        id: thumbClip
                        anchors.fill: parent
                        radius: 10
                        color: "#1a1a1c"
                        border.color: wpItem.isSel ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Image {
                            anchors.fill: parent
                            source: "file://" + wpItem.modelData.path
                            sourceSize.width: 240
                            sourceSize.height: 135
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            opacity: wpItem.isSel ? 1.0 : (wpMa.containsMouse ? 0.85 : 0.6)

                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // "applied" badge — state chip with green dot
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: 7
                            visible: wpItem.modelData.path === wallpaperSelector.appliedPath
                            width: badgeRow.implicitWidth + 16
                            height: 17
                            radius: height / 2
                            color: Qt.rgba(0.04, 0.04, 0.05, 0.72)

                            Row {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle {
                                    width: 5; height: 5; radius: 2.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#7fb98a"
                                }
                                Text {
                                    text: "applied"
                                    color: "#e9e9ec"
                                    font.pixelSize: 9
                                    font.family: "FiraCode Nerd Font"
                                    font.letterSpacing: 1
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: wpMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: wallpaperSelector.selectedIndex = index
                        onClicked: wallpaperSelector.setWallpaper(wpItem.modelData.path)
                    }
                }
            }

        }
    }
}
