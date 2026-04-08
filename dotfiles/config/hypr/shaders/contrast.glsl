#version 300 es
precision mediump float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 color = texture(tex, v_texcoord);

    // Brightness (+0.05) and contrast (1.2)
    float brightness = 0.10;
    float contrast   = 1.3;

    // Lift shadows via gamma (< 1.0 = brighter darks)
    color.rgb = pow(color.rgb, vec3(0.85));
    color.rgb += brightness;
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    fragColor = color;
}
