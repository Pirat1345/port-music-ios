#include <metal_stdlib>
using namespace metal;

struct BackdropUniforms {
    float timeScale;
    float spectrumPower;
    float whiteScrimAlpha;
    float blackScrimAlpha;
    float4x4 textureTransform;
};

struct BackdropVertexIn {
    float4 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct BackdropVertexOut {
    float4 position [[position]];
    float2 texCoords;
};

vertex BackdropVertexOut backdrop_identity_vertex(
    BackdropVertexIn in [[stage_in]],
    constant BackdropUniforms &uniforms [[buffer(1)]]
) {
    BackdropVertexOut out;
    out.position = in.position;
    float4 transformedTex = uniforms.textureTransform * float4(in.texCoords, 0.0, 1.0);
    out.texCoords = transformedTex.xy;
    return out;
}

vertex BackdropVertexOut backdrop_pinch_vertex(
    BackdropVertexIn in [[stage_in]],
    constant BackdropUniforms &uniforms [[buffer(1)]]
) {
    BackdropVertexOut out;
    float2 center = float2(0.5, 0.5);
    float2 delta = in.texCoords - center;
    float dist = length(delta);
    float pinch = 1.0 - (sin(uniforms.timeScale * 2.0) * 0.1 * uniforms.spectrumPower);
    out.position = in.position;
    out.texCoords = center + delta * pinch;
    return out;
}

vertex BackdropVertexOut backdrop_rotation_vertex(
    BackdropVertexIn in [[stage_in]],
    constant BackdropUniforms &uniforms [[buffer(1)]]
) {
    BackdropVertexOut out;
    float angle = uniforms.timeScale * 0.15;
    float cosA = cos(angle);
    float sinA = sin(angle);
    float2x2 rot = float2x2(cosA, -sinA, sinA, cosA);
    float2 centered = in.texCoords - float2(0.5, 0.5);
    out.position = in.position;
    out.texCoords = rot * centered + float2(0.5, 0.5);
    return out;
}

fragment float4 backdrop_blended_fragment(
    BackdropVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]],
    constant BackdropUniforms &uniforms [[buffer(1)]]
) {
    float4 color = colorTexture.sample(textureSampler, in.texCoords);
    
    // Dynamic glow and audio spectrum response
    float lum = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb += float3(uniforms.spectrumPower * 0.12);
    
    // Scrim overlay
    color.rgb = mix(color.rgb, float3(1.0), uniforms.whiteScrimAlpha);
    color.rgb = mix(color.rgb, float3(0.0), uniforms.blackScrimAlpha);
    
    return float4(color.rgb, 1.0);
}

fragment float4 backdrop_pinch_fragment(
    BackdropVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]],
    constant BackdropUniforms &uniforms [[buffer(1)]]
) {
    float4 color = colorTexture.sample(textureSampler, in.texCoords);
    color.rgb *= (1.0 + uniforms.spectrumPower * 0.2);
    return color;
}

fragment float4 backdrop_rotation_fragment(
    BackdropVertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]],
    constant BackdropUniforms &uniforms [[buffer(1)]]
) {
    return colorTexture.sample(textureSampler, in.texCoords);
}
