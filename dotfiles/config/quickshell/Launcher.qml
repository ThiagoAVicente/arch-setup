import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Scope {
    id: launcher
    property bool visible: false
    property int selectedIndex: 0

    readonly property color cBg:      "#1E1E2C"
    readonly property color cHeader:  "#0D0D18"
    readonly property color cSurface: "#111118"
    readonly property color cBorder:  Qt.rgba(1, 1, 1, 0.06)
    readonly property color cText:    "#DDDDE8"
    readonly property color cMuted:   "#383848"
    readonly property color cMutedBr: "#505065"

    function toggle() {
        visible = !visible
        if (visible) {
            searchField.text = ""
            selectedIndex = 0
            searchField.forceActiveFocus()
        }
    }

    property var allApps: []
    property var filteredApps: []
    property var _tempApps: []

    Component.onCompleted: appListProcess.running = true

    onVisibleChanged: {
        if (visible) {
            // open
            backdrop.opacity = 0
            card.opacity     = 0
            card.height      = 0
            closeAnim.stop()
            openAnim.start()
        } else {
            // close: animate out, then let window hide naturally
            card.height  = card.height
            card.opacity = card.opacity
            openAnim.stop()
            closeAnim.start()
            // background rescan for next open
            if (allApps.length > 0) {
                _tempApps = []
                appListProcess.running = true
            }
        }
    }

    Process {
        id: appListProcess
        command: ["sh", "-c", `
            # Build XDG app dirs exactly as rofi does
            data_home="\${XDG_DATA_HOME:-$HOME/.local/share}"
            IFS=: read -ra sys_dirs <<< "\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            app_dirs=()
            for d in "$data_home" "\${sys_dirs[@]}"; do
                [ -d "$d/applications" ] && app_dirs+=("$d/applications")
            done

            # XDG icon dirs from same data dirs
            icon_dirs=()
            for d in "$data_home" "\${sys_dirs[@]}"; do
                [ -d "$d/icons" ] && icon_dirs+=("$d/icons")
            done
            icon_dirs+=(/usr/share/pixmaps)

            lookup_icon() {
                local n="$1"
                [ -z "$n" ] && return
                [ -f "$n" ] && echo "$n" && return
                for ibase in "\${icon_dirs[@]}"; do
                    for size in 256x256 128x128 64x64 48x48 32x32 scalable; do
                        for theme in hicolor Papirus Papirus-Dark; do
                            for sub in apps devices categories mimetypes actions; do
                                for ext in png svg xpm; do
                                    p="$ibase/$theme/$size/$sub/$n.$ext"
                                    [ -f "$p" ] && echo "$p" && return
                                done
                            done
                            for ext in png svg xpm; do
                                p="$ibase/$theme/$size/$n.$ext"
                                [ -f "$p" ] && echo "$p" && return
                            done
                        done
                    done
                    for ext in png svg xpm; do
                        p="$ibase/$n.$ext"
                        [ -f "$p" ] && echo "$p" && return
                    done
                done
            }

            find "\${app_dirs[@]}" -name '*.desktop' 2>/dev/null | sort -u | while IFS= read -r f; do
                name=$(grep -m1 '^Name='      "$f" 2>/dev/null | cut -d= -f2-)
                exec=$(grep -m1 '^Exec='      "$f" 2>/dev/null | cut -d= -f2-)
                icon=$(grep -m1 '^Icon='      "$f" 2>/dev/null | cut -d= -f2-)
                cmnt=$(grep -m1 '^Comment='   "$f" 2>/dev/null | cut -d= -f2-)
                nod=$( grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)
                type=$(grep -m1 '^Type='      "$f" 2>/dev/null | cut -d= -f2-)
                [ -z "$name" ] && continue
                [ "$nod" = "true" ] && continue
                [ "$type" = "Directory" ] && continue
                iconpath=$(lookup_icon "$icon")
                echo "$name|||$iconpath|||$f|||$exec|||$cmnt"
            done
        `]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (!line || !line.includes("|||")) return
                const p = line.split("|||")
                if (p.length < 4) return
                const name    = p[0] || ""
                const ipath   = p[1] || ""
                const dpath   = p[2] || ""
                const execRaw = p[3] || ""
                const comment = p[4] || ""
                if (!name) return
                const execCmd = execRaw.replace(/%[a-zA-Z]/g, "").trim()
                launcher._tempApps.push({
                    name, comment, dpath, execCmd,
                    iconPath: ipath ? "file://" + ipath : ""
                })
            }
        }
        onExited: (code) => {
            launcher._tempApps.sort((a, b) => a.name.localeCompare(b.name))
            launcher.allApps = launcher._tempApps
            launcher.filteredApps = launcher.allApps.slice(0, 50)
        }
    }

    function filterApps(query) {
        if (!query) {
            filteredApps = allApps.slice(0, 50)
        } else {
            const q = query.toLowerCase()
            filteredApps = allApps.filter(a =>
                a.name.toLowerCase().includes(q) ||
                a.comment.toLowerCase().includes(q)
            ).slice(0, 50)
        }
        selectedIndex = 0
    }

    function launchApp(app) {
        const cmd = app.execCmd ? ["sh", "-c", app.execCmd] : ["gio", "launch", app.dpath]
        Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) +
            '; running: true; onExited: (c) => { destroy() } }',
            launcher
        )
        visible = false
    }

    PanelWindow {
        id: win
        visible: launcher.visible || closeAnim.running
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: -1
        focusable: true
        color: "transparent"

        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: "black"
            opacity: 0
            MouseArea {
                anchors.fill: parent
                onClicked: launcher.visible = false
            }
        }

        // ── Card ─────────────────────────────────────────────────────────
        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 0
            width: 560
            height: 0
            color: launcher.cBg
            border.color: launcher.cBorder
            border.width: 1
            radius: 16
            opacity: 0
            clip: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            // ── Search area ──────────────────────────────────────────────
            Item {
                id: searchArea
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 56

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12

                    Text {
                        text: "\u{f002}"
                        color: searchField.text ? launcher.cMutedBr : launcher.cMuted
                        font.pixelSize: 16
                        font.family: "FiraCode Nerd Font"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: launcher.cText
                        font.pixelSize: 17
                        font.family: "FiraCode Nerd Font"
                        font.weight: Font.Light
                        clip: true
                        focus: true
                        selectionColor: Qt.rgba(1, 1, 1, 0.15)

                        onTextChanged: launcher.filterApps(text)
                        Component.onCompleted: forceActiveFocus()

                        Keys.onEscapePressed: launcher.visible = false
                        Keys.onReturnPressed: {
                            if (launcher.filteredApps.length > 0)
                                launcher.launchApp(launcher.filteredApps[launcher.selectedIndex])
                        }
                        Keys.onDownPressed: {
                            if (launcher.selectedIndex < launcher.filteredApps.length - 1)
                                launcher.selectedIndex++
                            appList.positionViewAtIndex(launcher.selectedIndex, ListView.Contain)
                        }
                        Keys.onUpPressed: {
                            if (launcher.selectedIndex > 0)
                                launcher.selectedIndex--
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
                            text: "Type to search..."
                            color: launcher.cMuted
                            font.pixelSize: 17
                            font.family: "FiraCode Nerd Font"
                            font.weight: Font.Light
                            visible: !searchField.text
                        }
                    }
                }

                // Top border
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    height: 1
                    color: launcher.cBorder
                }
            }

            // ── App list ─────────────────────────────────────────────────
            Item {
                id: listArea
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: searchArea.top

                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: launcher.filteredApps.length === 0 && searchField.text
                    opacity: 0.4

                    Text {
                        text: "\u{f0349}"
                        font.pixelSize: 32
                        font.family: "FiraCode Nerd Font"
                        color: launcher.cMutedBr
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "no matches"
                        font.pixelSize: 12
                        font.family: "FiraCode Nerd Font"
                        font.letterSpacing: 1.0
                        color: launcher.cMutedBr
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    clip: true
                    spacing: 0
                    model: launcher.filteredApps
                    verticalLayoutDirection: ListView.BottomToTop
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 400

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 2
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        opacity: appList.moving ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        contentItem: Rectangle { radius: 1; color: Qt.rgba(1, 1, 1, 0.18) }
                        background: Item {}
                    }

                    delegate: Item {
                        id: delegateRoot
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 54
                        opacity: 0

                        // Staggered entrance
                        Timer {
                            interval: Math.min(index, 10) * 18
                            running: launcher.visible
                            onTriggered: entranceAnim.start()
                        }
                        NumberAnimation {
                            id: entranceAnim
                            target: delegateRoot
                            property: "opacity"
                            from: 0; to: 1.0
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                        Connections {
                            target: launcher
                            function onVisibleChanged() {
                                if (!launcher.visible) delegateRoot.opacity = 0
                            }
                        }

                        // Horizontal gradient selection highlight
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
                                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.03) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                            opacity: index === launcher.selectedIndex ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        // Left accent bar
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 20
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.9)
                            opacity: index === launcher.selectedIndex ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 16
                            spacing: 14

                            // Circular icon container
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 17
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                Image {
                                    id: ico
                                    source: modelData.iconPath || ""
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                    asynchronous: true
                                    smooth: true
                                    opacity: status === Image.Ready ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                Text {
                                    text: "\u{f259}"
                                    font.pixelSize: 14
                                    font.family: "FiraCode Nerd Font"
                                    color: launcher.cMuted
                                    anchors.centerIn: parent
                                    visible: !ico.visible
                                }
                            }

                            // Name + description
                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name
                                    color: index === launcher.selectedIndex ? "#FFFFFF" : launcher.cText
                                    font.pixelSize: 13
                                    font.family: "FiraCode Nerd Font"
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.2
                                    width: parent.width
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    text: modelData.comment || ""
                                    color: launcher.cMutedBr
                                    font.pixelSize: 10
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

                // Fade — top
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 24
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: launcher.cBg }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Fade — bottom
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 24
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: launcher.cBg }
                    }
                }
            }

        }

        // ── Open ─────────────────────────────────────────────────────────
        ParallelAnimation {
            id: openAnim
            OpacityAnimator { target: backdrop; from: 0; to: 0.12; duration: 200; easing.type: Easing.OutCubic }
            OpacityAnimator { target: card; from: 0; to: 1.0; duration: 80; easing.type: Easing.OutCubic }
            NumberAnimation {
                target: card; property: "height"
                from: 0; to: 380; duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
            }
        }

        // ── Close ────────────────────────────────────────────────────────
        ParallelAnimation {
            id: closeAnim
            OpacityAnimator { target: backdrop; to: 0; duration: 220; easing.type: Easing.OutCubic }
            OpacityAnimator { target: card; to: 0; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation {
                target: card; property: "height"
                to: 0; duration: 100
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0, 0.133, 0.06, 0.167, 0.4, 0.208, 0.82, 0.25, 1.0, 1.0, 1.0]
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) launcher.visible = false
        }
    }
}
