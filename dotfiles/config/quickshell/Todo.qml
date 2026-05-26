import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "." as Root

Scope {
    id: todo
    property bool visible: false
    property var items: []
    property var displayItems: []

    readonly property string storePath: {
        const home = Quickshell.env("HOME") || ""
        return home + "/.cache/quickshell-todo.json"
    }

    readonly property color cBg:      Root.Theme.bg
    readonly property color cMantle:  Root.Theme.mantle
    readonly property color cAccent:  Root.Theme.accent
    readonly property color cGreen:   Root.Theme.ok
    readonly property color cRed:     Root.Theme.critical
    readonly property color cText:    Root.Theme.text
    readonly property color cSubtext: Root.Theme.subtext
    readonly property color cMuted:   Root.Theme.muted
    readonly property color cBorder:  Root.Theme.border

    function toggle() {
        visible = !visible
        if (visible) {
            inputField.text = ""
            inputField.forceActiveFocus()
            loadProcess.running = true
        }
    }

    Component.onCompleted: loadProcess.running = true

    // ── Load ───────────────────────────────────────────────────────────────
    Process {
        id: loadProcess
        command: ["sh", "-c", "cat \"$HOME/.cache/quickshell-todo.json\" 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text || "[]")
                    if (Array.isArray(parsed)) todo.items = parsed
                } catch (e) {
                    todo.items = []
                }
                todo.rebuildDisplay()
            }
        }
    }

    // ── Save ───────────────────────────────────────────────────────────────
    function save() {
        const json = JSON.stringify(items)
        const cmd = ["sh", "-c",
            "mkdir -p \"$(dirname \"$0\")\"; printf '%s' \"$1\" > \"$0\"",
            todo.storePath, json]
        Qt.createQmlObject(
            'import Quickshell.Io; Process { ' +
            'command: ' + JSON.stringify(cmd) + '; ' +
            'running: true ' +
            '}',
            todo
        )
    }

    function parseInput(s) {
        const m = s.match(/^(.*?)\s*@(\S+)\s*$/)
        if (!m) return { text: s.trim(), due: null }
        const body = m[1].trim()
        const tok = m[2].toLowerCase()
        const today = new Date(); today.setHours(0, 0, 0, 0)
        let d = null
        if (tok === "today") d = today
        else if (tok === "tomorrow" || tok === "tmr") {
            d = new Date(today); d.setDate(d.getDate() + 1)
        } else if (/^\+\d+d?$/.test(tok)) {
            const days = parseInt(tok.replace(/[^\d]/g, ""))
            d = new Date(today); d.setDate(d.getDate() + days)
        } else if (/^\d{4}-\d{2}-\d{2}$/.test(tok)) {
            d = new Date(tok + "T00:00:00")
        } else {
            return { text: s.trim(), due: null }
        }
        const pad = n => (n < 10 ? "0" + n : "" + n)
        const iso = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
        return { text: body || s.trim(), due: iso }
    }

    function dueInfo(iso) {
        if (!iso) return { label: "", color: cMuted, days: Infinity }
        const today = new Date(); today.setHours(0, 0, 0, 0)
        const d = new Date(iso + "T00:00:00")
        const days = Math.round((d - today) / 86400000)
        let label
        if (days < 0) label = "overdue " + (-days) + "d"
        else if (days === 0) label = "today"
        else if (days === 1) label = "tomorrow"
        else if (days < 7) label = days + "d"
        else {
            const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
            label = months[d.getMonth()] + " " + d.getDate()
        }
        let color = cMuted
        if (days < 0) color = cRed
        else if (days <= 2) color = Qt.color("#f9e2af")
        else color = cSubtext
        return { label, color, days }
    }

    function rebuildDisplay() {
        const arr = items.map((it, i) => ({
            text: it.text,
            done: !!it.done,
            due: it.due || null,
            _i: i
        }))
        arr.sort((a, b) => {
            if (a.done !== b.done) return a.done ? 1 : -1
            const ad = a.due ? Date.parse(a.due + "T00:00:00") : Infinity
            const bd = b.due ? Date.parse(b.due + "T00:00:00") : Infinity
            if (ad !== bd) return ad - bd
            return a._i - b._i
        })
        displayItems = arr
    }

    function addItem(raw) {
        const parsed = parseInput(raw)
        if (!parsed.text) return
        const next = items.slice()
        next.push({ text: parsed.text, done: false, due: parsed.due })
        items = next
        rebuildDisplay()
        save()
    }

    function toggleItem(index) {
        if (index < 0 || index >= items.length) return
        const next = items.slice()
        next[index] = Object.assign({}, next[index], { done: !next[index].done })
        items = next
        rebuildDisplay()
        save()
    }

    function deleteItem(index) {
        if (index < 0 || index >= items.length) return
        const next = items.slice()
        next.splice(index, 1)
        items = next
        rebuildDisplay()
        save()
    }

    function clearDone() {
        items = items.filter(it => !it.done)
        rebuildDisplay()
        save()
    }

    PanelWindow {
        id: win
        visible: todo.visible
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: -1
        focusable: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.55
            MouseArea {
                anchors.fill: parent
                onClicked: todo.visible = false
            }
        }

        // Glow halo
        Rectangle {
            anchors.centerIn: parent
            width: card.width + 12
            height: card.height + 12
            radius: card.radius + 6
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.85)
            border.width: 3
            visible: todo.visible
            layer.enabled: todo.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 20
                brightness: 0.15
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 520
            height: 560
            color: todo.cBg
            border.width: 0
            radius: 14
            clip: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            // ── Header ─────────────────────────────────────────────────────
            Rectangle {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 46
                radius: card.radius
                color: todo.cMantle

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: parent.height / 2
                    color: parent.color
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    spacing: 10

                    Text {
                        text: "\u{f00c}"
                        font.pixelSize: 14
                        font.family: "FiraCode Nerd Font"
                        color: todo.cAccent
                    }
                    Text {
                        text: "Todo"
                        font.pixelSize: 13
                        font.family: "FiraCode Nerd Font"
                        font.weight: Font.Medium
                        color: todo.cText
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: todo.items.length > 0
                        height: 22
                        width: countLabel.implicitWidth + 16
                        radius: 11
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: todo.cBorder
                        border.width: 1
                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: {
                                const done = todo.items.filter(it => it.done).length
                                return done + "/" + todo.items.length
                            }
                            font.pixelSize: 11
                            font.family: "FiraCode Nerd Font"
                            color: todo.cMuted
                        }
                    }
                    Rectangle {
                        visible: todo.items.some(it => it.done)
                        height: 22
                        width: clearLabel.implicitWidth + 16
                        radius: 11
                        color: Qt.rgba(0.95, 0.55, 0.66, 0.10)
                        border.color: Qt.rgba(0.95, 0.55, 0.66, 0.30)
                        border.width: 1
                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "clear done"
                            font.pixelSize: 11
                            font.family: "FiraCode Nerd Font"
                            color: todo.cRed
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: todo.clearDone()
                        }
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: todo.cBorder
                }
            }

            // ── Input area ─────────────────────────────────────────────────
            Item {
                id: inputArea
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 60

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1
                    color: todo.cBorder
                }

                Rectangle {
                    anchors { fill: parent; margins: 10 }
                    color: todo.cMantle
                    radius: 8
                    border.color: inputField.activeFocus
                        ? Qt.rgba(0.48, 0.64, 0.97, 0.45)
                        : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 10

                        Text {
                            text: "\u{f067}"
                            color: inputField.text ? todo.cAccent : todo.cMuted
                            font.pixelSize: 14
                            font.family: "FiraCode Nerd Font"
                        }

                        TextInput {
                            id: inputField
                            Layout.fillWidth: true
                            color: todo.cText
                            font.pixelSize: 15
                            font.family: "FiraCode Nerd Font"
                            font.weight: Font.Light
                            clip: true
                            focus: true
                            selectionColor: Qt.rgba(0.48, 0.64, 0.97, 0.3)

                            Keys.onEscapePressed: todo.visible = false
                            Keys.onReturnPressed: {
                                todo.addItem(text)
                                text = ""
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Add a task... (@today, @tomorrow, @+3, @2026-06-01)"
                                color: todo.cMuted
                                font.pixelSize: 15
                                font.family: "FiraCode Nerd Font"
                                font.weight: Font.Light
                                visible: !inputField.text
                            }
                        }

                        Rectangle {
                            visible: inputField.text.length > 0
                            height: 20
                            width: hintText.implicitWidth + 12
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: todo.cBorder
                            border.width: 1
                            Text {
                                id: hintText
                                anchors.centerIn: parent
                                text: "↵"
                                font.pixelSize: 11
                                font.family: "FiraCode Nerd Font"
                                color: todo.cMuted
                            }
                        }
                    }
                }
            }

            // ── List ───────────────────────────────────────────────────────
            Item {
                id: listArea
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    bottom: inputArea.top
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: todo.items.length === 0

                    Text {
                        text: "\u{f0c8}"
                        font.pixelSize: 36
                        font.family: "FiraCode Nerd Font"
                        color: todo.cMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "Nothing to do"
                        font.pixelSize: 12
                        font.family: "FiraCode Nerd Font"
                        color: todo.cMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                ListView {
                    id: list
                    anchors { fill: parent; topMargin: 6; bottomMargin: 6 }
                    clip: true
                    spacing: 0
                    model: todo.displayItems
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 0
reuseItems: true

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 2
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        opacity: list.moving ? 1.0 : 0.0
                        contentItem: Rectangle { radius: 1; color: Qt.rgba(1, 1, 1, 0.18) }
                        background: Item {}
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 46

                        property bool hovered: false

                        Rectangle {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            radius: 8
                            color: row.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                            border.color: row.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            border.width: 1
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 18; rightMargin: 14 }
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 6
                                color: row.modelData.done
                                    ? Qt.rgba(0.65, 0.89, 0.63, 0.18)
                                    : Qt.rgba(1, 1, 1, 0.04)
                                border.color: row.modelData.done
                                    ? Qt.rgba(0.65, 0.89, 0.63, 0.55)
                                    : Qt.rgba(1, 1, 1, 0.18)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f00c}"
                                    font.pixelSize: 11
                                    font.family: "FiraCode Nerd Font"
                                    color: todo.cGreen
                                    visible: row.modelData.done
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: todo.toggleItem(row.modelData._i)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.text
                                color: row.modelData.done ? todo.cMuted : todo.cText
                                font.pixelSize: 13
                                font.family: "FiraCode Nerd Font"
                                font.strikeout: row.modelData.done
                                elide: Text.ElideRight

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: todo.toggleItem(row.modelData._i)
                                }
                            }

                            Rectangle {
                                readonly property var info: todo.dueInfo(row.modelData.due)
                                visible: !!row.modelData.due
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: dueLabel.implicitWidth + 14
                                radius: 10
                                color: row.modelData.done
                                    ? Qt.rgba(1, 1, 1, 0.04)
                                    : Qt.rgba(info.color.r, info.color.g, info.color.b, 0.14)
                                border.color: row.modelData.done
                                    ? Qt.rgba(1, 1, 1, 0.06)
                                    : Qt.rgba(info.color.r, info.color.g, info.color.b, 0.40)
                                border.width: 1

                                Text {
                                    id: dueLabel
                                    anchors.centerIn: parent
                                    text: parent.info.label
                                    font.pixelSize: 10
                                    font.family: "FiraCode Nerd Font"
                                    color: row.modelData.done ? todo.cMuted : parent.info.color
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 6
                                color: delMouse.containsMouse
                                    ? Qt.rgba(0.95, 0.55, 0.66, 0.18)
                                    : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f00d}"
                                    font.pixelSize: 13
                                    font.family: "FiraCode Nerd Font"
                                    color: delMouse.containsMouse ? todo.cRed : todo.cMuted
                                }
                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: todo.deleteItem(row.modelData._i)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: row.hovered = true
                            onExited: row.hovered = false
                            propagateComposedEvents: true
                        }
                    }
                }
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) todo.visible = false
        }
    }
}
