import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
    id: cal

    property bool visible: false
    property bool iconHovered: false
    property bool cardHovered: false

    readonly property color cBg:     "#0D0D0D"
    readonly property color cBorder: "#1C1C1C"
    readonly property color cText:   "#E0E0E0"
    readonly property color cMuted:  "#484848"

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var dayNames: ["Mo","Tu","We","Th","Fr","Sa","Su"]

    property var _today: new Date()
    property int displayMonth: _today.getMonth()
    property int displayYear:  _today.getFullYear()
    property var cells: []

    function open() {
        if (!visible) {
            _today = new Date()
            displayMonth = _today.getMonth()
            displayYear  = _today.getFullYear()
            visible = true
        }
    }

    function _checkClose() {
        if (!iconHovered && !cardHovered)
            closeTimer.restart()
        else
            closeTimer.stop()
    }

    onIconHoveredChanged: _checkClose()
    onCardHoveredChanged: _checkClose()

    Timer {
        id: closeTimer
        interval: 280
        onTriggered: cal.visible = false
    }

    function prevMonth() {
        if (displayMonth === 0) { displayMonth = 11; displayYear-- }
        else displayMonth--
    }
    function nextMonth() {
        if (displayMonth === 11) { displayMonth = 0; displayYear++ }
        else displayMonth++
    }

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
    function firstWeekday(y, m) {
        return (new Date(y, m, 1).getDay() + 6) % 7  // Mon=0
    }

    function buildCells() {
        const y = displayYear, m = displayMonth
        const fd  = firstWeekday(y, m)
        const dim = daysInMonth(y, m)
        const prevDim = daysInMonth(m === 0 ? y - 1 : y, m === 0 ? 11 : m - 1)
        let out = []
        for (let i = fd - 1; i >= 0; i--)
            out.push({ day: prevDim - i, cur: false })
        for (let d = 1; d <= dim; d++)
            out.push({ day: d, cur: true })
        let nd = 1
        while (out.length < 42)
            out.push({ day: nd++, cur: false })
        return out
    }

    onDisplayMonthChanged: cells = buildCells()
    onDisplayYearChanged:  cells = buildCells()
    Component.onCompleted: cells = buildCells()

    // ── Floating card window (no backdrop — hover-driven open/close) ────────
    PanelWindow {
        id: calWin
        visible: cal.visible
        anchors { top: true; left: true }
        implicitWidth: 248
        implicitHeight: 290
        exclusiveZone: 0
        focusable: false
        color: "transparent"

        // ── Card ─────────────────────────────────────────────────────────
        Rectangle {
            id: calCard
            x: 16
            y: 0            // PanelWindow origin is already at bar bottom (after bar's exclusiveZone)
            width: 216
            height: calCol.implicitHeight + 24
            color: cal.cBg
            border.color: cal.cBorder
            border.width: 1
            radius: 6
            opacity: 0
            scale: 0.88
            transformOrigin: Item.Top

            HoverHandler {
                onHoveredChanged: cal.cardHovered = hovered
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: calCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                spacing: 8

                // ── Month header ─────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "<"
                        color: cal.cMuted
                        font.pixelSize: 12
                        font.family: "FiraCode Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cal.prevMonth()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: cal.monthNames[cal.displayMonth] + "  " + cal.displayYear
                        color: cal.cText
                        font.pixelSize: 12
                        font.family: "FiraCode Nerd Font"
                    }

                    Text {
                        text: ">"
                        color: cal.cMuted
                        font.pixelSize: 12
                        font.family: "FiraCode Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cal.nextMonth()
                        }
                    }
                }

                // ── Day name headers ─────────────────────────────────────
                Row {
                    Layout.fillWidth: true
                    Repeater {
                        model: cal.dayNames
                        Text {
                            required property var modelData
                            width: (216 - 24) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: cal.cMuted
                            font.pixelSize: 10
                            font.family: "FiraCode Nerd Font"
                        }
                    }
                }

                // ── Day grid ─────────────────────────────────────────────
                Grid {
                    columns: 7
                    Layout.fillWidth: true
                    rowSpacing: 2
                    columnSpacing: 0

                    Repeater {
                        model: cal.cells

                        Rectangle {
                            required property var modelData
                            required property int index

                            readonly property bool isToday:
                                modelData.cur &&
                                modelData.day  === cal._today.getDate() &&
                                cal.displayMonth === cal._today.getMonth() &&
                                cal.displayYear  === cal._today.getFullYear()

                            width: (216 - 24) / 7
                            height: 24
                            radius: 3
                            color: isToday ? cal.cText : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.pixelSize: 11
                                font.family: "FiraCode Nerd Font"
                                color: isToday
                                    ? cal.cBg
                                    : modelData.cur ? cal.cText : cal.cMuted
                                opacity: modelData.cur ? 1.0 : 0.35
                            }
                        }
                    }
                }
            }
        }

        ParallelAnimation {
            id: openAnim
            OpacityAnimator {
                target: calCard; from: 0; to: 1.0
                duration: 100; easing.type: Easing.OutCubic
            }
            ScaleAnimator {
                target: calCard; from: 0.88; to: 1.0
                duration: 340; easing.type: Easing.OutBack; easing.overshoot: 0.7
            }
            NumberAnimation {
                target: calCard; property: "y"; from: -8; to: 0
                duration: 340; easing.type: Easing.OutBack; easing.overshoot: 0.7
            }
        }

        onVisibleChanged: {
            if (visible) {
                calCard.opacity = 0
                calCard.scale   = 0.88
                calCard.y       = -8
                openAnim.start()
            }
        }
    }
}
