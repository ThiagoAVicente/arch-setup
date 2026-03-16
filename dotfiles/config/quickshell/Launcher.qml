import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Scope {
    id: launcher
    property bool visible: false
    property int selectedIndex: 0

    readonly property color cBg:      "#0D0D0D"
    readonly property color cSurface: "#131313"
    readonly property color cBorder:  "#1C1C1C"
    readonly property color cText:    "#E0E0E0"
    readonly property color cMuted:   "#484848"
    readonly property color cSel:     "#FFFFFF"
    readonly property color cSelText: "#0D0D0D"

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
    property var _tempApps: []   // accumulator — avoids O(n²) array spreading

    Component.onCompleted: appListProcess.running = true

    Process {
        id: appListProcess
        command: ["sh", "-c", `
            lookup_icon() {
                local n="$1"
                [ -z "$n" ] && return
                [ -f "$n" ] && echo "$n" && return
                for d in $HOME/.local/share/icons/hicolor/256x256 \
                          $HOME/.local/share/icons/hicolor/128x128 \
                          $HOME/.local/share/icons/hicolor/48x48 \
                          $HOME/.local/share/icons/hicolor/32x32 \
                          /usr/share/icons/Papirus/48x48 \
                          /usr/share/icons/Papirus/32x32 \
                          /usr/share/icons/hicolor/48x48 \
                          /usr/share/icons/hicolor/scalable \
                          /usr/share/pixmaps; do
                    for ext in png svg; do
                        for sub in apps devices categories mimetypes actions; do
                            [ -f "$d/$sub/$n.$ext" ] && echo "$d/$sub/$n.$ext" && return
                        done
                        [ -f "$d/$n.$ext" ] && echo "$d/$n.$ext" && return
                    done
                done
            }
            find /usr/share/applications ~/.local/share/applications \
                 -name '*.desktop' 2>/dev/null | sort | while IFS= read -r f; do
                name=$(grep -m1 '^Name='      "$f" 2>/dev/null | cut -d= -f2-)
                exec=$(grep -m1 '^Exec='      "$f" 2>/dev/null | cut -d= -f2-)
                icon=$(grep -m1 '^Icon='      "$f" 2>/dev/null | cut -d= -f2-)
                cmnt=$(grep -m1 '^Comment='   "$f" 2>/dev/null | cut -d= -f2-)
                nod=$( grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)
                [ -z "$name" ] && continue
                [ "$nod" = "true" ] && continue
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
                // push — no QML binding triggered per item (single assign in onExited)
                launcher._tempApps.push({
                    name, comment, dpath, execCmd,
                    iconPath: ipath ? "file://" + ipath : ""
                })
            }
        }
        onExited: (code) => {
            console.log("[launcher] loaded", launcher._tempApps.length, "apps, exit:", code)
            launcher._tempApps.sort((a, b) => a.name.localeCompare(b.name))
            launcher.allApps = launcher._tempApps      // single QML assignment
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
        console.log("[launcher] launch:", app.name, "|", app.execCmd)
        const cmd = app.execCmd ? ["sh", "-c", app.execCmd] : ["gio", "launch", app.dpath]
        Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) +
            '; running: true; onExited: (c) => { console.log("[launcher] exited:", c); destroy() } }',
            launcher
        )
        visible = false
    }

    PanelWindow {
        id: win
        visible: launcher.visible
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: 0
        focusable: true
        color: "transparent"

        // Animated backdrop
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

        // ── Main card ────────────────────────────────────────────────────
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 520
            height: 480
            color: launcher.cBg
            border.color: launcher.cBorder
            border.width: 1
            radius: 6
            opacity: 0
            scale: 0.96

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 0

                // ── Search ───────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.bottomMargin: 8
                    color: launcher.cSurface
                    border.color: launcher.cBorder
                    border.width: 1
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "/"
                            color: launcher.cMuted
                            font.pixelSize: 14
                            font.family: "FiraCode Nerd Font"
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: launcher.cText
                            font.pixelSize: 14
                            font.family: "FiraCode Nerd Font"
                            clip: true
                            focus: true
                            selectionColor: Qt.rgba(1, 1, 1, 0.2)

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
                                text: "search..."
                                color: launcher.cMuted
                                font.pixelSize: 14
                                font.family: "FiraCode Nerd Font"
                                visible: !searchField.text
                            }
                        }
                    }
                }

                // ── App list ─────────────────────────────────────────────
                ListView {
                    id: appList
                    Layout.fillWidth: true
                    height: 408
                    clip: true
                    spacing: 1
                    model: launcher.filteredApps
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 300   // pre-render ~6 items outside viewport

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 3
                        contentItem: Rectangle {
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.2)
                        }
                        background: Item {}
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width - 4
                        height: 46
                        color: index === launcher.selectedIndex ? launcher.cSel : "transparent"
                        radius: 4

                        Behavior on color { ColorAnimation { duration: 90 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12

                            Image {
                                id: ico
                                source: modelData.iconPath || ""
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                                asynchronous: true
                                smooth: true
                                // Fade in once loaded
                                opacity: status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Text {
                                text: ""
                                font.pixelSize: 15
                                font.family: "FiraCode Nerd Font"
                                color: index === launcher.selectedIndex ? launcher.cSelText : launcher.cMuted
                                visible: !ico.visible
                                Layout.preferredWidth: 24
                            }

                            Text {
                                text: modelData.name
                                color: index === launcher.selectedIndex ? launcher.cSelText : launcher.cText
                                font.pixelSize: 13
                                font.family: "FiraCode Nerd Font"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
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

        // ── Enter animations (render-thread Animators) ────────────────────
        ParallelAnimation {
            id: openAnim
            OpacityAnimator  { target: backdrop; from: 0;    to: 0.6;  duration: 200; easing.type: Easing.OutCubic }
            OpacityAnimator  { target: card;     from: 0;    to: 1.0;  duration: 160; easing.type: Easing.OutCubic }
            ScaleAnimator    { target: card;     from: 0.96; to: 1.0;  duration: 220; easing.type: Easing.OutCubic }
        }

        onVisibleChanged: {
            if (visible) {
                backdrop.opacity = 0
                card.opacity     = 0
                card.scale       = 0.96
                openAnim.start()
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) launcher.visible = false
        }
    }
}
