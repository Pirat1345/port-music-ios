import SwiftUI
import CoreGraphics
import Combine

// MARK: - Clump Model
public struct LitterClump: Identifiable {
    public let id: Int
    public var x: CGFloat
    public var y: CGFloat
    public var r: CGFloat
    public let seed: Int
    public var path: Path
    public var cgPath: CGPath
    public var removed: Bool = false
}

// MARK: - LitterCaptchaView
public struct LitterCaptchaView: View {
    public let onVerify: ((_ solution: CaptchaSolution) -> Void)?
    public let onFail: (() -> Void)?
    public let onReset: (() -> Void)?

    // Canvas Constants
    private let boxW = 396
    private let boxH = 220
    private let spotlightRadius: CGFloat = 100.0

    // Pixel colors: Little-endian 0xAABBGGRR
    // Light grain: #efeff2 -> R: 0xef, G: 0xef, B: 0xf2, A: 0xff -> 0xfff2efef
    // Dark grain:  #383940 -> R: 0x38, G: 0x39, B: 0x40, A: 0xff -> 0xff403938
    private let lightPixel: UInt32 = 0xfff2efef
    private let darkPixel: UInt32 = 0xff403938

    // State
    @State private var clumps: [LitterClump] = []
    @State private var baseNoise: [UInt8] = [] // 1 = light, 0 = dark
    @State private var clumpMap: [Int8] = [] // -1 = background, 0..3 = clump index
    @State private var displayImage: UIImage? = nil

    // Touch and Drag State
    @State private var isTouching: Bool = false
    @State private var touchPos: CGPoint = CGPoint(x: -200, y: -200)
    @State private var draggedClumpId: Int? = nil
    @State private var dragCurrentPos: CGPoint = .zero
    @State private var isOverBin: Bool = false

    // Verification & Dialog
    @State private var isVerified: Bool = false
    @State private var showInfo: Bool = false

    // 30 FPS Shimmer Timer
    private let shimmerTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    public init(
        onVerify: ((_ solution: CaptchaSolution) -> Void)? = nil,
        onFail: (() -> Void)? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.onVerify = onVerify
        self.onFail = onFail
        self.onReset = onReset
    }

    private var remainingCount: Int {
        clumps.filter { !$0.removed }.count
    }

    private var collectedCount: Int {
        clumps.count - remainingCount
    }

    private var isDone: Bool {
        !clumps.isEmpty && remainingCount == 0
    }

    public var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - 24
            let scale = min(max(availableWidth / CGFloat(boxW), 0.75), 1.0)

