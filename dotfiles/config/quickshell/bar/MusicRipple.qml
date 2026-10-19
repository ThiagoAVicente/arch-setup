import QtQuick
import "../" as Root

// Music ripple along the bar's inner edge (the side facing the screen):
// cava bands mirrored from the middle outwards, bass in the centre. Sits
// behind the widgets; flat and invisible when nothing is playing.
Item {
    id: ripple
    anchors.fill: parent

    required property string edge
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property var levels: Root.Visualizer.levels
    readonly property int bands: 48
    readonly property int slots: bands * 2
    // Keep clear of the rounded ends
    readonly property real inset: Math.min(width, height) / 2
    readonly property real span: (vertical ? height : width) - 2 * inset
    readonly property real step: span / slots
    readonly property real maxDepth: 14

    visible: Root.Visualizer.playing
    opacity: Root.Visualizer.playing ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300 } }

    Repeater {
        model: ripple.slots

        Rectangle {
            required property int index
            // Mirror around the middle: centre slots carry the lowest band
            readonly property int band: index < ripple.bands ? ripple.bands - 1 - index : index - ripple.bands
            readonly property real level: ripple.levels[band] ?? 0
            property real depth: 1.5 + level * ripple.maxDepth
            readonly property real along: ripple.inset + index * ripple.step + ripple.step * 0.15
            readonly property real breadth: ripple.step * 0.7

            radius: 2
            color: Qt.rgba(1, 1, 1, 0.1 + level * 0.22)

            x: ripple.vertical ? (ripple.edge === "left" ? ripple.width - depth - 1 : 1) : along
            y: ripple.vertical ? along : (ripple.edge === "bottom" ? 1 : ripple.height - depth - 1)
            width: ripple.vertical ? depth : breadth
            height: ripple.vertical ? breadth : depth

            Behavior on depth { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }
    }
}
