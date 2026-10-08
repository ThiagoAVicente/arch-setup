pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../.." as Root

// Themed tray menu rendered in QML — QsMenuAnchor needs QApplication mode
// (extra RAM + Qt widget styling), this reads the DBus menu via QsMenuOpener.
PopupWindow {
    id: menu

    required property Item anchorItem
    property var rootHandle: null
    // Submenu navigation: last element is the menu currently shown
    property var stack: []

    function popup() {
        stack = []
        visible = true
    }

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 10
    // Closes on click outside (xdg_popup grab)
    grabFocus: true
    color: "transparent"

    implicitWidth: card.width
    implicitHeight: card.height

    QsMenuOpener {
        id: opener
        menu: menu.stack.length > 0 ? menu.stack[menu.stack.length - 1] : menu.rootHandle
    }

    Rectangle {
        id: card
        width: Math.max(200, Math.min(320, col.implicitWidth + 12))
        height: col.implicitHeight + 12
        radius: Root.Theme.radiusMd
        color: Root.Theme.panelSolid
        border.color: Root.Theme.hairline
        border.width: 1

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 1

            // Back row inside submenus
            MenuRow {
                visible: menu.stack.length > 0
                label: "Back"
                glyph: "󰁍"
                onActivated: menu.stack = menu.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children

                delegate: Loader {
                    id: entryLoader
                    required property QsMenuEntry modelData
                    Layout.fillWidth: true
                    sourceComponent: modelData.isSeparator ? sepComp : rowComp

                    Component {
                        id: sepComp
                        Item {
                            implicitHeight: 9
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 6 }
                                height: 1
                                color: Root.Theme.hairline
                            }
                        }
                    }

                    Component {
                        id: rowComp
                        MenuRow {
                            readonly property QsMenuEntry entry: entryLoader.modelData
                            label: entry.text.replace(/_(?!_)/g, "")   // strip mnemonic underscores
                            iconSource: entry.icon
                            enabled: entry.enabled
                            checkable: entry.buttonType !== QsMenuButtonType.None
                            checked: entry.checkState === Qt.Checked
                            hasChildren: entry.hasChildren
                            onActivated: {
                                if (entry.hasChildren) {
                                    menu.stack = menu.stack.concat([entry])
                                } else {
                                    entry.triggered()
                                    menu.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: row
        property string label: ""
        property string glyph: ""
        property string iconSource: ""
        property bool checkable: false
        property bool checked: false
        property bool hasChildren: false
        signal activated()

        Layout.fillWidth: true
        implicitWidth: rowLayout.implicitWidth + 20
        implicitHeight: 28
        radius: Root.Theme.radiusSm
        color: rowMa.containsMouse && row.enabled ? Root.Theme.hover : "transparent"
        opacity: row.enabled ? 1 : 0.4

        RowLayout {
            id: rowLayout
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8

            Text {
                visible: row.checkable
                text: row.checked ? "󰄬" : ""
                Layout.preferredWidth: 12
                color: Root.Theme.text
                font.family: Root.Theme.fontFamily; font.pixelSize: 12
            }
            IconImage {
                visible: row.iconSource !== ""
                source: row.iconSource
                implicitSize: 16
            }
            Text {
                visible: row.glyph !== ""
                text: row.glyph
                color: Root.Theme.subtext
                font.family: Root.Theme.fontFamily; font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                text: row.label
                elide: Text.ElideRight
                color: Root.Theme.text
                font.family: Root.Theme.fontFamily; font.pixelSize: 12
            }
            Text {
                visible: row.hasChildren
                text: "󰅂"
                color: Root.Theme.muted
                font.family: Root.Theme.fontFamily; font.pixelSize: 12
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (row.enabled) row.activated()
        }
    }
}
