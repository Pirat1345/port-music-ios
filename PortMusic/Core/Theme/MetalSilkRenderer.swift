import Foundation
import Metal
import MetalKit
import UIKit

public struct SilkUniforms {
    public var resolution: SIMD2<Float>
    public var glowPos: SIMD2<Float>
    public var waveDir: SIMD2<Float>
    public var noiseOffset: SIMD2<Float>
    public var time: Float
    public var waveFreq: Float
    public var duneOffset: Float
    public var padding: Float = 0.0
    public var glowCore: SIMD3<Float>
    public var glowMid: SIMD3<Float>
    public var glowDark: SIMD3<Float>
    public var duneSheen: SIMD3<Float>
    public var duneMid: SIMD3<Float>
    public var duneDark: SIMD3<Float>

    public init(
        resolution: SIMD2<Float> = .zero,
        glowPos: SIMD2<Float> = SIMD2<Float>(0.85, 0.80),
        waveDir: SIMD2<Float> = SIMD2<Float>(1.0, 0.0),
        noiseOffset: SIMD2<Float> = .zero,
        time: Float = 0.0,
        waveFreq: Float = 1.0,
        duneOffset: Float = 0.0,
        glowCore: SIMD3<Float> = SIMD3<Float>(0.22, 0.92, 0.98),
        glowMid: SIMD3<Float> = SIMD3<Float>(0.04, 0.52, 0.62),
        glowDark: SIMD3<Float> = SIMD3<Float>(0.02, 0.22, 0.28),
        duneSheen: SIMD3<Float> = SIMD3<Float>(0.92, 0.78, 0.60),
        duneMid: SIMD3<Float> = SIMD3<Float>(0.76, 0.62, 0.46),
        duneDark: SIMD3<Float> = SIMD3<Float>(0.35, 0.26, 0.18)
    ) {
        self.resolution = resolution
        self.glowPos = glowPos
        self.waveDir = waveDir
        self.noiseOffset = noiseOffset
        self.time = time
        self.waveFreq = waveFreq
        self.duneOffset = duneOffset
        self.padding = 0.0
        self.glowCore = glowCore
        self.glowMid = glowMid
        self.glowDark = glowDark
        self.duneSheen = duneSheen
        self.duneMid = duneMid
        self.duneDark = duneDark
    }
}

public struct SilkPalette {
    public let name: String
    public let glowCore: SIMD3<Float>
    public let glowMid: SIMD3<Float>
    public let glowDark: SIMD3<Float>
    public let duneSheen: SIMD3<Float>
    public let duneMid: SIMD3<Float>
    public let duneDark: SIMD3<Float>

    public init(
        name: String,
        glowCore: SIMD3<Float>,
        glowMid: SIMD3<Float>,
        glowDark: SIMD3<Float>,
        duneSheen: SIMD3<Float>,
        duneMid: SIMD3<Float>,
        duneDark: SIMD3<Float>
    ) {
        self.name = name
        self.glowCore = glowCore
        self.glowMid = glowMid
        self.glowDark = glowDark
        self.duneSheen = duneSheen
        self.duneMid = duneMid
        self.duneDark = duneDark
    }
}

