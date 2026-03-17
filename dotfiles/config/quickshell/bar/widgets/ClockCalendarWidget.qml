import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool calendarOpen: false
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
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 15
            font.weight: Font.Medium
            color: Qt.rgba(1, 1, 1, 0.88)

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
        Item { Layout.preferredWidth: 9 }
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 1; height: 13
            color: Qt.rgba(1, 1, 1, 0.13)
        }
        Item { Layout.preferredWidth: 9 }

        // ── Calendar icon ────────────────────────────────────────────────
        Text {
            id: calIcon
            Layout.alignment: Qt.AlignVCenter
            text: "󰃭"
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 15

            color: root.calendarOpen
                ? Qt.rgba(1, 1, 1, 0.92)
                : (calHover.hovered ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(1, 1, 1, 0.38))

            Behavior on color { ColorAnimation { duration: 160 } }

            scale: calHover.hovered ? 1.15 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }

            HoverHandler {
                id: calHover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.calHoverChanged(hovered)
            }
        }
    }
}
