import QtQuick
import QtQuick.Layouts
import "../.." as Root

Item {
    id: root

    property bool calendarOpen: false
    property bool showCalendar: true
    signal calHoverChanged(bool hovered)

    implicitWidth: row.implicitWidth
    implicitHeight: 36

    property var _time: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._time = new Date()
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // ── Clock ────────────────────────────────────────────────────────
        Text {
            id: timeText
            Layout.alignment: Qt.AlignVCenter
            font.family: Root.Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
            color: Root.Theme.barText

            property string _fmt: Qt.formatTime(root._time, "HH:mm")
            text: _fmt

            on_FmtChanged: minuteFlip.restart()

            SequentialAnimation {
                id: minuteFlip
                ParallelAnimation {
                    NumberAnimation { target: timeText; property: "opacity"; to: 0.65; duration: 80;  easing.type: Easing.InCubic }
                    NumberAnimation { target: timeText; property: "scale";   to: 0.96; duration: 80;  easing.type: Easing.InCubic }
                }
                ParallelAnimation {
                    NumberAnimation { target: timeText; property: "opacity"; to: 1.0;  duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: timeText; property: "scale";   to: 1.0;  duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }
            }
        }

        // ── Separator ────────────────────────────────────────────────────
        Item { visible: root.showCalendar; Layout.preferredWidth: 9 }
        Rectangle {
            visible: root.showCalendar
            Layout.alignment: Qt.AlignVCenter
            width: 1; height: 13
            color: Root.Theme.barBorderStrong
        }
        Item { visible: root.showCalendar; Layout.preferredWidth: 9 }

        // ── Calendar ─────────────────────────────────────────────────────
        RowLayout {
            id: calGroup
            visible: root.showCalendar
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Text {
                id: calIcon
                text: "󰃭"
                font.family: Root.Theme.fontFamily
                font.pixelSize: 15

                color: root.calendarOpen
                    ? Root.Theme.barText
                    : (calHover.hovered ? Root.Theme.barText : Root.Theme.barMuted)

                Behavior on color { ColorAnimation { duration: 160 } }

                scale: calHover.hovered ? 1.15 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                }
            }

            Text {
                id: dateText
                text: Qt.formatDate(root._time, "dd/MM/yyyy")
                font.family: Root.Theme.fontFamily
                font.pixelSize: 14
                color: Root.Theme.barText
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            HoverHandler {
                id: calHover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.calHoverChanged(hovered)
            }
        }
    }
}
