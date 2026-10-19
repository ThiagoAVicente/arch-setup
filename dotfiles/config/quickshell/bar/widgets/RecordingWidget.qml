import QtQuick
import "../.." as Root

// Pulsing red dot and running time while the screen is being recorded.
// Click stops the recording.
Item {
    id: root
    property bool vertical: false

    visible: Root.Recording.active
    implicitWidth: vertical ? 28 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : 24

    readonly property string time: {
        const s = Root.Recording.elapsed
        const m = Math.floor(s / 60)
        return m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: recMa.containsMouse ? Qt.rgba(0.85, 0.3, 0.35, 0.22) : Qt.rgba(0.85, 0.3, 0.35, 0.12)
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    component Dot: Rectangle {
        width: 8; height: 8; radius: 4
        color: Root.Theme.critical
        SequentialAnimation on opacity {
            running: Root.Recording.active
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutSine }
        }
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6
        Dot { anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.time
            color: Root.Theme.barText
            font.family: Root.Theme.fontMono
            font.pixelSize: 12
        }
    }

    Column {
        id: col
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 4
        Dot { anchors.horizontalCenter: parent.horizontalCenter }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.time
            color: Root.Theme.barText
            font.family: Root.Theme.fontMono
            font.pixelSize: 9
        }
    }

    MouseArea {
        id: recMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Root.Recording.toggle()
    }
}
