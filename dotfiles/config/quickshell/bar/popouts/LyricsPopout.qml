pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.." as Root

// Synced lyrics of what Spotify is playing (Lyrics.qml), dropped from the bar
// under the now-playing pill. The song scrolls past with the line being sung
// held in the middle in full colour and the others dimmed around it. The
// drawer keeps one fixed size, so it never resizes as lines change. Opened and closed by clicking the pill; it stays open while
// you work.
PanelWindow {
    id: root

    required property bool isOpen
    required property var hub

    signal closeRequested()

    property bool shown: false
    visible: shown
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false
    WlrLayershell.namespace: "qs-drawer"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property string barEdge: Root.BarLayout.dockEdgeOf(screen?.name ?? "")
    readonly property bool barVertical: Root.BarLayout.isVertical(barEdge)
    readonly property int endInset: Root.Theme.barMarginSide + Root.Theme.barThickness / 2
    anchors {
        top: barEdge === "top"
        bottom: barVertical || barEdge === "bottom"
        left: barVertical ? barEdge === "left" : true
        right: barVertical ? barEdge === "right" : false
    }
    margins.left: !barVertical ? endInset : 0
    margins.bottom: barVertical ? endInset : 0

    implicitWidth: barVertical ? goo.topY + goo.fullW + 72 : goo.fullW + 40
    implicitHeight: barVertical ? goo.fullH + 40 : goo.topY + goo.fullH + 72
    // Clicks pass through: it only shows text
    mask: Region {}

    Root.LiquidSurface {
        id: goo
        alongOffset: root.barVertical
            ? (root.screen?.height ?? 0) - root.endInset - root.implicitHeight
            : root.endInset
        fullW: 440
        fullH: card.height + 1
        onClosed: root.shown = false
    }

    // Lazily created already open, so the first open has no change signal
    Component.onCompleted: if (isOpen) isOpenChanged()
    onIsOpenChanged: {
        if (isOpen) {
            shown = true
            // Switching popouts on the same screen: grow out of the open one
            const prev = hub.popoutSurface
            const swap = prev && prev !== goo && hub.popoutSurfaceScreen === root.screen
                && prev.revealH > 0
            goo.fromW = swap ? Math.round(prev.revealW) : 0
            goo.fromH = swap ? Math.round(prev.revealH) : 0
            if (swap) prev.handOff(goo.fullW, goo.fullH)
            hub.popoutSurface = goo
            hub.popoutSurfaceScreen = root.screen
            goo.open()
        } else {
            goo.close()
        }
    }

    // ── UI ─────────────────────────────────────────────────────────────
    Item {
        id: card

        // Content only, the LiquidSurface is its surface
        x: goo.cardX
        y: goo.cardY
        width: goo.fullW
        // Fixed: room for about five rows, so the drawer never resizes
        height: 196
        opacity: goo.contentOpacity

        // The whole song as a list that scrolls to keep the line being sung
        // in the middle, like Spotify's lyrics view
        ListView {
            id: list
            anchors { fill: parent; leftMargin: 18; rightMargin: 18; topMargin: 8; bottomMargin: 10 }
            visible: Root.Lyrics.available
            clip: true
            interactive: false
            spacing: 6
            model: Root.Lyrics.lines
            currentIndex: Math.max(0, Root.Lyrics.index)
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: height / 2 - 16
            preferredHighlightEnd: height / 2 + 16
            highlightMoveDuration: 420
            highlightMoveVelocity: -1
            highlightFollowsCurrentItem: true

            delegate: Text {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === Root.Lyrics.index
                readonly property int distance: Math.abs(index - Math.max(0, Root.Lyrics.index))
                width: ListView.view.width
                text: modelData.text !== "" ? modelData.text : "󰝚"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: current ? Root.Theme.barText : Root.Theme.barMuted
                font.family: Root.Theme.fontFamily
                font.pixelSize: 16
                font.weight: current ? Font.DemiBold : Font.Normal
                // Lines further from the current one fade out
                opacity: current ? 1 : Math.max(0.25, 0.8 - 0.22 * (distance - 1))
                scale: current ? 1 : 0.86
                Behavior on color { ColorAnimation { duration: 300 } }
                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }

        // Soft fade into the drawer at the top and bottom of the list, kept
        // inside the list so it never paints over the drawer's outline
        Rectangle {
            anchors { left: list.left; right: list.right; top: list.top }
            height: 28
            gradient: Gradient {
                GradientStop { position: 0; color: Root.Theme.barBg }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            anchors { left: list.left; right: list.right; bottom: list.bottom }
            height: 28
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Root.Theme.barBg }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !Root.Lyrics.available
            text: Root.Lyrics.loading ? "Looking for lyrics…" : "No synced lyrics for this song"
            color: Root.Theme.barMuted
            font.family: Root.Theme.fontFamily
            font.pixelSize: 14
        }
    }
}
