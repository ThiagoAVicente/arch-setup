pragma Singleton
import QtQuick
import "." as Root

QtObject {
    // Light mode, switched from the bar (BarLightToggle) and kept across restarts
    readonly property bool light: Root.State.lightMode
    // Foreground ink: white on the dark theme, black on the light one
    function ink(a) { return light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a) }

    // Neutral grayscale palette, lifted to make white borders glow
    readonly property color bg:       light ? "#f4f4f6" : "#1c1c1c"
    readonly property color mantle:   light ? "#ececef" : "#161616"
    readonly property color surface:  light ? "#e6e6ea" : "#262626"
    readonly property color surface2: light ? "#dadade" : "#303030"
    readonly property color overlay:  light ? "#cfcfd4" : "#3a3a3a"
    readonly property color muted:    light ? "#8a8a90" : "#6a6a6a"
    readonly property color subtext:  light ? "#55555b" : "#a8a8a8"
    readonly property color text:     light ? "#1c1c1f" : "#e6e6e6"
    readonly property color bright:   light ? "#000000" : "#ffffff"

    // Accent is a neutral light grey
    readonly property color accent:   light ? "#202024" : "#e0e0e0"
    readonly property color accent2:  light ? "#77777d" : "#8a8a8a"

    // Semantic colours are colorful for state clarity
    readonly property color ok:       light ? "#3f8a4e" : "#7fb98a"
    readonly property color warn:     light ? "#9c8526" : "#d9c78a"
    readonly property color alert:    light ? "#b3672e" : "#d9a07a"
    readonly property color critical: light ? "#c0405a" : "#d97a8e"

    // ── Shared surface language ──────────────────────────────────────────
    // One surface, one hairline everywhere (bar, popouts, modals, OSD)
    readonly property color panel:         light ? Qt.rgba(0.965, 0.965, 0.97, 0.94) : Qt.rgba(0.063, 0.063, 0.071, 0.92)
    readonly property color panelSolid:    light ? "#fafafb" : "#0f0f11"
    // Frosted variant, pair it with hyprland layerrule blur on qs-overlay
    readonly property color panelFrost:    light ? Qt.rgba(0.96, 0.96, 0.97, 0.80) : Qt.rgba(0.055, 0.055, 0.067, 0.72)
    readonly property color hairline:      ink(0.09)
    readonly property color panelHi:       ink(0.06)
    readonly property color focusRing:     ink(0.25)

    // Borders are bright white for glow effect (dark modals)
    readonly property color border:        ink(0.22)
    readonly property color borderStrong:  ink(0.40)
    readonly property color hover:         ink(0.06)
    readonly property color hoverStrong:   ink(0.12)
    readonly property color selected:      ink(0.10)
    readonly property color selectedBorder:ink(0.50)
    readonly property color backdrop:      Qt.rgba(0, 0, 0, 0.55)
    readonly property color glassHi:       ink(0.12)

    // ── Bar (pill, single hairline) ──────────────────────────────────────
    readonly property color barBg:         panel
    readonly property color barText:       light ? "#1a1a1d" : "#f2f2f4"
    readonly property color barSubtext:    light ? "#3c3c42" : "#c9c9cf"
    readonly property color barMuted:      light ? "#76767e" : "#8f8f96"
    readonly property color barAccent:     light ? "#000000" : "#ffffff"
    // Text/icons drawn on a barText/barAccent-coloured chip
    readonly property color barInverse:    light ? "#f2f2f4" : panelSolid
    readonly property color barBorder:     Qt.rgba(Root.Accent.color.r, Root.Accent.color.g, Root.Accent.color.b, 0.85)
    readonly property color barBorderStrong:ink(0.22)
    readonly property color barHover:      ink(0.06)
    readonly property color barHoverStrong:ink(0.10)

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

    // Bar pill geometry (shared so overlays can attach to the bar)
    readonly property int barThickness: 34
    readonly property int barBorderWidth: 2
    // Space kept around the pill for the music wave (bar/MusicRipple.qml),
    // reserved whether or not anything plays so windows never reflow
    readonly property int barWaveRoom: 15
    readonly property int barMarginTop: barWaveRoom
    readonly property int barMarginSide: barWaveRoom
}
