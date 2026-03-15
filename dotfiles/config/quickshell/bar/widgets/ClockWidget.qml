import QtQuick 2.15

Item {
    id: clockWrapper
    width: maxText.width
    height: maxText.height

    property var currentTime: new Date()
    property bool showDate: false

    // This hidden Text calculates the max width
    Text {
        id: maxText
        visible: false
        font.family: "FiraCode Nerd Font"
        font.pixelSize: 11
        font.weight: Font.Medium
        text: "Wed Sep 30"   // longest possible string
    }

    Text {
        id: clock
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: "FiraCode Nerd Font"
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Qt.rgba(1,1,1,0.7)

        text: showDate
            ? Qt.formatDate(clockWrapper.currentTime, "ddd MMM d")
            : Qt.formatTime(clockWrapper.currentTime, "HH:mm")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockWrapper.currentTime = new Date()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clockWrapper.showDate = !clockWrapper.showDate
    }
}
