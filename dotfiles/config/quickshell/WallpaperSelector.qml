import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "." as Root

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
    // Survives Loader unload (State) and reboots (file), so reopening starts
    // on the applied wallpaper
    property string appliedPath: Root.State.appliedWallpaper
    readonly property string appliedStorePath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "") + "/.local/state")
        + "/quickshell/wallpaper"

    FileView {
        id: appliedStore
        path: wallpaperSelector.appliedStorePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            const p = text().trim()
            if (p && !Root.State.appliedWallpaper) Root.State.appliedWallpaper = p
        }
        // Never saved yet: ask awww what it is showing (static wallpapers)
        onLoadFailed: if (!Root.State.appliedWallpaper) awwwQuery.running = true
    }

    Process {
        id: awwwQuery
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = (text || "").match(/image: (.+)$/m)
                if (!m || Root.State.appliedWallpaper) return
                Root.State.appliedWallpaper = m[1].trim()
                Qt.callLater(wallpaperSelector.jumpToApplied)
            }
        }
    }

    readonly property int thumbH: 117  // thumbnail height (16:9)
    readonly property int thumbW: 208  // thumbnail width

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

    // Drawer surface, read by shell.qml to morph into the next drawer
    readonly property alias surface: goo

    // Animated close: content out, surface drains back into the bar
    function close() {
        if (!visible || goo.closing) return
        focusRetry.stop()
        goo.close()
    }

    Process {
        id: wallpaperListProcess
        command: ["sh", "-c",
            "find \"$1\" \"$2\"" +
            " -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' -o -name '*.webp'" +
            " -o -name '*.mp4' -o -name '*.mkv' -o -name '*.webm' -o -name '*.mov' -o -name '*.gif' \\)" +
            " 2>/dev/null | sort",
            "sh", wallpaperSelector.wallpaperDir, wallpaperSelector.liveWallpaperDir]
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
                    // Paths go in as positional args (in/out pairs) — never spliced into the script
                    const args = []
                    for (const w of videos) args.push(w.path, wallpaperSelector.thumbCachePath(w.path))
                    thumbGenProcess.command = ["sh", "-c",
                        "mkdir -p \"$0\"; while [ $# -ge 2 ]; do " +
                        "[ -f \"$2\" ] || ffmpegthumbnailer -i \"$1\" -o \"$2\" -s 240 2>/dev/null; " +
                        "shift 2; done",
                        wallpaperSelector.thumbCacheDir].concat(args)
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
        // Snap there without the scroll animation: positionViewAtIndex fights
        // StrictlyEnforceRange and settles one item off
        thumbList.highlightMoveDuration = 0
        thumbList.currentIndex = idx >= 0 ? idx : 0
        Qt.callLater(() => thumbList.highlightMoveDuration = -1)
    }

    function setWallpaper(path) {
        // execDetached survives Loader unload (Process child would die when WallpaperSelector destroyed)
        Quickshell.execDetached(["sh", "-c", "\"$HOME/scripts/change-wallpaper.sh\" \"$1\"", "sh", path])
        Root.State.appliedWallpaper = path
        appliedStore.setText(path + "\n")
        close()
    }

    readonly property var current: thumbList.currentIndex >= 0 && thumbList.currentIndex < wallpapers.length
        ? wallpapers[thumbList.currentIndex] : null

    PanelWindow {
        id: panelWindow
        // Open on the focused monitor and stay there (no binding: focus
        // moving while open must not move the drawer)
        Component.onCompleted: screen = Root.BarLayout.focusedScreen()
        visible: wallpaperSelector.visible
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: -1
        focusable: true
        color: "transparent"
        // Own namespace: no blur (must match the bar) and no compositor layer anim
        WlrLayershell.namespace: "qs-drawer"
        // Overlay layer so it also shows over fullscreen windows
        WlrLayershell.layer: WlrLayer.Overlay

        onVisibleChanged: if (visible) goo.open()

        // Zero-size + transparent instead of visible:false — an invisible item
        // cannot take active focus in Qt Quick, so key events never arrive.
        TextInput {
            id: focusInput
            width: 1; height: 1
            opacity: 0
            readOnly: true
            text: ""
            Keys.onPressed: event => {
                const k = event.key
                if (k === Qt.Key_Escape) {
                    wallpaperSelector.close()
                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                    if (wallpaperSelector.current)
                        wallpaperSelector.setWallpaper(wallpaperSelector.current.path)
                } else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Down || k === Qt.Key_J) {
                    thumbList.incrementCurrentIndex()
                } else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Up || k === Qt.Key_K) {
                    thumbList.decrementCurrentIndex()
                } else if (k === Qt.Key_Home) {
                    thumbList.currentIndex = 0
                } else if (k === Qt.Key_End) {
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

        // Click-away close
        MouseArea {
            anchors.fill: parent
            onClicked: wallpaperSelector.close()
        }

        Root.LiquidSurface {
            id: goo
            // A strip along the bar: wide under a horizontal bar, tall beside a side bar
            fullW: vertical ? 264 : 940
            fullH: vertical ? 720 : 240
            onClosed: wallpaperSelector.visible = false
        }

        // Content only — the LiquidSurface is its surface
        Item {
            id: card
            x: goo.cardX
            y: goo.cardY
            width: goo.fullW
            height: goo.fullH - 1
            opacity: goo.contentOpacity
            clip: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            // ── Header ─────────────────────────────────────────────────────
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 44

                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    spacing: 10

                    Text {
                        text: "\u{f03e}"
                        font.pixelSize: 13
                        font.family: "FiraCode Nerd Font"
                        color: Root.Theme.subtext
                    }
                    Text {
                        text: "WALLPAPERS"
                        font.pixelSize: 10
                        font.family: "FiraCode Nerd Font"
                        font.letterSpacing: 2
                        color: Root.Theme.muted
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: wallpaperSelector.wallpapers.length > 0
                        text: (thumbList.currentIndex + 1) + "/" + wallpaperSelector.wallpapers.length
                        font.pixelSize: 11
                        font.family: "FiraCode Nerd Font"
                        color: Root.Theme.muted
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
            }

            // ── Carousel — selection stays centred, the strip scrolls ──────
            ListView {
                id: thumbList
                anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: footer.top }
                readonly property bool vertical: goo.vertical
                orientation: vertical ? ListView.Vertical : ListView.Horizontal
                spacing: 14
                model: wallpaperSelector.wallpapers
                boundsBehavior: Flickable.StopAtBounds
                // NOTE: no `currentIndex:` binding — StrictlyEnforceRange makes the
                // ListView write currentIndex itself, which would break the binding
                // permanently and freeze navigation. currentIndex IS the selection.

                // Keep selected item locked in center — list scrolls, not cursor
                readonly property int span: vertical ? height : width
                readonly property int thumbSpan: vertical ? wallpaperSelector.thumbH : wallpaperSelector.thumbW
                preferredHighlightBegin: (span - thumbSpan) / 2
                preferredHighlightEnd:   (span + thumbSpan) / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveVelocity: 1800
                highlightMoveDuration: -1  // velocity-controlled

                // Wheel steps one wallpaper at a time, either axis
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    property real acc: 0
                    onWheel: event => {
                        acc += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                        while (acc <= -120) { thumbList.incrementCurrentIndex(); acc += 120 }
                        while (acc >= 120)  { thumbList.decrementCurrentIndex(); acc -= 120 }
                    }
                }

                delegate: Item {
                    id: wpItem
                    required property var modelData
                    required property int index
                    width: thumbList.vertical ? thumbList.width : wallpaperSelector.thumbW
                    height: thumbList.vertical ? wallpaperSelector.thumbH : thumbList.height

                    readonly property bool isSel: ListView.isCurrentItem
                    // 0 at the centre, 1 at the card edge — thumbs fade out along the strip
                    readonly property real dist: thumbList.vertical
                        ? Math.min(1, Math.abs(y - thumbList.contentY + height / 2 - thumbList.height / 2) / (thumbList.height / 2))
                        : Math.min(1, Math.abs(x - thumbList.contentX + width / 2 - thumbList.width / 2) / (thumbList.width / 2))

                    opacity: 1 - dist * dist * 0.85
                    scale: isSel ? 1.0 : 0.9
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
                        scale: 1.12
                        z: -1
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    ClippingRectangle {
                        id: thumbClip
                        anchors.centerIn: parent
                        width: wallpaperSelector.thumbW
                        height: wallpaperSelector.thumbH
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
                            sourceSize.width: 320
                            sourceSize.height: 180
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
                    }

                    // Hover must NOT change selection: the list scrolls under a
                    // stationary cursor, so onEntered would fight the keyboard.
                    // First click centres a side thumb, clicking the centred one applies it.
                    MouseArea {
                        id: wpMa
                        anchors.fill: thumbClip
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (wpItem.isSel) wallpaperSelector.setWallpaper(wpItem.modelData.path)
                            else thumbList.currentIndex = wpItem.index
                        }
                    }
                }
            }

            // ── Footer — name of the centred wallpaper ─────────────────────
            Item {
                id: footer
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 34

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    spacing: 8

                    Text {
                        visible: wallpaperSelector.current?.isVideo ?? false
                        text: "LIVE"
                        font.pixelSize: 9
                        font.family: "FiraCode Nerd Font"
                        font.letterSpacing: 1.5
                        color: Root.Theme.ok
                    }
                    Text {
                        Layout.fillWidth: true
                        text: wallpaperSelector.current ? wallpaperSelector.current.path.split("/").pop() : ""
                        font.pixelSize: 11
                        font.family: "FiraCode Nerd Font"
                        color: Root.Theme.subtext
                        elide: Text.ElideMiddle
                    }
                    Text {
                        // No room beside the name in the narrow strip
                        visible: !thumbList.vertical
                        text: "←/→ browse · enter apply · esc close"
                        font.pixelSize: 10
                        font.family: "FiraCode Nerd Font"
                        color: Root.Theme.muted
                    }
                }
            }
        }
    }
}
