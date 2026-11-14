#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct SilkUniforms {
    float2 resolution;
    float2 glowPos;
    float2 waveDir;
    float2 noiseOffset;
    float time;
    float waveFreq;
    float duneOffset;
    float padding;
    float3 glowCore;
    float3 glowMid;
    float3 glowDark;
    float3 duneSheen;
    float3 duneMid;
    float3 duneDark;
};

// 2D Simplex Noise (Ashima Arts / Stefan Gustavson)
static inline float3 mod289(float3 x) {
    return x - floor(x * (1.0f / 289.0f)) * 289.0f;
}

static inline float2 mod289(float2 x) {
    return x - floor(x * (1.0f / 289.0f)) * 289.0f;
}

static inline float3 permute(float3 x) {
    return mod289(((x * 34.0f) + 1.0f) * x);
}

static inline float snoise(float2 v) {
    const float4 C = float4(0.211324865405187f, 0.366025403784439f, -0.577350269189626f, 0.024390243902439f);
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f);
    float4 x12 = float4(x0.x, x0.y, x0.x, x0.y) + float4(C.x, C.x, C.z, C.z);
    x12.xy -= i1;
    i = mod289(i);
    float3 p = permute(permute(i.y + float3(0.0f, i1.y, 1.0f)) + i.x + float3(0.0f, i1.x, 1.0f));
    float3 m = max(0.5f - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0f);
    m = m * m;
    m = m * m;
    float3 x = 2.0f * fract(p * C.www) - 1.0f;
    float3 h = abs(x) - 0.5f;
    float3 ox = floor(x + 0.5f);
    float3 a0 = x - ox;
    m *= 1.79284291400159f - 0.85373472095314f * (a0 * a0 + h * h);
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0f * dot(m, g);
}

vertex VertexOut silkVertexShader(uint vertexID [[vertex_id]]) {
    const float2 positions[6] = {
        float2(-1.0f, -1.0f),
        float2( 1.0f, -1.0f),
        float2(-1.0f,  1.0f),
        float2(-1.0f,  1.0f),
        float2( 1.0f, -1.0f),
        float2( 1.0f,  1.0f)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0f, 1.0f);
    out.uv = positions[vertexID] * 0.5f + 0.5f;
    return out;
}

fragment float4 silkFragmentShader(VertexOut in [[stage_in]],
                                  constant SilkUniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;

    float2 p = uv;
    p.x *= aspect;

    // Gentle, slow hypnotic drifting motion
    float t = uniforms.time * 0.14f;

    // Rotated coordinate space based on randomized wave flow angle
    float2 pRot = float2(
        p.x * uniforms.waveDir.x - p.y * uniforms.waveDir.y,
        p.x * uniforms.waveDir.y + p.y * uniforms.waveDir.x
    );

    // Primary spacious silk curves with randomized seed offsets
    float n1 = snoise(pRot * (uniforms.waveFreq * 0.52f) + uniforms.noiseOffset + float2(t * 0.05f, -t * 0.035f));
    float n2 = snoise(pRot * (uniforms.waveFreq * 0.82f) - uniforms.noiseOffset * 0.7f - float2(t * 0.04f, t * 0.025f) + n1 * 0.45f);
    float n3 = snoise(pRot * (uniforms.waveFreq * 1.55f) + uniforms.noiseOffset * 1.3f + float2(-t * 0.03f, t * 0.05f) + n2 * 0.35f);

    // Fine organic silk ripples
    float silkFolds = sin(pRot.y * 3.5f + pRot.x * 2.2f + n2 * 2.4f + t * 0.15f) * 0.5f + 0.5f;

    // Muted deep graphite background (OLED black)
    float3 c_deep_black = float3(0.018f, 0.022f, 0.028f);
    float3 c_slate_dark = float3(0.05f, 0.08f, 0.10f);

    // 1. Radiant Aura Pool
    float2 glowCenter = float2(uniforms.glowPos.x * aspect, uniforms.glowPos.y);
    float glowDist = length(p - glowCenter + float2(n1 * 0.18f, n2 * 0.14f));
    float glowMask = smoothstep(1.20f, 0.08f, glowDist);
    float glowCoreMask = smoothstep(0.55f, 0.02f, glowDist + n3 * 0.08f);

    float3 glowColor = mix(uniforms.glowDark, uniforms.glowMid, glowMask);
    glowColor = mix(glowColor, uniforms.glowCore, glowCoreMask * 0.80f);

    // 2. Silky Dune / Ribbon Waves
    float duneSlope = pRot.y * 1.25f + (pRot.x - uniforms.duneOffset) * 0.45f + n2 * 0.45f + n3 * 0.15f;
    float duneMask = smoothstep(0.25f, 0.85f, duneSlope) * (1.0f - smoothstep(1.15f, 1.85f, duneSlope));

    // Specular light sheen on silk crest
    float crest = smoothstep(0.46f, 0.58f, duneSlope) * (1.0f - smoothstep(0.58f, 0.72f, duneSlope));
    float3 duneColor = mix(uniforms.duneDark, uniforms.duneMid, clamp(duneSlope * 0.8f - 0.1f + n3 * 0.25f, 0.0f, 1.0f));
    duneColor += uniforms.duneSheen * crest * (0.35f + 0.35f * silkFolds);

    // 3. Composition
    float3 finalColor = c_deep_black;
    finalColor = mix(finalColor, c_slate_dark, clamp(n1 * 0.5f + 0.5f, 0.0f, 1.0f) * 0.75f);
    finalColor = mix(finalColor, duneColor, duneMask * 0.92f);
    finalColor = mix(finalColor, glowColor, glowMask * 0.88f);

    // Soft corner vignette to keep edges smooth
    float vig = uv.x * uv.y * (1.0f - uv.x) * (1.0f - uv.y);
    vig = clamp(pow(16.0f * vig, 0.18f), 0.0f, 1.0f);
    finalColor *= (0.42f + 0.58f * vig);

    // Subtle film dither to eliminate any banding
    float dither = (fract(sin(dot(in.position.xy, float2(12.9898f, 78.233f))) * 43758.5453f) - 0.5f) * (1.5f / 255.0f);
    finalColor += dither;

    return float4(finalColor, 1.0f);
}
