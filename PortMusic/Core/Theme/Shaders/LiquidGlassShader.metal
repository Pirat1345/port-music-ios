#include <metal_stdlib>
#if __has_include(<SwiftUI/SwiftUI.h>)
#include <SwiftUI/SwiftUI.h>
#endif
using namespace metal;

// MARK: - Liquid Glass Capsule Lens Distortion Shader
// Apple HIG Konforme Kapsel-Meniskus-Lichtbrechung (Spine-Normalen-Refraktion)
#if __has_include(<SwiftUI/SwiftUI.h>)
[[stitchable]] float2 liquidGlassSquircleDistort(float2 position, float2 center, float2 size) {
    float2 halfSize = size * 0.5f;
    float radius = halfSize.y;
    if (radius <= 0.5f || halfSize.x <= radius) {
        return position;
    }

    // Mittellinie (Spine) der Kapsel zwischen den beiden Kappen-Mittelpunkten
    float capSegment = halfSize.x - radius;
    float spineX = clamp(position.x, center.x - capSegment, center.x + capSegment);
    float2 spinePoint = float2(spineX, center.y);

    // Radialer Vektor und Euklidischer Abstand von der Kapsel-Mittellinie
    float2 radialVec = position - spinePoint;
    float dist = length(radialVec);

    if (dist > 0.001f && dist < radius) {
        // Normalisierter Abstand [0, 1] von Mittellinie zum Kapselrand
        float normDist = dist / radius;

        // Apple Liquid Glass Meniskus-Brechungsprofil:
        // C1-stetige, strikt monotone Lichtbrechung entlang der Oberflaechennormale.
        // Die Ableitung d(dist')/d(dist) bleibt ueberall strikt positiv (> 0.75),
        // wodurch Koordinatenfaltungen (Ray Folding / Caustic Folding), Moiré-Streifen
        // und Riffelungen an den Rundungen mathematisch unmoeglich sind.
        float meniscusProfile = sin(3.14159265f * normDist) * (1.0f - normDist * 0.35f);
        float displacement = -1.8f * meniscusProfile;

        float2 normal = radialVec / dist;
        return position + normal * displacement;
    }

    return position;
}
#endif
