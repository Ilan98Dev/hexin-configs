#version 440

// Travelling neon wave for the HexinAgent edge frame.
//
// The QML side passes one ShaderEffect per screen edge. `vertical` and `flip`
// orient the strip, `uSign` makes the along-axis run clockwise on every edge,
// and the sine below produces the actual wave. Output is premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;
    float phase;
    float cycles;
    float amp;
    float base;
    float vertical;
    float flip;
    float uSign;
    float stripPx;
    float depth;
};

void main() {
    float along = vertical > 0.5 ? qt_TexCoord0.y : qt_TexCoord0.x;
    float across = vertical > 0.5 ? qt_TexCoord0.x : qt_TexCoord0.y;

    if (uSign < 0.0)
        along = 1.0 - along;
    if (flip > 0.5)
        across = 1.0 - across;

    // Glow falls off towards the middle of the screen.
    float dist = across * stripPx;
    float glow = 1.0 - clamp(dist / depth, 0.0, 1.0);
    glow = glow * glow;

    // The actual wave: a sine travelling along the edge, mapped between
    // `base` (floor) and `base + amp` (peak). Integer `cycles` keeps adjacent
    // edges in phase at the corners.
    float wave = base + amp * (0.5 + 0.5 * sin(6.2831853 * (cycles * along - phase)));
    wave = clamp(wave, 0.0, 1.0);

    float a = wave * glow;
    fragColor = vec4(accent.rgb * a, a) * qt_Opacity;
}
