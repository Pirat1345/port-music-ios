#include <metal_stdlib>
#if __has_include(<SwiftUI/SwiftUI.h>)
#include <SwiftUI/SwiftUI.h>
#endif
using namespace metal;

// MARK: - Liquid Glass Exponent-6 Squircle Lens Distortion Shader
// Portiert die exakte Shader-Mathematik:
// roundedBox = pow(abs(m2.x), 6.0) + pow(abs(m2.y), 6.0)
// lens = (uv - 0.5) * (1.0 - roundedBox * 5000.0) + 0.5
// rb2 = clamp((0.95 - roundedBox * 9500.0) * 16.0, 0.0, 1.0) - clamp(pow(0.9 - roundedBox * 9500.0, 1.0) * 16.0, 0.0, 1.0)

#if __has_include(<SwiftUI/SwiftUI.h>)
[[stitchable]] float2 liquidGlassSquircleDistort(float2 position, float2 center, float2 size) {
    float2 halfSize = size * 0.5f;
    if (halfSize.x <= 0.0f || halfSize.y <= 0.0f) {
        return position;
    }
    float2 m2 = (position - center) / halfSize;
    float x2 = m2.x * m2.x;
    float y2 = m2.y * m2.y;
    // Exponent 6 superellipse squircle distance function: x^6 + y^6
    float roundedBox = (x2 * x2 * x2) + (y2 * y2 * y2);

    if (roundedBox < 1.0f) {
        // Nichtlineare optische Brechung zum Linsenzentrum (Kantenkruemmung)
        // Am Rand (0.75 bis 1.0) zieht die Verzerrung exponentiell an,
        // waehrend das Linsenzentrum (0 bis 0.6) klar und verzerrungsfrei bleibt
        float edgeDamping = smoothstep(1.0f, 0.70f, roundedBox);
        float factor = 1.0f - (roundedBox * 0.45f * edgeDamping);
        return center + (position - center) * factor;
    }
    return position;
}
#endif
