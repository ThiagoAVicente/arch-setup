import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "." as Root

Scope {
    id: powermenu
    property bool visible: false
    property int selectedIndex: 0

    property var options: [
        { icon: "⏻", name: "shutdown", cmd: ["systemctl", "poweroff"] },
        { icon: "↺", name: "reboot",   cmd: ["systemctl", "reboot"] },
        { icon: "⏾", name: "sleep",    cmd: ["systemctl", "suspend"] },
        { icon: "→", name: "logout",   cmd: ["pkill", "-KILL", "-u", "vcnt"] }
    ]

    function toggle() {
        visible = !visible
        if (visible) {
            selectedIndex = 0
            focusRetry.attempts = 0
            focusRetry.start()
        } else {
            focusRetry.stop()
        }
    }

    function runOption(index) {
        Quickshell.execDetached(options[index].cmd)
        visible = false
    }

    PanelWindow {
        id: panelWindow
        visible: powermenu.visible
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "transparent"
        focusable: true
        WlrLayershell.namespace: "qs-overlay"

        TextInput {
            id: focusInput
            visible: false; readOnly: true; text: ""; focus: false
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    powermenu.visible = false; break
                case Qt.Key_Up:
                case Qt.Key_Left:
                    if (powermenu.selectedIndex > 0) powermenu.selectedIndex--; break
                case Qt.Key_Down:
                case Qt.Key_Right:
                    if (powermenu.selectedIndex < powermenu.options.length - 1) powermenu.selectedIndex++; break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    powermenu.runOption(powermenu.selectedIndex); break
                }
                event.accepted = true
            }
        }

        Timer {
            id: focusRetry
            property int attempts: 0
            interval: 60; repeat: false
            onTriggered: {
                attempts++
                try { focusInput.forceActiveFocus() } catch(e) {}
                if (!panelWindow.activeFocus && attempts < 6) focusRetry.start()
            }
        }

        onVisibleChanged: {
            if (visible) {
                tileRow.opacity = 0
                tileRow.yOffset = 8
                pmOpenAnim.restart()
                focusRetry.attempts = 0
                focusRetry.start()
            } else {
                focusRetry.stop()
            }
        }

        ParallelAnimation {
            id: pmOpenAnim
            NumberAnimation { target: tileRow; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: tileRow; property: "yOffset"; to: 0; duration: 180; easing.type: Easing.OutCubic }
        }

        // Click-away close (invisible)
        MouseArea {
            anchors.fill: parent
            onClicked: powermenu.visible = false
        }

        // ── Glyph tiles — icons only, frosted, no card ─────────────────────
        Row {
            id: tileRow
            property real yOffset: 0
            anchors.centerIn: parent
            anchors.verticalCenterOffset: yOffset
            spacing: 14
            opacity: 0

            Repeater {
                model: powermenu.options

                Rectangle {
                    id: tile
                    required property int index
                    required property var modelData

                    readonly property bool isSel: index === powermenu.selectedIndex

                    width: 64
                    height: 64
                    radius: 18
                    color: isSel ? "#eeeef0" : Root.Theme.panelFrost
                    border.color: isSel ? "transparent" : Root.Theme.hairline
                    border.width: 1

                    transform: Translate {
                        y: tile.isSel ? -3 : 0
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: tile.modelData.icon
                        color: tile.isSel ? "#0e0e10" : "#c9c9cf"
                        font.pixelSize: 22
                        font.family: Root.Theme.fontFamily
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: powermenu.selectedIndex = tile.index
                        onClicked: powermenu.runOption(tile.index)
                    }
                }
            }
        }
    }
}
