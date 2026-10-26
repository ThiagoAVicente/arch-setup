import QtQuick
import "../" as Root

// Music wave around the bar: both long sides of the pill swell in the bar's
// colour with the cava bands, mirrored from the middle outwards with the bass
// in the centre, rimmed in red that glows over the loud bands. The side facing
// the screen edge runs inverted, swelling where the inner side dips. It sinks back
// into the bar when nothing plays.
// Sits under the pill, `room` px bigger on every side; the bar window keeps
// that room reserved so the wave never slips under windows.
// Drawn on the GPU (lip.frag): the bands are smoothed once in Visualizer and
// each screen only hands them to its shader.
ShaderEffect {
    id: ripple

    required property string edge
    // Screen this bar is on, and where the pill starts along the edge
    // (screen px), to place the gaps left for open drawers/popouts
    property string screenName: ""
    property real alongOrigin: 0

    visible: Root.Visualizer.playing

    // ── Shader inputs ──────────────────────────────────────────────────
    readonly property vector2d itemSize: Qt.vector2d(width, height)
    readonly property real room: Root.Theme.barWaveRoom
    // Tallest swell, rim included, stays inside the room
    readonly property real maxDepth: room - 1
    readonly property real edgeId: ({ top: 0, bottom: 1, left: 2, right: 3, center: 4 })[edge] ?? 0
    // Keep clear of the bar's rounded ends (Bar.qml leaves its hairline
    // whole over this stretch)
    property real inset: 17
    readonly property real feather: 28
    // Up to two drawers/popouts hanging off this screen's bar: (centre,
    // half width) along the pill; unused slots sit far off
    readonly property vector4d gaps: {
        const g = []
        for (const k in Root.State.holes) {
            const h = Root.State.holes[k]
            if (h.screen === screenName) g.push(h.c - alongOrigin, h.half)
        }
        while (g.length < 4) g.push(-1e5, 0)
        return Qt.vector4d(g[0], g[1], g[2], g[3])
    }
    readonly property var bands: Root.Visualizer.packed
    readonly property vector4d l0: bands[0] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d l1: bands[1] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d l2: bands[2] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d l3: bands[3] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d l4: bands[4] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d l5: bands[5] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d l6: bands[6] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d l7: bands[7] ?? Qt.vector4d(0, 0, 0, 0)
    readonly property real peak: Root.Visualizer.peak
    readonly property color fill: Root.Theme.barBg
    readonly property color rim: Root.Accent.color
    readonly property real rimWidth: Root.Theme.barBorderWidth
    // 0: body under the pill, 1: rim and glow over it (Bar.qml has one each)
    property real layerMode: 0

    vertexShader: Qt.resolvedUrl("lip.vert.qsb")
    fragmentShader: Qt.resolvedUrl("lip.frag.qsb")
}