public final class MetalSilkRenderer: NSObject, MTKViewDelegate {
    public static let palettes: [SilkPalette] = [
        // 0: Cyan Aurora & Silky Bronze
        SilkPalette(
            name: "Cyan Aurora & Silky Bronze",
            glowCore: SIMD3<Float>(0.22, 0.92, 0.98),
            glowMid: SIMD3<Float>(0.04, 0.52, 0.62),
            glowDark: SIMD3<Float>(0.02, 0.22, 0.28),
            duneSheen: SIMD3<Float>(0.92, 0.78, 0.60),
            duneMid: SIMD3<Float>(0.76, 0.62, 0.46),
            duneDark: SIMD3<Float>(0.35, 0.26, 0.18)
        ),
        // 1: Ultraviolet Purple & Emerald Silk
        SilkPalette(
            name: "Ultraviolet Purple & Emerald Silk",
            glowCore: SIMD3<Float>(0.75, 0.38, 0.98),
            glowMid: SIMD3<Float>(0.45, 0.16, 0.75),
            glowDark: SIMD3<Float>(0.20, 0.05, 0.36),
            duneSheen: SIMD3<Float>(0.48, 0.96, 0.70),
            duneMid: SIMD3<Float>(0.22, 0.72, 0.48),
            duneDark: SIMD3<Float>(0.08, 0.35, 0.20)
        ),
        // 2: Sunset Coral & Deep Oceanic Cobalt
        SilkPalette(
            name: "Sunset Coral & Deep Oceanic Cobalt",
            glowCore: SIMD3<Float>(0.98, 0.45, 0.35),
            glowMid: SIMD3<Float>(0.78, 0.24, 0.26),
            glowDark: SIMD3<Float>(0.36, 0.08, 0.14),
            duneSheen: SIMD3<Float>(0.55, 0.78, 0.98),
            duneMid: SIMD3<Float>(0.25, 0.48, 0.85),
            duneDark: SIMD3<Float>(0.10, 0.22, 0.45)
        ),
        // 3: Cosmic Magenta & Royal Indigo
        SilkPalette(
            name: "Cosmic Magenta & Royal Indigo",
            glowCore: SIMD3<Float>(0.98, 0.28, 0.75),
            glowMid: SIMD3<Float>(0.68, 0.12, 0.52),
            glowDark: SIMD3<Float>(0.30, 0.04, 0.25),
            duneSheen: SIMD3<Float>(0.65, 0.58, 0.98),
            duneMid: SIMD3<Float>(0.42, 0.32, 0.80),
            duneDark: SIMD3<Float>(0.16, 0.10, 0.38)
        ),
        // 4: Nordic Teal & Radiant Honey Gold
        SilkPalette(
            name: "Nordic Teal & Radiant Honey Gold",
            glowCore: SIMD3<Float>(0.20, 0.90, 0.85),
            glowMid: SIMD3<Float>(0.06, 0.54, 0.52),
            glowDark: SIMD3<Float>(0.02, 0.24, 0.24),
            duneSheen: SIMD3<Float>(0.98, 0.84, 0.38),
            duneMid: SIMD3<Float>(0.85, 0.64, 0.20),
            duneDark: SIMD3<Float>(0.40, 0.26, 0.08)
        ),
        // 5: Mint Frost & Midnight Sapphire
        SilkPalette(
            name: "Mint Frost & Midnight Sapphire",
            glowCore: SIMD3<Float>(0.32, 0.98, 0.80),
            glowMid: SIMD3<Float>(0.10, 0.65, 0.52),
            glowDark: SIMD3<Float>(0.04, 0.28, 0.22),
            duneSheen: SIMD3<Float>(0.55, 0.78, 0.98),
            duneMid: SIMD3<Float>(0.28, 0.48, 0.88),
            duneDark: SIMD3<Float>(0.10, 0.18, 0.42)
        ),
        // 6: Crimson Flare & Ethereal Ice Cyan
        SilkPalette(
            name: "Crimson Flare & Ethereal Ice Cyan",
            glowCore: SIMD3<Float>(0.98, 0.28, 0.32),
            glowMid: SIMD3<Float>(0.72, 0.14, 0.18),
            glowDark: SIMD3<Float>(0.34, 0.05, 0.08),
            duneSheen: SIMD3<Float>(0.62, 0.90, 0.98),
            duneMid: SIMD3<Float>(0.28, 0.64, 0.82),
            duneDark: SIMD3<Float>(0.10, 0.28, 0.38)
        )
    ]

    public static let glowPositions: [SIMD2<Float>] = [
        SIMD2<Float>(0.85, 0.80), // Top Right
        SIMD2<Float>(0.15, 0.80), // Top Left
        SIMD2<Float>(0.85, 0.25), // Bottom Right
        SIMD2<Float>(0.15, 0.25), // Bottom Left
        SIMD2<Float>(0.50, 0.85), // Top Center
        SIMD2<Float>(0.50, 0.20)  // Bottom Center
    ]

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?

    private var uniforms = SilkUniforms()
    private let startTime: CFTimeInterval
    private var isFirstFrameRendered: Bool = false

    public init?(device: MTLDevice, pixelFormat: MTLPixelFormat = .bgra8Unorm) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue
        self.startTime = CACurrentMediaTime()
        super.init()

