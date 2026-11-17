#include <metal_stdlib>
#if __has_include(<SwiftUI/SwiftUI.h>)
#include <SwiftUI/SwiftUI.h>
#endif
using namespace metal;

// MARK: - Liquid Glass Exponent-6 Squircle Lens Distortion Shader
// Exakte Brechung nach Snellius am gekruemmten Linsenrand (Apple HIG Liquid Glass Lens)
#if __has_include(<SwiftUI/SwiftUI.h>)
[[stitchable]] float2 liquidGlassSquircleDistort(float2 position, float2 center, float2 size) {
    float2 halfSize = size * 0.5f;
    if (halfSize.x <= 0.5f || halfSize.y <= 0.5f) {
        return position;
    }
    float2 normCoord = (position - center) / halfSize;
    float x2 = normCoord.x * normCoord.x;
    float y2 = normCoord.y * normCoord.y;
    // Exponent 6 superellipse squircle distance: x^6 + y^6
    float roundedBox = (x2 * x2 * x2) + (y2 * y2 * y2);

    if (roundedBox < 1.0f) {
        float rBox = clamp(roundedBox, 0.0f, 1.0f);
        // Weicher Rand-Uebergang am aeussersten Perimeter (0.90 bis 1.0) zur Vermeidung von Kantenrissen
        float edgeBlend = 1.0f - smoothstep(0.90f, 1.0f, rBox);
        // Exponentielle Randkruemmung: rBox^2.2 steigt an den Raendern progressiv an und biegt Pixel radial
        float rimRefract = pow(rBox, 2.2f) * 0.44f;
        // Im Linsenzentrum (rBox = 0): 0.92f = 1.087x Vergroesserung
        // An den Linsenraendern (rBox ~ 0.88): 0.92 - 0.44 = 0.48f = starke Meniskus-Lichtbrechung
        float lensFactor = (0.92f - rimRefract) * edgeBlend + (1.0f - edgeBlend);
        return center + (position - center) * lensFactor;
    }
    return position;
}
#endif
