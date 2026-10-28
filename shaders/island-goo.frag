#version 440
// The Island's black surface as one liquid shape: the capsule and the
// detached bubbles, their distance fields joined with a smooth minimum, so
// a bubble leaving the capsule draws a neck of liquid that thins and
// breaks. Also the key line just inside the edge and the soft shadow
// below: a faint contact shadow and a wider one further down, each the
// shape blurred (a Gaussian's edge, as a box-shadow draws it).
//
// Ported from crates/shoji-island/assets/src/effect/island-goo.frag
// (paint_main, the Island branch: Control Centre's menu shadow is left
// out). Uniform wiring: crates/shoji-island/src/island/mod.rs:9833-10010;
// QML side: components/Liquid.qml. Rebuild the .qsb: docs/SHADERS.md.
//
// Rects are logical px from the item's top-left: (x, y, width, height);
// a zero width leaves a bubble out. Colours arrive premultiplied (Qt's
// ShaderEffect premultiplies color properties).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 capsule;
    float capsuleRadius;
    vec4 leftBubble;
    vec4 rightBubble;
    // Smooth-minimum radius (logical px) for each bubble: how far the
    // liquid reaches across to it (wide while it travels, tight at rest).
    float leftSmoothness;
    float rightSmoothness;
    // The screen's top edge, `edge` logical px down from the item's top,
    // as one more shape the liquid joins with `edgeSmoothness` (0 leaves
    // it out).
    float edge;
    float edgeSmoothness;
    vec4 fill;
    // The key line, and its colour along the top.
    vec4 keyLine;
    vec4 rimTop;
    vec4 shadowColor;
    // Device pixels per logical px, and the item's size in logical px.
    float dpr;
    vec2 extent;
};

float rrect(vec2 p, vec4 rect, float radius) {
    vec2 halfSize = rect.zw * 0.5;
    vec2 q = abs(p - rect.xy - halfSize) - halfSize + vec2(radius);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

// `withEdge` 0 leaves the screen's edge out (the shadows: the edge's own
// would band the whole top of the screen).
float shape(vec2 p, float withEdge) {
    float d = rrect(p, capsule, capsuleRadius);
    if (leftBubble.z > 0.5) {
        d = smin(d, rrect(p, leftBubble, leftBubble.w * 0.5), max(leftSmoothness, 0.001));
    }
    if (rightBubble.z > 0.5) {
        d = smin(d, rrect(p, rightBubble, rightBubble.w * 0.5), max(rightSmoothness, 0.001));
    }
    if (edgeSmoothness > 0.5 && withEdge > 0.5) {
        d = smin(d, p.y - edge, edgeSmoothness);
    }
    return d;
}

// How much of the shape, `offset` px lower, `spread` px smaller and
// blurred by `sigma` (logical px), covers p: the logistic approximation
// of the Gaussian's integral, 1/2 at the edge.
float drop(vec2 p, float offset, float spread, float sigma) {
    float ds = shape(p - vec2(0.0, offset), 0.0) + spread;
    return 1.0 / (1.0 + exp(clamp(1.702 * ds / sigma, -80.0, 80.0)));
}

// Back to straight alpha (the uniforms arrive premultiplied).
vec4 straight(vec4 c) {
    return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}

vec4 over(vec4 below, vec4 colour, float coverage) {
    vec4 top = vec4(colour.rgb * colour.a, colour.a) * coverage;
    return top + below * (1.0 - top.a);
}

void main() {
    float s = max(dpr, 0.01);
    vec2 p = qt_TexCoord0 * extent;
    float d = shape(p, 1.0) * s;
    float contact = 0.4 * drop(p, 1.0, 0.0, 1.5);
    float key = drop(p, 8.0, 2.0, 11.0);
    // The Island hangs from the top of the window, which would cut off
    // what shows beside it there: the shadow grows in down its sides.
    float hang = smoothstep(capsule.y, capsule.y + 16.0, p.y);
    float island = 1.0 - (1.0 - contact) * (1.0 - key);
    vec4 shadowStraight = straight(shadowColor);
    float shadow = shadowStraight.a * island * hang;
    float inside = clamp(0.5 - d, 0.0, 1.0);
    vec4 colour = vec4(shadowStraight.rgb * shadow, shadow) * (1.0 - inside);
    colour = over(colour, straight(fill), inside);
    // A one-pixel key line just inside the edge, turning to `rimTop`
    // along the top (over the corners' height).
    float line = clamp(0.5 - abs(d + 0.5 * s) + 0.5 * s, 0.0, 1.0);
    float top = 1.0 - smoothstep(capsule.y, capsule.y + max(capsuleRadius, 1.0), p.y);
    colour = over(colour, mix(straight(keyLine), straight(rimTop), top), line * inside);
    fragColor = colour * qt_Opacity;
}
