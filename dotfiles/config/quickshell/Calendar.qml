import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "." as Root

Scope {
    id: cal

    property bool visible: false
    property bool iconHovered: false
    property bool cardHovered: false

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var dayNames: ["M","T","W","T","F","S","S"]

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

    onVisibleChanged: {
        if (visible) {
            closeAnim.stop()
            calCard.opacity = 0
            calCard.yOffset = -6
            openAnim.start()
        } else {
            openAnim.stop()
            closeAnim.start()
        }
    }

    function prevMonth() {
        if (displayMonth === 0) { displayMonth = 11; displayYear-- }
        else displayMonth--
        monthSlide(-1)
    }
    function nextMonth() {
        if (displayMonth === 11) { displayMonth = 0; displayYear++ }
        else displayMonth++
        monthSlide(1)
    }

    function monthSlide(dir) {
        dayGrid.opacity = 0.25
        dayGrid.xOffset = dir * 10
        monthAnim.restart()
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

    FontLoader {
        id: serifFont
        source: "Widget/InstrumentSerif-Regular.ttf"
    }

    PanelWindow {
        id: calWin
        visible: cal.visible || closeAnim.running
        anchors { top: true; left: true }
        implicitWidth: 290
        implicitHeight: 330
        exclusiveZone: 0
        focusable: false
        color: "transparent"
        WlrLayershell.namespace: "qs-overlay"

        // ── Card ─────────────────────────────────────────────────────────
        Rectangle {
            id: calCard
            // Window top sits at the bar's exclusive zone edge; pill bottom is
            // 4px below that (its topMargin), +2px breathing room
            property real yOffset: 0
            x: 12
            y: 6 + yOffset
            width: 252
            height: calCol.implicitHeight + 26
            opacity: 0
            color: Root.Theme.panelFrost
            border.color: Root.Theme.hairline
            border.width: 1
            radius: 14

            // Inset top highlight
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
                height: 1
                color: Root.Theme.panelHi
            }

            HoverHandler {
                onHoveredChanged: cal.cardHovered = hovered
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: calCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                spacing: 6

                // ── Month header — serif moment ──────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 2
                    spacing: 0

                    Text {
                        text: cal.monthNames[cal.displayMonth]
                        color: Root.Theme.barText
                        font.pixelSize: 21
                        font.family: serifFont.status === FontLoader.Ready ? serifFont.name : Root.Theme.fontFamily
                    }
                    Text {
                        text: " " + cal.displayYear
                        color: Qt.rgba(1, 1, 1, 0.32)
                        font.pixelSize: 13
                        font.family: Root.Theme.fontMono
                        Layout.alignment: Qt.AlignBaseline
                        Layout.leftMargin: 6
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 22; height: 22; radius: 7
                        color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u{f053}"
                            color: prevMa.containsMouse ? Root.Theme.barText : Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 11
                            font.family: Root.Theme.fontFamily
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cal.prevMonth()
                        }
                    }
                    Rectangle {
                        width: 22; height: 22; radius: 7
                        color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u{f054}"
                            color: nextMa.containsMouse ? Root.Theme.barText : Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 11
                            font.family: Root.Theme.fontFamily
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cal.nextMonth()
                        }
                    }
                }

                // ── Day name headers ─────────────────────────────────────
                Row {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Repeater {
                        model: cal.dayNames
                        Text {
                            required property var modelData
                            width: (252 - 28) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Qt.rgba(1, 1, 1, 0.3)
                            font.pixelSize: 11
                            font.family: Root.Theme.fontMono
                            font.letterSpacing: 1
                        }
                    }
                }

                // ── Day grid ─────────────────────────────────────────────
                Grid {
                    id: dayGrid
                    property real xOffset: 0
                    columns: 7
                    Layout.fillWidth: true
                    Layout.leftMargin: xOffset
                    rowSpacing: 0
                    columnSpacing: 0

                    ParallelAnimation {
                        id: monthAnim
                        NumberAnimation { target: dayGrid; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { target: dayGrid; property: "xOffset"; to: 0; duration: 160; easing.type: Easing.OutCubic }
                    }

                    Repeater {
                        model: cal.cells

                        Item {
                            required property var modelData
                            required property int index

                            readonly property bool isToday:
                                modelData.cur &&
                                modelData.day  === cal._today.getDate() &&
                                cal.displayMonth === cal._today.getMonth() &&
                                cal.displayYear  === cal._today.getFullYear()
                            readonly property bool isWeekend: (index % 7) >= 5

                            width: (252 - 28) / 7
                            height: 30

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 8
                                color: isToday ? Qt.rgba(0.94, 0.94, 0.95, 1)
                                    : dayMa.containsMouse && modelData.cur ? Qt.rgba(1, 1, 1, 0.05)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.pixelSize: 12
                                font.family: Root.Theme.fontMono
                                font.weight: isToday ? Font.DemiBold : Font.Normal
                                color: isToday ? "#0e0e10"
                                    : !modelData.cur ? Qt.rgba(1, 1, 1, 0.14)
                                    : isWeekend ? Root.Theme.barMuted
                                    : "#cfcfd4"
                            }

                            MouseArea {
                                id: dayMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }
        }

        // ── Open: fade + drop ─────────────────────────────────────────────
        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: calCard; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: calCard; property: "yOffset"; to: 0; duration: 200; easing.type: Easing.OutCubic }
        }

        // ── Close: quick fade ─────────────────────────────────────────────
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: calCard; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: calCard; property: "yOffset"; to: -4; duration: 150; easing.type: Easing.InCubic }
        }
    }
}
