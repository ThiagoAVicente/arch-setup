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

    // ── Shared surface language ──────────────────────────────────────────
    // One surface, one hairline everywhere (bar, popouts, modals, OSD)
    readonly property color panel:         Qt.rgba(0.063, 0.063, 0.071, 0.92)
    readonly property color panelSolid:    "#0f0f11"
    // Frosted variant — pair with hyprland layerrule blur on qs-overlay
    readonly property color panelFrost:    Qt.rgba(0.055, 0.055, 0.067, 0.72)
    readonly property color hairline:      Qt.rgba(1, 1, 1, 0.09)
    readonly property color panelHi:       Qt.rgba(1, 1, 1, 0.06)
    readonly property color focusRing:     Qt.rgba(1, 1, 1, 0.25)

    // Borders — bright white for glow effect (dark modals)
    readonly property color border:        Qt.rgba(1, 1, 1, 0.22)
    readonly property color borderStrong:  Qt.rgba(1, 1, 1, 0.40)
    readonly property color hover:         Qt.rgba(1, 1, 1, 0.06)
    readonly property color hoverStrong:   Qt.rgba(1, 1, 1, 0.12)
    readonly property color selected:      Qt.rgba(1, 1, 1, 0.10)
    readonly property color selectedBorder:Qt.rgba(1, 1, 1, 0.50)
    readonly property color backdrop:      Qt.rgba(0, 0, 0, 0.55)
    readonly property color glassHi:       Qt.rgba(1, 1, 1, 0.12)

    // ── Bar (dark pill, single hairline) ─────────────────────────────────
    readonly property color barBg:         panel
    readonly property color barText:       "#f2f2f4"
    readonly property color barSubtext:    "#c9c9cf"
    readonly property color barMuted:      "#8f8f96"
    readonly property color barAccent:     "#ffffff"
    readonly property color barBorder:     hairline
    readonly property color barBorderStrong:Qt.rgba(1, 1, 1, 0.22)
    readonly property color barHover:      Qt.rgba(1, 1, 1, 0.06)
    readonly property color barHoverStrong:Qt.rgba(1, 1, 1, 0.10)

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
