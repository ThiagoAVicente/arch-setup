import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "." as Root

Scope {
    id: launcher
    property bool visible: false
    property int selectedIndex: 0

    readonly property color cBg:      Root.Theme.bg
    readonly property color cMantle:  Root.Theme.mantle
    readonly property color cAccent:  Root.Theme.accent
    readonly property color cText:    Root.Theme.text
    readonly property color cSubtext: Root.Theme.subtext
    readonly property color cMuted:   Root.Theme.muted
    readonly property color cBorder:  Root.Theme.border

    function toggle() {
        visible = !visible
        if (visible) {
            searchField.text = ""
            selectedIndex = 0
            searchField.forceActiveFocus()
        }
    }

    property string searchQuery: ""

    readonly property var allApps: {
        const src = DesktopEntries.applications.values
        const list = []
        for (let i = 0; i < src.length; i++) {
            const e = src[i]
            if (e.noDisplay) continue
            list.push({
                name: e.name || "",
                comment: e.comment || e.genericName || "",
                iconPath: Quickshell.iconPath(e.icon, "application-x-executable"),
                entry: e
            })
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        return list
    }

    readonly property var filteredApps: {
        const q = searchQuery.toLowerCase()
        if (!q) return allApps.slice(0, 50)
        return allApps.filter(a =>
            a.name.toLowerCase().includes(q) ||
            a.comment.toLowerCase().includes(q)
        ).slice(0, 50)
    }

    function filterApps(query) {
        searchQuery = query
        selectedIndex = 0
    }

    function launchApp(app) {
        if (app && app.entry) app.entry.execute()
        visible = false
    }

    PanelWindow {
        id: win
        visible: launcher.visible
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: -1
        focusable: true
        color: "transparent"
        WlrLayershell.namespace: "qs-overlay"

        onVisibleChanged: {
            if (visible) {
                card.opacity = 0
                card.scale = 0.97
                openAnim.restart()
            }
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }

        // Click-away close (transparent — blur layerrule frosts the card only)
        MouseArea {
            anchors.fill: parent
            onClicked: launcher.visible = false
        }

        // ── Card ───────────────────────────────────────────────────────────
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 580
            height: 520
            color: Root.Theme.panelFrost
            border.color: Root.Theme.hairline
            border.width: 1
            radius: 14
            clip: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            // ── Header ─────────────────────────────────────────────────────
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 44

                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    spacing: 10

                    Text {
                        text: "\u{f0349}"
                        font.pixelSize: 13
                        font.family: "FiraCode Nerd Font"
                        color: launcher.cSubtext
                    }

                    Text {
                        text: "APPLICATIONS"
                        font.pixelSize: 10
                        font.family: "FiraCode Nerd Font"
                        font.letterSpacing: 2
                        color: launcher.cMuted
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: launcher.filteredApps.length > 0
                        text: launcher.filteredApps.length + (searchField.text ? "" : "+")
                        font.pixelSize: 11
                        font.family: "FiraCode Nerd Font"
                        color: launcher.cMuted
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
            }

            // ── Search area ────────────────────────────────────────────────
            Item {
                id: searchArea
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 60

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1
                    color: searchField.activeFocus ? Root.Theme.focusRing : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    anchors.fill: parent

                    RowLayout {
                        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                        spacing: 12

                        Text {
                            text: "\u{f002}"
                            color: searchField.text ? launcher.cAccent : launcher.cMuted
                            font.pixelSize: 15
                            font.family: "FiraCode Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: launcher.cText
                            font.pixelSize: 15
                            font.family: "FiraCode Nerd Font"
                            font.weight: Font.Light
                            clip: true
                            focus: true
                            selectionColor: Qt.rgba(1, 1, 1, 0.25)

                            onTextChanged: launcher.filterApps(text)
                            Component.onCompleted: forceActiveFocus()

                            Keys.onEscapePressed: launcher.visible = false
                            Keys.onReturnPressed: {
                                if (launcher.filteredApps.length > 0)
                                    launcher.launchApp(launcher.filteredApps[launcher.selectedIndex])
                            }
                            Keys.onDownPressed: {
                                if (launcher.selectedIndex > 0)
                                    launcher.selectedIndex--
                                appList.positionViewAtIndex(launcher.selectedIndex, ListView.Contain)
                            }
                            Keys.onUpPressed: {
                                if (launcher.selectedIndex < launcher.filteredApps.length - 1)
                                    launcher.selectedIndex++
                                appList.positionViewAtIndex(launcher.selectedIndex, ListView.Contain)
                            }
                            Keys.onTabPressed: {
                                launcher.selectedIndex =
                                    (launcher.selectedIndex + 1) % Math.max(1, launcher.filteredApps.length)
                                appList.positionViewAtIndex(launcher.selectedIndex, ListView.Contain)
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Search applications..."
                                color: launcher.cMuted
                                font.pixelSize: 15
                                font.family: "FiraCode Nerd Font"
                                font.weight: Font.Light
                                visible: !searchField.text
                            }
                        }

                        Text {
                            visible: launcher.filteredApps.length > 0
                            text: "↵"
                            font.pixelSize: 12
                            font.family: "FiraCode Nerd Font"
                            color: launcher.cMuted
                        }
                    }
                }
            }

            // ── App list ───────────────────────────────────────────────────
            Item {
                id: listArea
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    bottom: searchArea.top
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: launcher.filteredApps.length === 0 && searchField.text

                    Text {
                        text: "\u{f059d}"
                        font.pixelSize: 36
                        font.family: "FiraCode Nerd Font"
                        color: launcher.cMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "No results for \"" + searchField.text + "\""
                        font.pixelSize: 12
                        font.family: "FiraCode Nerd Font"
                        color: launcher.cMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                ListView {
                    id: appList
                    anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
                    clip: true
                    spacing: 0
                    model: launcher.filteredApps
                    verticalLayoutDirection: ListView.BottomToTop
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 0
reuseItems: true

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 2
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        opacity: appList.moving ? 1.0 : 0.0
                        contentItem: Rectangle { radius: 1; color: Qt.rgba(1, 1, 1, 0.18) }
                        background: Item {}
                    }

                    delegate: Item {
                        id: delegateRoot
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 52

                        readonly property bool isSelected: index === launcher.selectedIndex

                        // Selection background
                        Rectangle {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            radius: 10
                            color: delegateRoot.isSelected
                                ? Qt.rgba(1, 1, 1, 0.07)
                                : "transparent"
                        }

                        // Left accent bar
                        Rectangle {
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            width: 2
                            height: 20
                            radius: 2
                            color: Root.Theme.bright
                            visible: delegateRoot.isSelected
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                            spacing: 12

                            // Rounded-square icon
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 9
                                color: delegateRoot.isSelected
                                    ? Qt.rgba(1, 1, 1, 0.08)
                                    : Qt.rgba(1, 1, 1, 0.04)

                                Image {
                                    id: ico
                                    source: modelData.iconPath || ""
                                    anchors.centerIn: parent
                                    width: 24; height: 24
                                    sourceSize.width: 48
                                    sourceSize.height: 48
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                }

                                Text {
                                    text: "\u{f259}"
                                    font.pixelSize: 15
                                    font.family: "FiraCode Nerd Font"
                                    color: launcher.cMuted
                                    anchors.centerIn: parent
                                    visible: !ico.visible
                                }
                            }

                            // Name + description
                            Column {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: modelData.name
                                    color: delegateRoot.isSelected ? "#ffffff" : launcher.cText
                                    font.pixelSize: 13
                                    font.family: "FiraCode Nerd Font"
                                    font.weight: delegateRoot.isSelected === true ? Font.DemiBold : Font.Normal
                                    font.letterSpacing: 0.2
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.comment || ""
                                    color: delegateRoot.isSelected ? launcher.cSubtext : launcher.cMuted
                                    font.pixelSize: 11
                                    font.family: "FiraCode Nerd Font"
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: launcher.selectedIndex = index
                            onClicked: launcher.launchApp(modelData)
                        }
                    }
                }
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) launcher.visible = false
        }
    }
}