        setupConfiguration()
        buildPipelineState(pixelFormat: pixelFormat)
    }

    private func setupConfiguration() {
        let palette = Self.palettes.randomElement() ?? Self.palettes[0]
        let glowPos = Self.glowPositions.randomElement() ?? Self.glowPositions[0]

        let angle = Float.random(in: 0 ..< (2.0 * .pi))
        let waveDir = SIMD2<Float>(cos(angle), sin(angle))
        let waveFreq = 0.85 + Float.random(in: 0 ... 0.5)
        let duneOffset = Float.random(in: -0.4 ... 0.4)
        let noiseOffset = SIMD2<Float>(
            Float.random(in: -15.0 ... 15.0),
            Float.random(in: -15.0 ... 15.0)
        )

        uniforms.glowPos = glowPos
        uniforms.waveDir = waveDir
        uniforms.waveFreq = waveFreq
        uniforms.duneOffset = duneOffset
        uniforms.noiseOffset = noiseOffset

        uniforms.glowCore = palette.glowCore
        uniforms.glowMid = palette.glowMid
        uniforms.glowDark = palette.glowDark
        uniforms.duneSheen = palette.duneSheen
        uniforms.duneMid = palette.duneMid
        uniforms.duneDark = palette.duneDark
    }

    private func buildPipelineState(pixelFormat: MTLPixelFormat) {
        let library: MTLLibrary
        if let defaultLib = device.makeDefaultLibrary() {
            library = defaultLib
        } else if let bundleLib = try? device.makeDefaultLibrary(bundle: Bundle.main) {
            library = bundleLib
        } else if let sourceLib = try? device.makeLibrary(source: Self.shaderSource, options: nil) {
            library = sourceLib
        } else {
            return
        }

        guard let vertexFunc = library.makeFunction(name: "silkVertexShader"),
              let fragmentFunc = library.makeFunction(name: "silkFragmentShader") else {
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "FluentSilkPipeline"
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            self.pipelineState = nil
        }
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    public func draw(in view: MTKView) {
        guard let pipelineState = pipelineState,
              let drawable = view.currentDrawable,
              let renderPassDesc = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let drawableSize = view.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0 else {
            return
        }

        uniforms.resolution = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))

        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        if reduceMotion {
            uniforms.time = 1.0
        } else {
            uniforms.time = Float(CACurrentMediaTime() - startTime)
        }

        renderPassDesc.colorAttachments[0].loadAction = .clear
        renderPassDesc.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.018,
            green: 0.022,
            blue: 0.028,
            alpha: 1.0
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setCullMode(.none)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SilkUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        if reduceMotion && !isFirstFrameRendered {
            isFirstFrameRendered = true
            DispatchQueue.main.async {
                view.isPaused = true
            }
        }
    }

    private static let shaderSource = """
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

        float t = uniforms.time * 0.14f;

        float2 pRot = float2(
            p.x * uniforms.waveDir.x - p.y * uniforms.waveDir.y,
            p.x * uniforms.waveDir.y + p.y * uniforms.waveDir.x
        );

        float n1 = snoise(pRot * (uniforms.waveFreq * 0.52f) + uniforms.noiseOffset + float2(t * 0.05f, -t * 0.035f));
        float n2 = snoise(pRot * (uniforms.waveFreq * 0.82f) - uniforms.noiseOffset * 0.7f - float2(t * 0.04f, t * 0.025f) + n1 * 0.45f);
        float n3 = snoise(pRot * (uniforms.waveFreq * 1.55f) + uniforms.noiseOffset * 1.3f + float2(-t * 0.03f, t * 0.05f) + n2 * 0.35f);

        float silkFolds = sin(pRot.y * 3.5f + pRot.x * 2.2f + n2 * 2.4f + t * 0.15f) * 0.5f + 0.5f;

        float3 c_deep_black = float3(0.018f, 0.022f, 0.028f);
        float3 c_slate_dark = float3(0.05f, 0.08f, 0.10f);

        float2 glowCenter = float2(uniforms.glowPos.x * aspect, uniforms.glowPos.y);
        float glowDist = length(p - glowCenter + float2(n1 * 0.18f, n2 * 0.14f));
        float glowMask = smoothstep(1.20f, 0.08f, glowDist);
        float glowCoreMask = smoothstep(0.55f, 0.02f, glowDist + n3 * 0.08f);

        float3 glowColor = mix(uniforms.glowDark, uniforms.glowMid, glowMask);
        glowColor = mix(glowColor, uniforms.glowCore, glowCoreMask * 0.80f);

        float duneSlope = pRot.y * 1.25f + (pRot.x - uniforms.duneOffset) * 0.45f + n2 * 0.45f + n3 * 0.15f;
        float duneMask = smoothstep(0.25f, 0.85f, duneSlope) * (1.0f - smoothstep(1.15f, 1.85f, duneSlope));

        float crest = smoothstep(0.46f, 0.58f, duneSlope) * (1.0f - smoothstep(0.58f, 0.72f, duneSlope));
        float3 duneColor = mix(uniforms.duneDark, uniforms.duneMid, clamp(duneSlope * 0.8f - 0.1f + n3 * 0.25f, 0.0f, 1.0f));
        duneColor += uniforms.duneSheen * crest * (0.35f + 0.35f * silkFolds);

        float3 finalColor = c_deep_black;
        finalColor = mix(finalColor, c_slate_dark, clamp(n1 * 0.5f + 0.5f, 0.0f, 1.0f) * 0.75f);
        finalColor = mix(finalColor, duneColor, duneMask * 0.92f);
        finalColor = mix(finalColor, glowColor, glowMask * 0.88f);

        float vig = uv.x * uv.y * (1.0f - uv.x) * (1.0f - uv.y);
        vig = clamp(pow(16.0f * vig, 0.18f), 0.0f, 1.0f);
        finalColor *= (0.42f + 0.58f * vig);

        float dither = (fract(sin(dot(in.position.xy, float2(12.9898f, 78.233f))) * 43758.5453f) - 0.5f) * (1.5f / 255.0f);
        finalColor += dither;

        return float4(finalColor, 1.0f);
    }
    """
}
