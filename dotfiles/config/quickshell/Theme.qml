pragma Singleton
import QtQuick

QtObject {
    // Neutral grayscale palette — lifted to make white borders glow
    readonly property color bg:       "#1c1c1c"
    readonly property color mantle:   "#161616"
    readonly property color surface:  "#262626"
    readonly property color surface2: "#303030"
    readonly property color overlay:  "#3a3a3a"
    readonly property color muted:    "#6a6a6a"
    readonly property color subtext:  "#a8a8a8"
    readonly property color text:     "#e6e6e6"
    readonly property color bright:   "#ffffff"

    // Accent — neutral light grey
    readonly property color accent:   "#e0e0e0"
    readonly property color accent2:  "#8a8a8a"

    // Semantic — colorful for state clarity
    readonly property color ok:       "#7fb98a"
    readonly property color warn:     "#d9c78a"
    readonly property color alert:    "#d9a07a"
    readonly property color critical: "#d97a8e"

    // Borders — bright white for glow effect
    readonly property color border:        Qt.rgba(1, 1, 1, 0.22)
    readonly property color borderStrong:  Qt.rgba(1, 1, 1, 0.40)
    readonly property color hover:         Qt.rgba(1, 1, 1, 0.06)
    readonly property color hoverStrong:   Qt.rgba(1, 1, 1, 0.12)
    readonly property color selected:      Qt.rgba(1, 1, 1, 0.10)
    readonly property color selectedBorder:Qt.rgba(1, 1, 1, 0.50)
    readonly property color backdrop:      Qt.rgba(0, 0, 0, 0.55)
    readonly property color glassHi:       Qt.rgba(1, 1, 1, 0.12)

    // Typography
    readonly property string fontFamily: "FiraCode Nerd Font"
    readonly property string fontMono:   "FiraCode Nerd Font Mono"

    // Geometry
    readonly property int radiusSm: 6
    readonly property int radiusMd: 10
    readonly property int radiusLg: 14
    readonly property int radiusXl: 18

    readonly property int paddingSm: 8
    readonly property int paddingMd: 12
    readonly property int paddingLg: 18
}
