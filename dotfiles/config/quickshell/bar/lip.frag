#version 440
// Music lip, drawn per pixel (see MusicRipple.qml): a liquid bulge in the
// bar's colour whose depth follows the cava bands, mirrored from the middle
// outwards with the bass in the centre, rimmed with a red line that glows
// brighter over loud bands.
// Rebuild after editing:
//   /usr/lib/qt6/bin/qsb --glsl "300 es,330" -o lip.frag.qsb lip.frag
//   /usr/lib/qt6/bin/qsb --glsl "300 es,330" -o lip.vert.qsb lip.vert

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    // 0 top, 1 bottom, 2 left, 3 right: the bar's edge of the screen
    float edgeId;
    // Kept clear of the bar's rounded ends, px along the edge
    float inset;
    float maxDepth;
    // Openings for drawers/popouts: (centre, half width) twice, px along
    float feather;
    vec4 gaps;
    // 24 bands, bass first, already smoothed (Visualizer.qml)
    vec4 l0; vec4 l1; vec4 l2; vec4 l3; vec4 l4; vec4 l5;
    vec4 fill;
};

const int BANDS = 24;
const int N = 2 * BANDS;   // mirrored
const float PI = 3.14159265;

float band(int i) {
    i = clamp(i, 0, BANDS - 1);
    vec4 v = i < 4 ? l0 : i < 8 ? l1 : i < 12 ? l2 : i < 16 ? l3 : i < 20 ? l4 : l5;
    int k = i - (i / 4) * 4;
    return k == 0 ? v.x : k == 1 ? v.y : k == 2 ? v.z : v.w;
}

// Level at control point k of the mirrored profile (bass in the middle)
float level(int k) {
    k = clamp(k, 0, N - 1);
    return band(k < BANDS ? BANDS - 1 - k : k - BANDS);
}

float span() { return (edgeId >= 2.0 ? itemSize.y : itemSize.x) - 2.0 * inset; }

float opening(float u) {
    float f = 1.0;
    f = min(f, clamp((abs(u - gaps.x) - gaps.y) / feather, 0.0, 1.0));
    f = min(f, clamp((abs(u - gaps.z) - gaps.w) / feather, 0.0, 1.0));
    return f;
}

// Depth at control point k, tapering to nothing at both ends
float tip(int k) {
    k = clamp(k, 0, N - 1);
    float u = inset + float(k) * span() / float(N - 1);
    // max(): sin(PI) comes out a hair below zero in float, and sqrt of that
    // is NaN, which blanked the lip's last stretch
    return sqrt(max(sin(PI * float(k) / float(N - 1)), 0.0) * opening(u)) * (1.0 + level(k) * maxDepth);
}

// Quadratic B-spline through the tips (the curve through their midpoints)
float depthAt(float u) {
    float x = clamp((u - inset) / span(), 0.0, 1.0) * float(N - 1);
    int k = int(floor(x + 0.5));
    float s = x - (float(k) - 0.5);
    return 0.5 * (1.0 - s) * (1.0 - s) * tip(k - 1)
         + (-s * s + s + 0.5) * tip(k)
         + 0.5 * s * s * tip(k + 1);
}

// Loudness around u, smoothed over a few bands, calm at the ends
float loudness(float u) {
    float t = clamp((u - inset) / span(), 0.0, 1.0);
    float x = t * float(N - 1);
    int k = int(floor(x));
    float sum = 0.0;
    for (int j = -3; j <= 3; j++) sum += level(k + j);
    return sum / 7.0 * sqrt(max(sin(PI * t), 0.0));
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    // u along the edge, v away from the bar
    float u = edgeId >= 2.0 ? p.y : p.x;
    float v = edgeId == 0.0 ? p.y : edgeId == 1.0 ? itemSize.y - p.y
            : edgeId == 2.0 ? p.x : itemSize.x - p.x;

    vec4 col = vec4(0.0);
    if (u >= inset && u <= inset + span()) {
        float d = depthAt(u);
        // Slope, to measure the rim across the curve rather than straight down
        float slope = (depthAt(u + 1.0) - depthAt(u - 1.0)) * 0.5;
        float k = inversesqrt(1.0 + slope * slope);

        // Body
        col = fill * clamp((d - v) * k + 0.5, 0.0, 1.0);

        // Rim: 1.5px along the curve, never thinner than 1px where the lip
        // flattens, standing in for the bar's hairline cut off under it
        float outer = max(d, 1.0);
        float dist = (outer - v) * k;
        float rim = clamp(dist + 0.5, 0.0, 1.0) - clamp(dist - 1.5 + 0.5, 0.0, 1.0);
        float l = loudness(u);
        vec4 red = vec4(0.90 + 0.10 * l, 0.22 + 0.25 * l, 0.25 + 0.20 * l, 1.0) * (0.55 + 0.45 * l);
        col = red * rim + col * (1.0 - red.a * rim);
    }
    fragColor = col * qt_Opacity;
}
