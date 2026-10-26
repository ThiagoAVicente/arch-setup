#version 440
// Music wave around the bar (see MusicRipple.qml), drawn per pixel: both long
// sides of the pill swell in the bar's colour with the cava bands, mirrored
// from the middle outwards with the bass in the centre, rimmed with a red
// line in the accent colour that glows brighter over loud bands. The outer side (facing the screen
// edge) runs inverted, peak - level, so it swells where the inner side dips.
// The rounded ends stay calm.
// Rebuild after editing:
//   /usr/lib/qt6/bin/qsb --glsl "300 es,330" -o lip.frag.qsb lip.frag
//   /usr/lib/qt6/bin/qsb --glsl "300 es,330" -o lip.vert.qsb lip.vert

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The pill plus `room` px of space for the wave on every side
    vec2 itemSize;
    float room;
    // 0 top, 1 bottom, 2 left, 3 right: the bar's edge of the screen;
    // 4: the round widget in the middle of the screen, waving all the way
    // round (the item is then the circle plus `room`)
    float edgeId;
    // Kept clear of the bar's rounded ends, px along the pill
    float inset;
    float maxDepth;
    // Openings for drawers/popouts on the inner side: (centre, half width)
    // twice, px along the pill
    float feather;
    vec4 gaps;
    // 32 bands, bass first, already smoothed, and the loudest of them
    // (Visualizer.qml)
    vec4 l0; vec4 l1; vec4 l2; vec4 l3; vec4 l4; vec4 l5; vec4 l6; vec4 l7;
    float peak;
    vec4 fill;
    // Accent colour (Accent.qml), lightened toward white over loud bands
    vec4 rim;
    // Border width (Theme.barBorderWidth)
    float rimWidth;
    // 0: the wave's body, drawn under the pill; 1: its rim and glow, drawn
    // over the pill so the rim lands exactly where the bar's border was
    float layerMode;
};

const int BANDS = 32;
const int N = 2 * BANDS;   // mirrored
const float PI = 3.14159265;

float band(int i) {
    i = clamp(i, 0, BANDS - 1);
    vec4 v = i < 4 ? l0 : i < 8 ? l1 : i < 12 ? l2 : i < 16 ? l3
           : i < 20 ? l4 : i < 24 ? l5 : i < 28 ? l6 : l7;
    int k = i - (i / 4) * 4;
    return k == 0 ? v.x : k == 1 ? v.y : k == 2 ? v.z : v.w;
}

// Level at control point k of the mirrored profile (bass in the middle);
// inverted on the outer side
float level(int k, bool inner) {
    k = clamp(k, 0, N - 1);
    float v = band(k < BANDS ? BANDS - 1 - k : k - BANDS);
    return inner ? v : max(peak - v, 0.0);
}

bool circle() { return edgeId > 3.5; }
bool vertical() { return edgeId >= 2.0 && !circle(); }
// Where the wave starts and how far it runs: along the pill between its
// rounded ends, or once round the circle (set in main)
float gInset;
float gSpan;
float span() { return gSpan; }

float opening(float u) {
    float f = 1.0;
    f = min(f, clamp((abs(u - gaps.x) - gaps.y) / feather, 0.0, 1.0));
    f = min(f, clamp((abs(u - gaps.z) - gaps.w) / feather, 0.0, 1.0));
    return f;
}

// Depth at control point k, tapering to nothing at both ends; drawers only
// open gaps on the inner side
float tip(int k, bool inner) {
    k = clamp(k, 0, N - 1);
    float u = gInset + float(k) * span() / float(N - 1);
    // max(): sin(PI) comes out a hair below zero in float, and sqrt of that
    // is NaN. Round the circle there are no ends to taper into
    float taper = circle() ? 1.0
        : max(sin(PI * float(k) / float(N - 1)), 0.0) * (inner ? opening(u) : 1.0);
    return sqrt(taper) * (1.0 + level(k, inner) * maxDepth);
}

// Quadratic B-spline through the tips (the curve through their midpoints)
float depthAt(float u, bool inner) {
    float x = clamp((u - gInset) / span(), 0.0, 1.0) * float(N - 1);
    int k = int(floor(x + 0.5));
    float s = x - (float(k) - 0.5);
    return 0.5 * (1.0 - s) * (1.0 - s) * tip(k - 1, inner)
         + (-s * s + s + 0.5) * tip(k, inner)
         + 0.5 * s * s * tip(k + 1, inner);
}

// Loudness around u, smoothed over a few bands, calm at the ends
float loudness(float u, bool inner) {
    float t = clamp((u - gInset) / span(), 0.0, 1.0);
    float x = t * float(N - 1);
    int k = int(floor(x));
    float sum = 0.0;
    for (int j = -3; j <= 3; j++) sum += level(k + j, inner);
    return sum / 7.0 * (circle() ? 1.0 : sqrt(max(sin(PI * t), 0.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float u, v;
    bool inner = true;
    if (circle()) {
        // u round the circle from the bottom, clockwise (bass at the top),
        // v out from its edge
        float r = itemSize.x * 0.5 - room;
        vec2 q = p - itemSize * 0.5;
        gInset = 0.0;
        gSpan = 2.0 * PI * r;
        u = (atan(q.x, -q.y) / (2.0 * PI) + 0.5) * gSpan;
        v = length(q) - r;
    } else {
        // u along the pill from its start, a across from its centre line
        float pillLen = (vertical() ? itemSize.y : itemSize.x) - 2.0 * room;
        gInset = inset;
        gSpan = pillLen - 2.0 * inset;
        u = (vertical() ? p.y : p.x) - room;
        float a = vertical() ? p.x - itemSize.x * 0.5 : p.y - itemSize.y * 0.5;
        float halfT = (vertical() ? itemSize.x : itemSize.y) * 0.5 - room;
        // v: distance out from the pill's long side
        v = abs(a) - halfT;
        // The side facing the screen (away from the bar's screen edge)
        inner = (edgeId == 0.0 || edgeId == 2.0) ? a > 0.0 : a < 0.0;
    }

    vec4 col = vec4(0.0);
    if (u >= gInset && u <= gInset + span()) {
        float d = depthAt(u, inner);
        // Slope, to measure across the curve rather than straight out
        float slope = (depthAt(u + 1.0, inner) - depthAt(u - 1.0, inner)) * 0.5;
        float k = inversesqrt(1.0 + slope * slope);
        // Signed distance to the wave's outline, positive inside
        float dist = (d - v) * k;

        if (layerMode < 0.5) {
            // Body, outside the pill only (the pill is drawn over it)
            col = fill * clamp(dist + 0.5, 0.0, 1.0) * clamp(v + 0.5, 0.0, 1.0);
        } else {
            float l = loudness(u, inner);
            vec3 tint = mix(rim.rgb, vec3(1.0), 0.3 * l);
            // Rim: rimWidth px inward from the outline; where the wave is
            // flat that is the bar's own border row, cut away in Bar.qml
            float edge = clamp(dist + 0.5, 0.0, 1.0) - clamp(dist - rimWidth + 0.5, 0.0, 1.0);
            // Glow: soft falloff outward from the outline, stronger when loud
            float out_ = max(-dist, 0.0);
            float halo = exp(-out_ / (2.5 + 3.0 * l)) * (0.30 + 0.45 * l) * step(0.0, v);
            float aRim = edge * (0.75 + 0.25 * l);
            float aGlow = halo * (1.0 - edge);
            col = vec4(tint, 1.0) * (aRim + aGlow);
        }
    }
    fragColor = col * qt_Opacity;
}
