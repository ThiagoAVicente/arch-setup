pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "." as Root

// Quick access: each key maps to an app. Binds are personal, so they live in
// $XDG_DATA_HOME/quickshell/quickaccess.json (not in the dotfiles repo); the
// first run seeds it from quickaccess.example.json next to this file.
// Type up to 6 keys to queue apps, Backspace/Delete removes the last one,
// Enter launches them all at once (detached, like the launcher).
//
// quickaccess.json: { "<key>": "<desktop entry id>" | { "name", "icon", "exec": [argv] } }
Scope {
    id: qa
    property bool visible: false

    readonly property int maxSlots: 6
    // Queued apps, each { key, name, icon, entry | exec }
    property var queue: []
    // key -> resolved app, rebuilt whenever the JSON changes
    property var apps: ({})
    readonly property var appKeys: Object.keys(apps).sort()

    function toggle() {
        visible = !visible
        if (visible) {
            queue = []
            focusRetry.attempts = 0
            focusRetry.start()
        } else {
            focusRetry.stop()
        }
    }

    // Drawer surface, read by shell.qml to morph into the next drawer
    readonly property alias surface: goo

    function close() {
        if (!visible || goo.closing) return
        focusRetry.stop()
        goo.close()
    }

    // Loose match so "zed" finds dev.zed.Zed and "claude" finds
    // com.anthropic.Claude: last id segment, display name, or command name
    function findEntry(name) {
        const n = name.toLowerCase()
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            const last = e.id.toLowerCase().split(".").pop()
            const cmd = (e.command[0] ?? "").split("/").pop().toLowerCase()
            if (last === n || e.name.toLowerCase() === n || cmd === n) return e
        }
        return null
    }

    function resolve(spec) {
        if (typeof spec === "string") {
            const id = spec.replace(/\.desktop$/, "")
            const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? findEntry(id)
            if (!e) return null
            return { name: e.name, icon: Quickshell.iconPath(e.icon, "application-x-executable"), entry: e }
        }
        if (spec && Array.isArray(spec.exec) && spec.exec.length > 0) {
            return {
                name: spec.name || spec.exec[0],
                icon: Quickshell.iconPath(spec.icon || spec.exec[0], "application-x-executable"),
                exec: spec.exec
            }
        }
        return null
    }

    // Shown in the drawer when the binds file can't be read
    property string error: ""

    function load(text) {
        let map = {}
        try {
            // Hand-edited file: tolerate trailing commas
            map = JSON.parse((text || "{}").replace(/,\s*([}\]])/g, "$1"))
            error = ""
        } catch (e) {
            console.warn("quickaccess: ignoring unparsable", store.path, e)
            error = "quickaccess.json: " + e.message
            return
        }
        const out = {}
        for (const key in map) {
            const app = resolve(map[key])
            if (app) out[key] = Object.assign({ key: key }, app)
            else console.warn("quickaccess: no app for", JSON.stringify(key), "->", JSON.stringify(map[key]))
        }
        apps = out
    }

    function push(key) {
        const app = apps[key] ?? apps[key.toLowerCase()]
        if (!app || queue.length >= maxSlots) {
            slots.shake()
            return
        }
        queue = queue.concat([app])
    }

    function pop() {
        if (queue.length > 0) queue = queue.slice(0, -1)
    }

    function removeAt(i) {
        queue = queue.filter((_, j) => j !== i)
    }

    function launchAll() {
        if (queue.length === 0) return
        for (const app of queue) {
            if (app.entry) app.entry.execute()
            else Quickshell.execDetached(app.exec)
        }
        queue = []
        visible = false
    }

    readonly property string storePath:
        (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/quickshell/quickaccess.json"

    FileView {
        id: store
        path: qa.storePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: qa.load(text())
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound) return
            const seed = example.text()
            if (!seed) return
            setText(seed)
            qa.load(seed)
        }
    }

    FileView {
        id: example
        path: Quickshell.shellDir + "/quickaccess.example.json"
        blockLoading: true
        printErrors: false
    }

    PanelWindow {
        id: win
        // Open on the focused monitor and stay there
        Component.onCompleted: screen = Root.BarLayout.focusedScreen()
        visible: qa.visible
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: -1
        focusable: true
        color: "transparent"
        WlrLayershell.namespace: "qs-drawer"
        WlrLayershell.layer: WlrLayer.Overlay

        onVisibleChanged: if (visible) goo.open()

        // Wayland grants keyboard focus async — retry until the catcher has it
        Timer {
            id: focusRetry
            property int attempts: 0
            interval: 60; repeat: false
            onTriggered: {
                attempts++
                keys.forceActiveFocus()
                if (!keys.activeFocus && attempts < 6) focusRetry.start()
            }
        }

        // Click-away close
        MouseArea {
            anchors.fill: parent
            onClicked: qa.close()
        }

        Root.LiquidSurface {
            id: goo
            // Fixed size: the key list scrolls instead of growing the card
            fullW: 560
            fullH: 206
            onClosed: qa.visible = false
        }

        Item {
            id: card
            x: goo.cardX
            y: goo.cardY
            width: goo.fullW
            height: goo.fullH - 1
            opacity: goo.contentOpacity
            clip: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            // All keyboard input lands here
            Item {
                id: keys
                focus: true
                Keys.onPressed: event => {
                    event.accepted = true
                    if (event.key === Qt.Key_Escape) qa.close()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) qa.launchAll()
                    else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) qa.pop()
                    else if (event.text.length === 1 && event.text.charCodeAt(0) > 0x20) qa.push(event.text)
                }
            }

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 14

                // ── Header ─────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "󱓞"
                        font.family: Root.Theme.fontFamily; font.pixelSize: 13
                        color: Root.Theme.subtext
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "QUICK ACCESS"
                        font.family: Root.Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 2
                        color: Root.Theme.muted
                    }
                    Text {
                        text: "↵ open  ⌫ remove  esc"
                        font.family: Root.Theme.fontFamily; font.pixelSize: 10
                        color: Root.Theme.muted
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 124
                    spacing: 14

                    // ── Slots + queued names ───────────────────────────────
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 10

                        Row {
                            id: slots
                            spacing: 6
                            property real shakeX: 0
                            transform: Translate { x: slots.shakeX }

                            function shake() { shakeAnim.restart() }

                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: slots; property: "shakeX"; to: -8; duration: 45 }
                                NumberAnimation { target: slots; property: "shakeX"; to: 7;  duration: 60 }
                                NumberAnimation { target: slots; property: "shakeX"; to: -4; duration: 60 }
                                NumberAnimation { target: slots; property: "shakeX"; to: 0;  duration: 50 }
                            }

                            Repeater {
                                model: qa.maxSlots

                                Rectangle {
                                    id: slot
                                    required property int index
                                    readonly property var app: qa.queue[index] ?? null

                                    width: 42; height: 42
                                    radius: Root.Theme.radiusSm
                                    color: app ? Root.Theme.surface : "transparent"
                                    border.width: 1
                                    border.color: app ? Root.Theme.hairline
                                        : index === qa.queue.length ? Root.Theme.focusRing : Qt.rgba(1, 1, 1, 0.06)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    IconImage {
                                        anchors.centerIn: parent
                                        visible: slot.app !== null
                                        source: slot.app?.icon ?? ""
                                        implicitSize: 22
                                        scale: visible ? 1 : 0.6
                                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                    }
                                    // Key badge in the corner
                                    Text {
                                        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 4; bottomMargin: 2 }
                                        visible: slot.app !== null
                                        text: slot.app?.key ?? ""
                                        font.family: Root.Theme.fontFamily; font.pixelSize: 9
                                        color: Root.Theme.subtext
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: slot.app !== null
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: qa.removeAt(slot.index)
                                    }
                                }
                            }
                        }

                        // Names of what's queued
                        Text {
                            Layout.preferredWidth: slots.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            text: qa.error !== "" ? qa.error
                                : qa.queue.length ? qa.queue.map(a => a.name).join("  ·  ") : "type a key"
                            font.family: Root.Theme.fontFamily; font.pixelSize: 11
                            color: qa.error !== "" ? Root.Theme.critical
                                : qa.queue.length ? Root.Theme.text : Root.Theme.muted
                        }
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        width: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // ── Key map (scrolls, sorted by key) ───────────────────
                    ListView {
                        id: keyList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: qa.appKeys

                        ScrollBar.vertical: ScrollBar {
                            policy: keyList.contentHeight > keyList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 4
                        }

                        delegate: Rectangle {
                            id: row
                            required property string modelData
                            readonly property var app: qa.apps[modelData]
                            readonly property bool queued: qa.queue.some(a => a.key === modelData)

                            width: keyList.width - 10
                            height: 26
                            radius: Root.Theme.radiusSm
                            color: rowMa.containsMouse ? Root.Theme.hover : "transparent"

                            RowLayout {
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 20; Layout.preferredHeight: 18
                                    radius: 4
                                    color: row.queued ? Root.Theme.selected : "transparent"
                                    border.width: 1
                                    border.color: row.queued ? Root.Theme.selectedBorder : Root.Theme.hairline
                                    Text {
                                        anchors.centerIn: parent
                                        text: row.modelData
                                        font.family: Root.Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Medium
                                        color: Root.Theme.text
                                    }
                                }
                                IconImage {
                                    source: row.app?.icon ?? ""
                                    implicitSize: 16
                                }
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: row.app?.name ?? ""
                                    font.family: Root.Theme.fontFamily; font.pixelSize: 11
                                    color: Root.Theme.subtext
                                }
                            }

                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qa.push(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
