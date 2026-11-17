#include <metal_stdlib>
#if __has_include(<SwiftUI/SwiftUI.h>)
#include <SwiftUI/SwiftUI.h>
#endif
using namespace metal;

// MARK: - Liquid Glass Capsule Lens Distortion Shader
// Exakte Kapsel-SDF (Signed Distance Field) mit kontinuierlicher Meniskus-Lichtbrechung (Apple HIG)
#if __has_include(<SwiftUI/SwiftUI.h>)
[[stitchable]] float2 liquidGlassSquircleDistort(float2 position, float2 center, float2 size) {
    float2 halfSize = size * 0.5f;
    float radius = halfSize.y;
    if (radius <= 0.5f || halfSize.x <= radius) {
        return position;
    }

    // Gerades Segment in der Kapselmitte (zwischen linkem und rechtem Halbkreis)
    float capSegment = halfSize.x - radius;
    float2 d = abs(position - center);
    // Euklidischer Abstand zur Kapsel-Mittellinie (Rotationssymmetrie an den Kappen)
    float2 clampedD = float2(max(0.0f, d.x - capSegment), d.y);
    float dist = length(clampedD);

    if (dist < radius) {
        // Normalisierter Abstand [0, 1] von Mittellinie zum Kapselrand
        float normDist = dist / radius;

        // Stetige, weiche Linsenkruemmung ohne Gradientensprung (verhindert Moire und Riffelung):
        // Im Linsenzentrum (normDist = 0): sanfte 1.05x Lupenvergroesserung
        // An den Raendern: Seidenglatter Meniskus-Bogen mit stetiger Ableitung < 1.0
        float edgeSmooth = smoothstep(0.65f, 1.0f, normDist);
        float meniscus = sin(normDist * 3.14159265f) * 0.08f;
        
        // Kontinuierlicher Uebergang von Zentrum (0.952) sanft zu 1.0 am exakten Rand
        float factor = mix(0.952f, 1.0f, edgeSmooth) - (meniscus * (1.0f - edgeSmooth));

        return center + (position - center) * factor;
    }
    return position;
}
#endif
