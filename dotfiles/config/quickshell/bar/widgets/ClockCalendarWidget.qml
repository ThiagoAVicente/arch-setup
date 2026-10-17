import QtQuick
import QtQuick.Layouts
import "../.." as Root

Item {
    id: root

    property bool vertical: false

    implicitWidth: vertical ? 30 : row.implicitWidth
    implicitHeight: vertical ? vCol.implicitHeight + 10 : 36

    property var _time: new Date()
    // Triggers the vertical minute-flip on change
    property string _vFmt: Qt.formatTime(root._time, "mm")
    on_VFmtChanged: if (vertical) vClockAnim.restart()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._time = new Date()
    }

    // ── Horizontal layout ─────────────────────────────────────────────────
    RowLayout {
        id: row
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // ── Clock ────────────────────────────────────────────────────────
        Text {
            id: timeText
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
            font.family: Root.Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Root.Theme.barText
            textFormat: Text.StyledText

            property string _fmt: Qt.formatTime(root._time, "HH:mm")
            text: _fmt.slice(0, 2) + "<font color=\"#8f8f96\">:</font>" + _fmt.slice(3)

            on_FmtChanged: minuteFlip.restart()

            SequentialAnimation {
                id: minuteFlip
                ParallelAnimation {
                    NumberAnimation { target: timeText; property: "opacity"; to: 0.65; duration: 80;  easing.type: Easing.InCubic }
                    NumberAnimation { target: timeText; property: "scale";   to: 0.96; duration: 80;  easing.type: Easing.InCubic }
                }
                ParallelAnimation {
                    NumberAnimation { target: timeText; property: "opacity"; to: 1.0;  duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: timeText; property: "scale";   to: 1.0;  duration: 250; easing.type: Easing.OutCubic }
                }
            }
        }

        // ── Date ─────────────────────────────────────────────────────────
        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 18
            text: Qt.formatDate(root._time, "dd/MM")
            font.family: Root.Theme.fontFamily
            font.pixelSize: 13
            color: Root.Theme.barSubtext
        }
    }

    // ── Vertical layout — hour over minute, no colon, no date ────────────
    Column {
        id: vCol
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 1

        Text {
            id: vHour
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root._time, "HH")
            font.family: Root.Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Root.Theme.barText
        }

        Text {
            id: vMinute
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root._time, "mm")
            font.family: Root.Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Root.Theme.barText
        }
    }

    // Minute-flip animation for vertical mode — both hour and minute dip
    SequentialAnimation {
        id: vClockAnim
        ParallelAnimation {
            NumberAnimation { target: vHour;   property: "opacity"; to: 0.65; duration: 80;  easing.type: Easing.InCubic }
            NumberAnimation { target: vHour;   property: "scale";   to: 0.96; duration: 80;  easing.type: Easing.InCubic }
            NumberAnimation { target: vMinute; property: "opacity"; to: 0.65; duration: 80;  easing.type: Easing.InCubic }
            NumberAnimation { target: vMinute; property: "scale";   to: 0.96; duration: 80;  easing.type: Easing.InCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: vHour;   property: "opacity"; to: 1.0;  duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: vHour;   property: "scale";   to: 1.0;  duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: vMinute; property: "opacity"; to: 1.0;  duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: vMinute; property: "scale";   to: 1.0;  duration: 250; easing.type: Easing.OutCubic }
        }
    }
}
