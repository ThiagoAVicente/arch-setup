import QtQuick
import QtQuick.Shapes
import "../" as Root

// Music hanging off the bar's inner edge (the side facing the screen): one
// smooth liquid lip in the bar's colour whose depth follows the cava bands,
// mirrored from the middle outwards with the bass in the centre. It sinks
// back into the bar when nothing plays.
Item {
    id: ripple

    required property string edge
    // Screen this lip is on, and where the item starts along the edge (screen
    // px), to place the gaps left for open drawers/popouts
    property string screenName: ""
    property real alongOrigin: 0
    // Room the lip may grow into, away from the bar
    readonly property real maxDepth: 22
    readonly property bool vertical: edge === "left" || edge === "right"
    // Keep clear of the bar's rounded ends
    property real inset: 17
    readonly property real span: (vertical ? height : width) - 2 * inset

    visible: Root.Visualizer.playing

    // Bands mirrored around the centre, softened with their neighbours so
    // the lip rolls instead of spiking
    readonly property var profile: {
        const lv = Root.Visualizer.levels
        const n = lv.length
        if (n === 0) return []
        const soft = []
        for (let i = 0; i < n; i++) {
            const a = lv[Math.max(0, i - 1)], b = lv[i], c = lv[Math.min(n - 1, i + 1)]
            soft.push((a + 2 * b + c) / 4)
        }
        return soft.slice().reverse().concat(soft)
    }

    // Bar frame (u along the edge, v away from the bar) -> item coordinates
    function px(u, v) { return edge === "left" ? v : edge === "right" ? width - v : u }
    function py(u, v) { return edge === "top" ? v : edge === "bottom" ? height - v : u }
    function pt(u, v) { return px(u, v).toFixed(1) + " " + py(u, v).toFixed(1) }

    // Quadratic curve through the midpoints of the band tips, closed along
    // the bar's edge (not under it: overlapping the translucent pill would
    // show as a darker seam)
    readonly property string svg: {
        const p = profile
        const n = p.length
        if (n < 2) return ""
        const step = span / (n - 1)
        const base = 0
        // Parts around drawers/popouts hanging off the bar, easing to nothing
        // at their fillets
        const gaps = []
        for (const k in Root.State.holes) {
            const h = Root.State.holes[k]
            if (h.screen === screenName) gaps.push([h.c - alongOrigin, h.half])
        }
        const feather = 28
        const open = u => {
            let f = 1
            for (const g of gaps) f = Math.min(f, Math.max(0, Math.min(1, (Math.abs(u - g[0]) - g[1]) / feather)))
            return f
        }
        // Tapers to nothing at both ends so it melts into the bar's corners
        const depth = i => Math.sqrt(Math.sin(Math.PI * i / (n - 1)) * open(inset + i * step)) * (1 + p[i] * maxDepth)
        let d = "M " + pt(inset, base) + " L " + pt(inset, depth(0))
        for (let i = 1; i < n; i++) {
            const u0 = inset + (i - 1) * step, u1 = inset + i * step
            d += " Q " + pt(u0, depth(i - 1)) + " " + pt((u0 + u1) / 2, (depth(i - 1) + depth(i)) / 2)
        }
        d += " L " + pt(inset + span, depth(n - 1)) + " L " + pt(inset + span, base) + " Z"
        return d
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Root.Theme.barBg
            strokeColor: "transparent"
            PathSvg { path: ripple.svg }
        }
    }
}
