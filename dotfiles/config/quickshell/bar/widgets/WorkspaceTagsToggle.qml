import QtQuick
import "../.." as Root

// Switches the workspace number drawer on unfocused monitors
// (bar/popouts/WorkspaceTag.qml). Only shown with more than one monitor.
Item {
    id: tagsToggle

    property bool vertical: false

    visible: Root.MonitorColors.order.length > 1
    implicitWidth: visible ? 24 : 0
    implicitHeight: visible ? 24 : 0

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: tagMa.containsMouse ? Root.Theme.barHover : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    Text {
        anchors.centerIn: parent
        // Monitor with or without its number
        text: Root.State.workspaceTags ? "󰍹" : "󰶐"
        color: tagMa.containsMouse ? Root.Theme.barAccent
            : Root.State.workspaceTags ? Root.Theme.barText : Root.Theme.barMuted
        font.pixelSize: 14
        font.family: Root.Theme.fontFamily
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    MouseArea {
        id: tagMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Root.State.workspaceTags = !Root.State.workspaceTags
    }
}
