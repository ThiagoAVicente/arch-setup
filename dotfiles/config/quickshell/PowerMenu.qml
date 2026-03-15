import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    id: powermenu
    property bool visible: false
    property int selectedIndex: 0

    readonly property color cBg:      "#0D0D0D"
    readonly property color cBorder:  "#1C1C1C"
    readonly property color cText:    "#E0E0E0"
    readonly property color cMuted:   "#484848"
    readonly property color cSel:     "#FFFFFF"
    readonly property color cSelText: "#0D0D0D"

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
        runner.command = options[index].cmd
        runner.running = true
        visible = false
    }

    Process { id: runner }

    PanelWindow {
        id: panelWindow
        visible: powermenu.visible
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: Qt.rgba(0, 0, 0, 0.65)
        focusable: true

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
            if (visible) { focusRetry.attempts = 0; focusRetry.start() }
            else focusRetry.stop()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: powermenu.visible = false
            propagateComposedEvents: false
        }

        // ── Card ───────────────────────────────────────────────────────────
        Rectangle {
            anchors.centerIn: parent
            width: 220
            height: optionCol.implicitHeight + 32
            color: powermenu.cBg
            border.color: powermenu.cBorder
            border.width: 1
            radius: 6

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: optionCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 16
                }
                spacing: 2

                Repeater {
                    model: powermenu.options

                    Rectangle {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        height: 44
                        radius: 4
                        color: index === powermenu.selectedIndex
                            ? powermenu.cSel
                            : "transparent"

                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 14

                            Text {
                                text: modelData.icon
                                color: index === powermenu.selectedIndex
                                    ? powermenu.cSelText
                                    : powermenu.cMuted
                                font.pixelSize: 16
                                font.family: "FiraCode Nerd Font"
                            }

                            Text {
                                text: modelData.name
                                color: index === powermenu.selectedIndex
                                    ? powermenu.cSelText
                                    : powermenu.cText
                                font.pixelSize: 13
                                font.family: "FiraCode Nerd Font"
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: powermenu.selectedIndex = index
                            onClicked: powermenu.runOption(index)
                        }
                    }
                }
            }
        }
    }
}
