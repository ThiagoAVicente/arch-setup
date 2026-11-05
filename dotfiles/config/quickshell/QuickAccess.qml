pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "." as Root

// Quick access: each key maps to an app (quickaccess.json next to this file).
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

    function resolve(spec) {
        if (typeof spec === "string") {
            const id = spec.replace(/\.desktop$/, "")
            const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)
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

    function load(text) {
        let map = {}
        try {
            map = JSON.parse(text || "{}")
        } catch (e) {
            console.warn("quickaccess: ignoring unparsable", store.path, e)
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

    FileView {
        id: store
        path: Quickshell.shellDir + "/quickaccess.json"
        blockLoading: true
        watchChanges: true
        onLoaded: qa.load(text())
        onFileChanged: reload()
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
            fullW: 460
            fullH: Math.round(card.contentHeight)
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
            readonly property real contentHeight: col.implicitHeight + 32

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

                // ── Slots ──────────────────────────────────────────────────
                Row {
                    id: slots
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
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

                            width: 60; height: 60
                            radius: Root.Theme.radiusMd
                            color: app ? Root.Theme.surface : "transparent"
                            border.width: 1
                            border.color: app ? Root.Theme.hairline
                                : index === qa.queue.length ? Root.Theme.focusRing : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            IconImage {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -6
                                visible: slot.app !== null
                                source: slot.app?.icon ?? ""
                                implicitSize: 28
                                scale: visible ? 1 : 0.6
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                            }
                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                                visible: slot.app !== null
                                text: slot.app?.key ?? ""
                                font.family: Root.Theme.fontFamily; font.pixelSize: 10
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
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: qa.queue.length ? qa.queue.map(a => a.name).join("  ·  ") : "type a key"
                    font.family: Root.Theme.fontFamily; font.pixelSize: 11
                    color: qa.queue.length ? Root.Theme.text : Root.Theme.muted
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                // ── Key map ────────────────────────────────────────────────
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: qa.appKeys

                        Rectangle {
                            id: chip
                            required property string modelData
                            readonly property var app: qa.apps[modelData]

                            width: chipRow.implicitWidth + 14
                            height: 26
                            radius: height / 2
                            color: chipMa.containsMouse ? Root.Theme.hover : "transparent"
                            border.width: 1
                            border.color: Root.Theme.hairline

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData
                                    font.family: Root.Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Medium
                                    color: Root.Theme.text
                                }
                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: chip.app?.icon ?? ""
                                    implicitSize: 14
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.app?.name ?? ""
                                    font.family: Root.Theme.fontFamily; font.pixelSize: 10
                                    color: Root.Theme.subtext
                                }
                            }

                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qa.push(chip.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
