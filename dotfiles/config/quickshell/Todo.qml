import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
        WlrLayershell.namespace: "qs-overlay"

        onVisibleChanged: {
            if (visible) {
                card.opacity = 0
                card.scale = 0.97
                openAnim.restart()
            }
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }

        // Click-away close (transparent — blur layerrule frosts the card only)
        MouseArea {
            anchors.fill: parent
            onClicked: todo.visible = false
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 520
            height: 560
            color: Root.Theme.panelFrost
            border.color: Root.Theme.hairline
            border.width: 1
            radius: 14
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
                        text: "\u{f00c}"
                        font.pixelSize: 13
                        font.family: "FiraCode Nerd Font"
                        color: todo.cSubtext
                    }
                    Text {
                        text: "TODO"
                        font.pixelSize: 10
                        font.family: "FiraCode Nerd Font"
                        font.letterSpacing: 2
                        color: todo.cMuted
                        Layout.fillWidth: true
                    }

                    // Progress ring — fills as tasks complete
                    Canvas {
                        id: progressRing
                        visible: todo.items.length > 0
                        width: 16; height: 16
                        property real fraction: todo.items.length > 0
                            ? todo.items.filter(it => it.done).length / todo.items.length
                            : 0
                        onFractionChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.lineWidth = 2
                            ctx.lineCap = "round"
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12)
                            ctx.beginPath()
                            ctx.arc(8, 8, 6.5, 0, Math.PI * 2)
                            ctx.stroke()
                            if (fraction > 0) {
                                ctx.strokeStyle = "#e9e9ec"
                                ctx.beginPath()
                                ctx.arc(8, 8, 6.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * fraction)
                                ctx.stroke()
                            }
                        }
                    }

                    Text {
                        visible: todo.items.length > 0
                        text: {
                            const done = todo.items.filter(it => it.done).length
                            return done + "/" + todo.items.length
                        }
                        font.pixelSize: 11
                        font.family: "FiraCode Nerd Font"
                        color: todo.cMuted
                    }

                    Text {
                        visible: todo.items.some(it => it.done)
                        text: "clear done"
                        font.pixelSize: 11
                        font.family: "FiraCode Nerd Font"
                        color: todo.cRed
                        opacity: clearMa.containsMouse ? 1 : 0.75
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: todo.clearDone()
                        }
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
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
                    color: inputField.activeFocus ? Root.Theme.focusRing : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    anchors.fill: parent

                    RowLayout {
                        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                        spacing: 12

                        Text {
                            text: "\u{f067}"
                            color: inputField.text ? todo.cAccent : todo.cMuted
                            font.pixelSize: 14
                            font.family: "FiraCode Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
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
                            selectionColor: Qt.rgba(1, 1, 1, 0.25)

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

                        Text {
                            visible: inputField.text.length > 0
                            text: "↵"
                            font.pixelSize: 12
                            font.family: "FiraCode Nerd Font"
                            color: todo.cMuted
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
                            radius: 10
                            color: row.hovered ? Qt.rgba(1, 1, 1, 0.045) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 18; rightMargin: 14 }
                            spacing: 12

                            // Circular checkbox — outline open, fills white when done
                            Rectangle {
                                id: checkCircle
                                Layout.preferredWidth: 17
                                Layout.preferredHeight: 17
                                radius: width / 2
                                color: row.modelData.done ? "#e9e9ec" : "transparent"
                                border.color: row.modelData.done ? "#e9e9ec"
                                    : cbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.28)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: checkMark
                                    anchors.centerIn: parent
                                    text: "\u{f00c}"
                                    font.pixelSize: 9
                                    font.family: "FiraCode Nerd Font"
                                    color: "#0e0e10"
                                    visible: row.modelData.done
                                    scale: row.modelData.done ? 1 : 0.4
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                }
                                MouseArea {
                                    id: cbMa
                                    anchors.fill: parent
                                    hoverEnabled: true
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
                                Layout.preferredWidth: dueLabel.implicitWidth + 16
                                radius: 10
                                color: row.modelData.done
                                    ? Qt.rgba(1, 1, 1, 0.04)
                                    : Qt.rgba(info.color.r, info.color.g, info.color.b, 0.10)

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
                                radius: 12
                                color: delMouse.containsMouse
                                    ? Qt.rgba(0.85, 0.48, 0.55, 0.14)
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
