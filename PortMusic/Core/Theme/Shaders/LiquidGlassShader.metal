#include <metal_stdlib>
#if __has_include(<SwiftUI/SwiftUI.h>)
#include <SwiftUI/SwiftUI.h>
#endif
using namespace metal;

// MARK: - Liquid Glass Exponent-6 Squircle Lens Distortion Shader
// Portiert die mathematische Brechung ohne ungueltige Parameter
#if __has_include(<SwiftUI/SwiftUI.h>)
[[stitchable]] float2 liquidGlassSquircleDistort(float2 position, float2 center, float2 size) {
    float2 halfSize = size * 0.5f;
    if (halfSize.x <= 0.0f || halfSize.y <= 0.0f) {
        return position;
    }
    float2 m2 = (position - center) / halfSize;
    float x2 = m2.x * m2.x;
    float y2 = m2.y * m2.y;
    // Exponent 6 superellipse squircle distance: x^6 + y^6
    float roundedBox = (x2 * x2 * x2) + (y2 * y2 * y2);

    if (roundedBox < 1.0f) {
        // Gueltige smoothstep-Parameter (edge0 < edge1)
        float clampedBox = clamp(roundedBox, 0.0f, 1.0f);
        float edgeDamping = 1.0f - smoothstep(0.70f, 1.0f, clampedBox);
        float factor = 1.0f - (clampedBox * 0.35f * edgeDamping);
        return center + (position - center) * factor;
    }
    return position;
}
#endif