            VStack(spacing: 12) {
                // Header Bar
                headerView

                // Info Accordion if opened
                if showInfo {
                    infoBannerView
                }

                // Main Particle Noise Canvas
                particleCanvasView
                    .frame(width: CGFloat(boxW), height: CGFloat(boxH))
                    .scaleEffect(scale)
                    .frame(width: CGFloat(boxW) * scale, height: CGFloat(boxH) * scale)

                // Zielbereich Receptacle Dropzone
                targetBinView
                    .frame(width: CGFloat(boxW) * scale)

                // Footer Controls: Reload & Verify Button
                footerControlsView
                    .frame(width: CGFloat(boxW) * scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                setupBoard()
            }
            .onReceive(shimmerTimer) { _ in
                renderNoiseFrame()
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Partikel-Muster (Motion-Fokus)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text("Ziehe alle statischen Formen in den Zielbereich")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showInfo.toggle()
                }
            }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Info Banner
    private var infoBannerView: some View {
        Text("Bewege den Finger über das Partikelfeld. Die Formen heben sich durch das Rauschen ab, da sich ihr Muster nicht verändert. Ziehe alle Formen in den Zielbereich.")
            .font(.system(size: 12))
            .foregroundColor(.white)
            .lineSpacing(3)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 16)
    }

    // MARK: - Particle Noise Canvas Area
    private var particleCanvasView: some View {
        ZStack(alignment: .topLeading) {
            // Rendered Noise Buffer Bitmap
            if let img = displayImage {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: CGFloat(boxW), height: CGFloat(boxH))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#efeff2"))
                    .frame(width: CGFloat(boxW), height: CGFloat(boxH))
            }

            // Lifted Dragged Clump Follower
            if let dragId = draggedClumpId,
               let clump = clumps.first(where: { $0.id == dragId }) {
                draggedFollowerView(clump: clump)
            }

            // Glass Border
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    isTouching = true
                    touchPos = val.location

                    if draggedClumpId == nil {
                        // Check if touched inside any clump
                        if let found = clumps.first(where: { c in
                            guard !c.removed else { return false }
                            let center = CGPoint(
                                x: c.x + 50.0 * (c.r / 50.0),
                                y: c.y + 40.0 * (c.r / 50.0)
                            )
                            let dx = val.location.x - center.x
                            let dy = val.location.y - center.y
                            return (dx * dx + dy * dy) <= pow(c.r * 1.35, 2)
                        }) {
                            draggedClumpId = found.id
                            dragCurrentPos = val.location
                            triggerHaptic(style: .medium)
                        }
                    } else {
                        dragCurrentPos = val.location
                        // Check if over bottom area (Zielbereich)
                        isOverBin = (val.location.y >= CGFloat(boxH) - 15)
                    }
                }
                .onEnded { val in
                    isTouching = false
                    touchPos = CGPoint(x: -200, y: -200)

                    if let dragId = draggedClumpId {
                        // Drop in bin check: if released near or below canvas bottom
                        if val.location.y >= CGFloat(boxH) - 30 {
                            if let idx = clumps.firstIndex(where: { $0.id == dragId }) {
                                clumps[idx].removed = true
                                triggerHaptic(style: .medium)
                            }
                        }
                        draggedClumpId = nil
                        isOverBin = false
                    }
                }
        )
    }

    // MARK: - Lifted Follower View
    private func draggedFollowerView(clump: LitterClump) -> some View {
        let width = clump.r * 2.0
        let height = clump.r * 1.6
        // Lifted touch offset: y - 38 so the user's finger does not block the blob
        let targetX = dragCurrentPos.x - width / 2.0
        let targetY = dragCurrentPos.y - height / 2.0 - 38.0

        return ZStack {
            clump.path
                .fill(Color(hex: "#e5e5ea"))
                .overlay(
                    clump.path
                        .stroke(Color(hex: "#34c759"), lineWidth: 2.5)
                )
        }
        .frame(width: 100, height: 80)
        .scaleEffect(clump.r / 40.0)
        .scaleEffect(1.08)
        .shadow(color: Color.black.opacity(0.55), radius: 12, y: 8)
        .position(x: targetX + width / 2.0, y: targetY + height / 2.0)
        .allowsHitTesting(false)
    }

    // MARK: - Target Receptacle (Zielbereich)
    private var targetBinView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isOverBin ? Color(hex: "#34c759") : .white)

            Text("Zielbereich (\(collectedCount)/\(clumps.count))")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isOverBin ? .white : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            isOverBin ?
                Color(hex: "#34c759").opacity(0.18) :
                Color.white.opacity(0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isOverBin ? Color(hex: "#34c759") : Color.white.opacity(0.30),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isOverBin)
    }

    // MARK: - Footer Controls
    private var footerControlsView: some View {
        HStack {
            // Reset Button
            Button(action: {
                setupBoard()
                onReset?()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Neu laden")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Confirm Button
            Button(action: handleVerify) {
                HStack(spacing: 8) {
                    if isVerified {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Verifiziert")
                            .font(.system(size: 14, weight: .bold))
                    } else {
                        Text("Bestätigen")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundColor(isDone ? .black : Color.white.opacity(0.60))
                .padding(.horizontal, 24)
                .padding(.vertical, 11)
                .background(isDone ? Color.white : Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isDone || isVerified)
        }
    }

    // MARK: - Verification Handler
    private func handleVerify() {
        guard isDone else { return }
        isVerified = true
        triggerHapticNotification(type: .success)
        let solution = CaptchaSolution(verified: true, clumpsRemaining: remainingCount)
        onVerify?(solution)
    }

    // MARK: - Board Setup
    private func setupBoard() {
        isVerified = false
        draggedClumpId = nil
        isOverBin = false

        // Generate 4 clumps in 4 non-overlapping quadrants
        let quadrants = [
            (minX: CGFloat(30), maxX: CGFloat(120), minY: CGFloat(20), maxY: CGFloat(65)),   // Top-Left
            (minX: CGFloat(205), maxX: CGFloat(295), minY: CGFloat(20), maxY: CGFloat(65)),  // Top-Right
            (minX: CGFloat(30), maxX: CGFloat(120), minY: CGFloat(110), maxY: CGFloat(155)), // Bottom-Left
            (minX: CGFloat(205), maxX: CGFloat(295), minY: CGFloat(110), maxY: CGFloat(155)) // Bottom-Right
        ].shuffled()

        var generatedClumps: [LitterClump] = []
        for (i, q) in quadrants.enumerated() {
            let seed = Int.random(in: 1000...99999) + i * 37
            let (p, cgp) = makeBlobPath(seed: seed)
            let clump = LitterClump(
                id: i,
                x: CGFloat.random(in: q.minX...q.maxX),
                y: CGFloat.random(in: q.minY...q.maxY),
                r: CGFloat.random(in: 28.0...38.0),
                seed: seed,
                path: p,
                cgPath: cgp,
                removed: false
            )
            generatedClumps.append(clump)
        }
        clumps = generatedClumps

        // Generate Master Base Noise: 48% light, 52% dark
        let total = boxW * boxH
        var noise = [UInt8](repeating: 0, count: total)
        for i in 0..<total {
            noise[i] = (Float.random(in: 0...1) > 0.48) ? 1 : 0
        }
        baseNoise = noise

        // Rasterize Clumps into clumpMap
        var map = [Int8](repeating: -1, count: total)
        for (idx, c) in generatedClumps.enumerated() {
            let scaleX = c.r / 50.0
            let scaleY = (c.r * 0.8) / 40.0
            var transform = CGAffineTransform(translationX: c.x, y: c.y)
                .scaledBy(x: scaleX, y: scaleY)

            if let transformedPath = c.cgPath.copy(using: &transform) {
                let bounds = transformedPath.boundingBox
                let minX = max(0, Int(floor(bounds.minX)))
                let maxX = min(boxW - 1, Int(ceil(bounds.maxX)))
                let minY = max(0, Int(floor(bounds.minY)))
                let maxY = min(boxH - 1, Int(ceil(bounds.maxY)))

                for y in minY...maxY {
                    let yOffset = y * boxW
                    for x in minX...maxX {
                        let pt = CGPoint(x: x, y: y)
                        if transformedPath.contains(pt) {
                            map[yOffset + x] = Int8(idx)
                        }
                    }
                }
            }
        }
        clumpMap = map

        // Render initial frame
        renderNoiseFrame()
    }

    // MARK: - 30 FPS Kinetic Noise Buffer Rendering
    private func renderNoiseFrame() {
        guard !baseNoise.isEmpty && !clumpMap.isEmpty else { return }

        let total = boxW * boxH
        var pixelBuffer = [UInt32](repeating: 0, count: total)

        let mouseX = Int(touchPos.x)
        let mouseY = Int(touchPos.y)
        let spotRadiusSq = Int(spotlightRadius * spotlightRadius)
        let active = isTouching

        for y in 0..<boxH {
            let yOffset = y * boxW
            let dy = y - mouseY
            let dySq = dy * dy

            for x in 0..<boxW {
                let idx = yOffset + x
                let cId = Int(clumpMap[idx])

                let isClumpPixel = (cId >= 0 && cId < clumps.count && !clumps[cId].removed && draggedClumpId != clumps[cId].id)

                if isClumpPixel {
                    // Clump pixels: permanently locked to static base noise
                    pixelBuffer[idx] = (baseNoise[idx] == 1) ? lightPixel : darkPixel
                } else {
                    // Background pixels
                    if active {
                        let dx = x - mouseX
                        let inSpotlight = (dx * dx + dySq < spotRadiusSq)
                        if inSpotlight {
                            // Dynamic shimmering noise
                            pixelBuffer[idx] = (Float.random(in: 0...1) > 0.48) ? lightPixel : darkPixel
                        } else {
                            // Static base noise outside spotlight
                            pixelBuffer[idx] = (baseNoise[idx] == 1) ? lightPixel : darkPixel
                        }
                    } else {
                        // Completely identical to base noise (100% camouflage)
                        pixelBuffer[idx] = (baseNoise[idx] == 1) ? lightPixel : darkPixel
                    }
                }
            }
        }

        // Convert pixel buffer to CGImage
        displayImage = createUIImage(from: pixelBuffer, width: boxW, height: boxH)
    }

    private func createUIImage(from pixels: [UInt32], width: Int, height: Int) -> UIImage? {
        let count = width * height
        let data = pixels.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

        guard let cgImg = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImg)
    }

    // MARK: - Organic Blob Path Construction
    private func makeBlobPath(seed: Int) -> (Path, CGPath) {
        var s = Double(seed + 1)
        func nextRand() -> Double {
            s = Double((Int(s) * 9301 + 49297) % 233280)
            return s / 233280.0
        }

        let points = 8
        var pts: [CGPoint] = []
        for i in 0..<points {
            let a = (Double(i) / Double(points)) * .pi * 2.0
            let rx = 32.0 + nextRand() * 14.0
            let ry = 24.0 + nextRand() * 12.0
            pts.append(CGPoint(x: 50.0 + cos(a) * rx, y: 40.0 + sin(a) * ry))
        }

        var p = Path()
        let mutableCG = CGMutablePath()

        let first = pts[0]
        p.move(to: first)
        mutableCG.move(to: first)

        for i in 0..<points {
            let cur = pts[i]
            let next = pts[(i + 1) % points]
            let mid = CGPoint(x: (cur.x + next.x) / 2.0, y: (cur.y + next.y) / 2.0)
            p.addQuadCurve(to: mid, control: cur)
            mutableCG.addQuadCurve(to: mid, control: cur)
        }
        p.closeSubpath()
        mutableCG.closeSubpath()

        return (p, mutableCG)
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func triggerHapticNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
