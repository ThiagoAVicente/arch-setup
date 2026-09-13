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
    property string liveWallpaperDir: (Quickshell.env("HOME") || "") + "/Videos/live-wallpapers"
    property string thumbCacheDir: (Quickshell.env("HOME") || "") + "/.cache/wallpaper-thumbs"
    property var wallpapers: []
    // Bumped a few times after list load to force Image reload once thumbs land on disk
    property int thumbGen: 0

    function thumbCachePath(path) {
        return wallpaperSelector.thumbCacheDir + "/" + path.replace(/\//g, "_") + ".jpg"
    }
    // Survives Loader unload, so reopening starts on the applied wallpaper
    property string appliedPath: State.appliedWallpaper

    readonly property int thumbH: 88   // thumbnail height
    readonly property int thumbW: 156  // thumbnail width

    function toggle() {
        visible = !visible
        if (visible) {
            wallpaperListProcess.running = true
            focusRetry.attempts = 0
            focusRetry.start()
        } else {
            focusRetry.stop()
        }
    }

    Process {
        id: wallpaperListProcess
        command: ["sh", "-c",
            "find " + wallpaperSelector.wallpaperDir + " " + wallpaperSelector.liveWallpaperDir +
            " -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' -o -name '*.webp'" +
            " -o -name '*.mp4' -o -name '*.mkv' -o -name '*.webm' -o -name '*.mov' -o -name '*.gif' \\)" +
            " 2>/dev/null | sort"]
        // Collect everything, assign the model ONCE. Appending per line resets the
        // ListView (and its currentIndex) on every single file found.
        stdout: StdioCollector {
            onStreamFinished: {
                const videoExt = /\.(mp4|mkv|webm|mov|gif)$/i
                const list = (text || "").split("\n")
                    .map(l => l.trim())
                    .filter(l => l.length > 0)
                    .map(p => ({ path: p, isVideo: videoExt.test(p) }))
                wallpaperSelector.wallpapers = list
                // Model assignment resets currentIndex to 0 — restore after it settles
                Qt.callLater(wallpaperSelector.jumpToApplied)

                const videos = list.filter(w => w.isVideo)
                if (videos.length > 0) {
                    thumbGenProcess.command = ["sh", "-c",
                        "mkdir -p '" + wallpaperSelector.thumbCacheDir + "'; " +
                        videos.map(w => {
                            const out = wallpaperSelector.thumbCachePath(w.path)
                            return "[ -f '" + out + "' ] || ffmpegthumbnailer -i '" + w.path +
                                "' -o '" + out + "' -s 240 2>/dev/null"
                        }).join("; ")]
                    thumbGenProcess.running = true
                    thumbPoll.attempts = 0
                    thumbPoll.start()
                }
            }
        }
    }

    // Generates missing video thumbnails in background (once per file, cached to disk)
    Process {
        id: thumbGenProcess
    }

    // No file-watch API here — just bump thumbGen a few times so Image re-attempts load
    Timer {
        id: thumbPoll
        property int attempts: 0
        interval: 700; repeat: true
        onTriggered: {
            attempts++
            wallpaperSelector.thumbGen++
            if (attempts >= 8) thumbPoll.stop()
        }
    }

    function jumpToApplied() {
        const idx = wallpaperSelector.wallpapers.findIndex(w => w.path === wallpaperSelector.appliedPath)
        thumbList.currentIndex = idx >= 0 ? idx : 0
        thumbList.positionViewAtIndex(thumbList.currentIndex, ListView.Center)
    }

    function setWallpaper(path) {
        // execDetached survives Loader unload (Process child would die when WallpaperSelector destroyed)
        Quickshell.execDetached(["sh", "-c", "\"$HOME/scripts/change-wallpaper.sh\" \"$1\"", "sh", path])
        State.appliedWallpaper = path
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

        // Zero-size + transparent instead of visible:false — an invisible item
        // cannot take active focus in Qt Quick, so key events never arrive.
        TextInput {
            id: focusInput
            width: 1; height: 1
            opacity: 0
            readOnly: true
            text: ""
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    wallpaperSelector.visible = false
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (thumbList.currentIndex >= 0 && thumbList.currentIndex < wallpaperSelector.wallpapers.length)
                        wallpaperSelector.setWallpaper(wallpaperSelector.wallpapers[thumbList.currentIndex].path)
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    thumbList.incrementCurrentIndex()
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    thumbList.decrementCurrentIndex()
                } else if (event.key === Qt.Key_Home) {
                    thumbList.currentIndex = 0
                } else if (event.key === Qt.Key_End) {
                    thumbList.currentIndex = wallpaperSelector.wallpapers.length - 1
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
                focusInput.forceActiveFocus()
                if (!focusInput.activeFocus && attempts < 6) focusRetry.start()
            }
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
                boundsBehavior: Flickable.StopAtBounds
                // NOTE: no `currentIndex:` binding — StrictlyEnforceRange makes the
                // ListView write currentIndex itself, which would break the binding
                // permanently and freeze navigation. currentIndex IS the selection.

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

                    readonly property bool isSel: ListView.isCurrentItem

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
                            id: thumbImg
                            anchors.fill: parent
                            // Bumping thumbGen re-evaluates source, retrying once the
                            // background ffmpegthumbnailer pass has written the file
                            property int _gen: wallpaperSelector.thumbGen
                            source: wpItem.modelData.isVideo
                                ? ("file://" + wallpaperSelector.thumbCachePath(wpItem.modelData.path) + "?" + _gen)
                                : ("file://" + wpItem.modelData.path)
                            sourceSize.width: 240
                            sourceSize.height: 135
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                            opacity: (status === Image.Ready) ? (wpItem.isSel ? 1.0 : (wpMa.containsMouse ? 0.85 : 0.6)) : 0

                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Shown until the cached thumbnail lands (or if generation fails)
                        Text {
                            anchors.centerIn: parent
                            visible: wpItem.modelData.isVideo && thumbImg.status !== Image.Ready
                            text: "▶"
                            font.pixelSize: 28
                            color: "#e9e9ec"
                            opacity: wpItem.isSel ? 1.0 : (wpMa.containsMouse ? 0.85 : 0.6)
                        }

                        // Filename so a video is identifiable even before/without a thumbnail
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 4
                            visible: wpItem.modelData.isVideo
                            text: wpItem.modelData.path.split("/").pop()
                            color: "#e9e9ec"
                            font.pixelSize: 8
                            font.family: "FiraCode Nerd Font"
                            elide: Text.ElideMiddle
                            width: Math.min(implicitWidth, parent.width - 8)
                            horizontalAlignment: Text.AlignRight
                            style: Text.Outline
                            styleColor: "#000000"
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

                    // Hover must NOT change selection: the list scrolls under a
                    // stationary cursor, so onEntered would fight the keyboard.
                    MouseArea {
                        id: wpMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            thumbList.currentIndex = wpItem.index
                            wallpaperSelector.setWallpaper(wpItem.modelData.path)
                        }
                    }
                }
            }

        }
    }
}
