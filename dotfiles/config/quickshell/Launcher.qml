import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
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

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.55
            MouseArea {
                anchors.fill: parent
                onClicked: launcher.visible = false
            }
        }

        // ── Glow halo ──────────────────────────────────────────────────────
        Rectangle {
            anchors.centerIn: parent
            width: card.width + 12
            height: card.height + 12
            radius: card.radius + 6
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.85)
            border.width: 3
            visible: launcher.visible
            layer.enabled: launcher.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 20
                brightness: 0.15
            }
        }

        // ── Card ───────────────────────────────────────────────────────────
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 580
            height: 520
            color: launcher.cBg
            border.width: 0
            radius: 14
            clip: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            // ── Header ─────────────────────────────────────────────────────
            Rectangle {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 46
                radius: card.radius
                color: launcher.cMantle

                // Square off bottom half so only top corners are rounded by card clip
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: parent.height / 2
                    color: parent.color
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    spacing: 10

                    Text {
                        text: "\u{f0349}"
                        font.pixelSize: 14
                        font.family: "FiraCode Nerd Font"
                        color: launcher.cAccent
                    }

                    Text {
                        text: "Applications"
                        font.pixelSize: 13
                        font.family: "FiraCode Nerd Font"
                        font.weight: Font.Medium
                        color: launcher.cText
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: launcher.filteredApps.length > 0
                        height: 22
                        width: countLabel.implicitWidth + 16
                        radius: 11
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: launcher.cBorder
                        border.width: 1

                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: launcher.filteredApps.length + (searchField.text ? "" : "+")
                            font.pixelSize: 11
                            font.family: "FiraCode Nerd Font"
                            color: launcher.cMuted
                        }
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: launcher.cBorder
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
                    color: launcher.cBorder
                }

                Rectangle {
                    anchors { fill: parent; margins: 10 }
                    color: launcher.cMantle
                    radius: 8
                    border.color: searchField.activeFocus
                        ? Qt.rgba(0.48, 0.64, 0.97, 0.45)
                        : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 10

                        Text {
                            text: "\u{f002}"
                            color: searchField.text ? launcher.cAccent : launcher.cMuted
                            font.pixelSize: 15
                            font.family: "FiraCode Nerd Font"
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
                            selectionColor: Qt.rgba(0.48, 0.64, 0.97, 0.3)

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

                        Rectangle {
                            visible: launcher.filteredApps.length > 0
                            height: 20
                            width: hintText.implicitWidth + 12
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: launcher.cBorder
                            border.width: 1

                            Text {
                                id: hintText
                                anchors.centerIn: parent
                                text: "↵"
                                font.pixelSize: 11
                                font.family: "FiraCode Nerd Font"
                                color: launcher.cMuted
                            }
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
                            radius: 8
                            color: delegateRoot.isSelected
                                ? Qt.rgba(0.48, 0.64, 0.97, 0.12)
                                : "transparent"
                            border.color: delegateRoot.isSelected
                                ? Qt.rgba(0.48, 0.64, 0.97, 0.2)
                                : "transparent"
                            border.width: 1
                        }

                        // Left accent bar
                        Rectangle {
                            anchors {
                                left: parent.left
                                leftMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            width: 3
                            height: 24
                            radius: 2
                            color: launcher.cAccent
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
                                    ? Qt.rgba(0.48, 0.64, 0.97, 0.15)
                                    : Qt.rgba(1, 1, 1, 0.04)
                                border.color: delegateRoot.isSelected
                                    ? Qt.rgba(0.48, 0.64, 0.97, 0.25)
                                    : Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1

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
                                    font.weight: delegateRoot.isSelected ? Font.SemiBold : Font.Normal
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
