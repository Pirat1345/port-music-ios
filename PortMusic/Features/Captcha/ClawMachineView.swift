import SwiftUI

// MARK: - Toy Metadata Definition
public struct ToyItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let accentHex: String

    public var accentColor: Color {
        Color(hex: accentHex)
    }

    public static let catalog: [String: ToyItem] = [
        "duck": ToyItem(id: "duck", name: "Gelbe Ente", accentHex: "#ffd60a"),
        "bear": ToyItem(id: "bear", name: "Teddybär", accentHex: "#c89b7b"),
        "panda": ToyItem(id: "panda", name: "Panda", accentHex: "#e5e5ea"),
        "bunny": ToyItem(id: "bunny", name: "Häschen", accentHex: "#fca5a5"),
        "dino": ToyItem(id: "dino", name: "Dino", accentHex: "#86efac"),
        "penguin": ToyItem(id: "penguin", name: "Pinguin", accentHex: "#93c5fd"),
        "fox": ToyItem(id: "fox", name: "Fuchs", accentHex: "#fdba74"),
        "frog": ToyItem(id: "frog", name: "Frosch", accentHex: "#4ade80"),
        "whale": ToyItem(id: "whale", name: "Wal", accentHex: "#67e8f9"),
        "cat": ToyItem(id: "cat", name: "Katze", accentHex: "#fde047"),
        "puppy": ToyItem(id: "puppy", name: "Hündchen", accentHex: "#f9a8d4"),
        "unicorn": ToyItem(id: "unicorn", name: "Einhorn", accentHex: "#d8b4fe")
    ]

    public static func item(for id: String) -> ToyItem {
        catalog[id] ?? ToyItem(id: id, name: id.capitalized, accentHex: "#ffd60a")
    }
}

// MARK: - Toy in Arcade Pile
private struct PlacedToy: Identifiable {
    let id: Int
    let toyId: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let rotation: Double
    let zIndex: Double
}

// MARK: - Game Phases
private enum ClawPhase {
    case aiming          // User steers claw
    case descending      // Claw moves down
    case grabbing        // Fingers close
    case ascending       // Claw moves back up (with or without toy)
    case delivering      // Claw glides over to chute
    case dropping        // Fingers open over chute
    case success         // Target verified
    case reset           // Missed or wrong toy returning
}

public struct ClawMachineView: View {
    public let targetId: String
    public let onVerify: (String) -> Void
    public let onFail: (() -> Void)?

    // Canvas geometry
    private let machineWidth: CGFloat = 360
    private let machineHeight: CGFloat = 300
    private let railY: CGFloat = 20
    private let idleCableLen: CGFloat = 45
    private let maxCableLen: CGFloat = 195
    private let chuteX: CGFloat = 310

    // Claw physics & position
    @State private var clawX: CGFloat = 140
    @State private var cableLength: CGFloat = 45
    @State private var clawOpen: CGFloat = 1.0 // 1.0 = open, 0.0 = closed
    @State private var cableSway: Double = 0.0
    @State private var phase: ClawPhase = .aiming

    // Caught toy
    @State private var caughtToyIndex: Int? = nil
    @State private var statusMessage: String? = nil
    @State private var isVerified: Bool = false

    // Showcase Toys
    @State private var toys: [PlacedToy] = []

    public init(
        targetId: String,
        onVerify: @escaping (String) -> Void,
        onFail: (() -> Void)? = nil
    ) {
        self.targetId = targetId
        self.onVerify = onVerify
        self.onFail = onFail
    }

    private var targetInfo: ToyItem {
        ToyItem.item(for: targetId)
    }

    public var body: some View {
        GeometryReader { geo in
            let scale = min(max((geo.size.width - 32) / machineWidth, 0.72), 1.0)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header mit Aufgabe & Ziel
                    challengeHeader

                    // Arcade Greifarm-Maschine
                    machineCaseView
                        .frame(width: machineWidth, height: machineHeight)
                        .scaleEffect(scale)
                        .frame(width: machineWidth * scale, height: machineHeight * scale)

                    // Bedienleiste: Pfeile & großer Arcade-Greifen-Button
                    controlsSection
                        .frame(width: machineWidth * scale)

                    // Hinweistext
                    Text("Bewege den Greifarm über dein Ziel und drücke Greifen.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            initializeToys()
        }
    }

    // MARK: - Challenge Header
    private var challengeHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: isVerified ? "checkmark.shield.fill" : "shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isVerified ? PortColors.successGreen : Color.white.opacity(0.85))

                Text(isVerified ? "Erfolgreich verifiziert" : "Sicherheitsprüfung")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
            }

            // Ziel-Badge mit Target-Icon & Name
            if !isVerified {
                HStack(spacing: 8) {
                    Text("Greife:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.70))

                    HStack(spacing: 6) {
                        Image(targetInfo.id)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)

                        Text(targetInfo.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(targetInfo.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(targetInfo.accentColor.opacity(0.4), lineWidth: 1)
                    )
                }
            }

            if let msg = statusMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isVerified ? PortColors.successGreen : Color(hex: "#ff9500"))
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Arcade Machine Case
    private var machineCaseView: some View {
        ZStack(alignment: .topLeading) {
            // Arcade Glaskasten Hintergrund
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#15171e"), Color(hex: "#0c0d11")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1.5)
                )

            // Obere Schiene (Rail)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#4f5563"), Color(hex: "#2c3039")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 6)
                .offset(y: railY)

            // Trolley Laufkatze
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#c5cad6"), Color(hex: "#7a8294")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 28, height: 10)
                .position(x: clawX, y: railY + 3)

            // Abwurfschacht (Chute) auf der rechten Seite
            chuteView
                .position(x: chuteX, y: machineHeight - 44)

            // Spielzeug-Haufen am Boden
            ForEach(toys) { toy in
                let isCarried = (caughtToyIndex == toy.id)
                if !isCarried {
                    toyView(for: toy)
                        .position(x: toy.x, y: toy.y)
                        .zIndex(toy.zIndex)
                }
            }

            // Schatten unter der Klaue
            let shadowAlpha = max(0.05, 0.40 - Double(cableLength / maxCableLen) * 0.25)
            Ellipse()
                .fill(Color.black.opacity(shadowAlpha))
                .frame(width: 38, height: 12)
                .position(x: clawX, y: machineHeight - 16)

            // Der Greifarm (Kabel + Zange)
            clawAssemblyView
                .position(x: clawX, y: railY + cableLength / 2)
                .zIndex(20)

            // Falls ein Spielzeug gegriffen ist: hängt an der Klaue
            if let caughtIdx = caughtToyIndex, let caught = toys.first(where: { $0.id == caughtIdx }) {
                Image(caught.toyId)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: caught.width * 0.85, height: caught.width * 0.85)
                    .rotationEffect(.degrees(cableSway * 1.5))
                    .position(x: clawX, y: railY + cableLength + 36)
                    .zIndex(25)
            }

            // Dezente Glas-Glanzkante
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        // Interaktives Wischen direkt auf dem Glaskasten
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { val in
                    guard phase == .aiming else { return }
                    let targetX = min(max(val.location.x, 40), chuteX - 50)
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.75)) {
                        clawX = targetX
                        cableSway = Double(val.translation.width) * 0.12
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        cableSway = 0.0
                    }
                }
        )
    }

    // MARK: - Chute / Abwurfschacht
    private var chuteView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#101e14"), Color(hex: "#0a120c")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 68, height: 74)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isVerified ? PortColors.successGreen : Color.white.opacity(0.20),
                            lineWidth: isVerified ? 1.5 : 1
                        )
                )

            VStack(spacing: 4) {
                Image(systemName: isVerified ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isVerified ? PortColors.successGreen : Color.white.opacity(0.60))

                Text(isVerified ? "Passt!" : "Abwurf")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isVerified ? PortColors.successGreen : Color.white.opacity(0.60))
            }
        }
    }

    // MARK: - Toy Representation
    private func toyView(for item: PlacedToy) -> some View {
        ZStack {
            // Weicher Bodenschatten
            Ellipse()
                .fill(Color.black.opacity(0.40))
                .frame(width: item.width * 0.80, height: 12)
                .offset(y: item.width * 0.38)

            Image(item.toyId)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: item.width, height: item.width)
                .rotationEffect(.degrees(item.rotation))
        }
    }

    // MARK: - Greifarm Mechanik (Kabel & Zangen)
    private var clawAssemblyView: some View {
        VStack(spacing: 0) {
            // Stahlkabel
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#b8bcc6"), Color(hex: "#6b7280")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 2.5, height: cableLength)

            // Mechanischer Greifkopf
            ZStack {
                // Basis-Kuppel
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#e2e6ea"), Color(hex: "#6b7280")],
                            center: .center,
                            startRadius: 1,
                            endRadius: 10
                        )
                    )
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.4), radius: 2)

                // Linke Zange
                clawProng(isLeft: true)
                    .offset(x: -8 - (clawOpen * 6), y: 12)
                    .rotationEffect(.degrees(clawOpen * -18), anchor: .top)

                // Rechte Zange
                clawProng(isLeft: false)
                    .offset(x: 8 + (clawOpen * 6), y: 12)
                    .rotationEffect(.degrees(clawOpen * 18), anchor: .top)
            }
            .offset(y: -4)
        }
        .rotationEffect(.degrees(cableSway), anchor: .top)
    }

    private func clawProng(isLeft: Bool) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: isLeft ? -10 : 10, y: 24),
                control: CGPoint(x: isLeft ? -14 : 14, y: 12)
            )
            path.addLine(to: CGPoint(x: isLeft ? -4 : 4, y: 26))
        }
        .stroke(
            LinearGradient(
                colors: [Color(hex: "#e2e8f0"), Color(hex: "#64748b")],
                startPoint: .top,
                endPoint: .bottom
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
        .frame(width: 14, height: 26)
    }

    // MARK: - Steuerungspanel
    private var controlsSection: some View {
        HStack(spacing: 20) {
            // Nach links fahren
            Button(action: { moveClaw(delta: -28) }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(PortColors.surfaceGlassStrong)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PortColors.borderGlass, lineWidth: 1))
            }
            .disabled(phase != .aiming)

            // Nach rechts fahren
            Button(action: { moveClaw(delta: 28) }) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(PortColors.surfaceGlassStrong)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PortColors.borderGlass, lineWidth: 1))
            }
            .disabled(phase != .aiming)

            Spacer()

            // Großer roter Arcade-Button: GREIFEN
            Button(action: triggerGrabSequence) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "#ff3b30"))
                        .frame(width: 14, height: 14)
                        .shadow(color: Color(hex: "#ff3b30").opacity(0.8), radius: 4)

                    Text(phase == .aiming ? "GREIFEN" : "AKTIV...")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#282a32"), Color(hex: "#15161b")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(phase == .aiming ? Color(hex: "#ff3b30").opacity(0.6) : PortColors.borderGlass, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2)
            }
            .disabled(phase != .aiming)
        }
        .padding(.top, 4)
    }

    // MARK: - Game Logic & Sequence
    private func moveClaw(delta: CGFloat) {
        guard phase == .aiming else { return }
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            clawX = min(max(clawX + delta, 40), chuteX - 50)
            cableSway = Double(delta > 0 ? 8 : -8)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                cableSway = 0.0
            }
        }
    }

    private func triggerGrabSequence() {
        guard phase == .aiming else { return }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        phase = .descending
        statusMessage = nil

        // 1. Klaue absenken
        withAnimation(.easeInOut(duration: 0.85)) {
            cableLength = maxCableLen
            clawOpen = 1.0
        }

        // 2. Unten angekommen -> Zangen schließen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) {
            // Trefferprüfung
            let caught = findClosestToy(at: clawX)
            caughtToyIndex = caught?.id

            let snap = UIImpactFeedbackGenerator(style: .heavy)
            snap.impactOccurred()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                clawOpen = (caught != nil) ? 0.30 : 0.0
            }

            // 3. Klaue wieder hochziehen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                phase = .ascending
                withAnimation(.easeInOut(duration: 0.80)) {
                    cableLength = idleCableLen + 15
                }

                // 4. Zur Abwurfzone fahren
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                    if let caughtItem = caught {
                        phase = .delivering
                        withAnimation(.easeInOut(duration: 0.90)) {
                            clawX = chuteX
                            cableSway = 5.0
                        }

                        // 5. Über der Abwurfzone öffnen & fallen lassen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                cableSway = 0.0
                                clawOpen = 1.0
                            }

                            if caughtItem.toyId == targetId {
                                // RICHTIGES SPIELZEUG -> GEWONNEN!
                                isVerified = true
                                statusMessage = "Großartig! Zielobjekt gefangen."
                                let notif = UINotificationFeedbackGenerator()
                                notif.notificationOccurred(.success)

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    onVerify(targetId)
                                }
                            } else {
                                // FALSCHES SPIELZEUG
                                let wrongMeta = ToyItem.item(for: caughtItem.toyId)
                                statusMessage = "Das war \(wrongMeta.name)! Versuche \(targetInfo.name) zu fangen."
                                let notif = UINotificationFeedbackGenerator()
                                notif.notificationOccurred(.warning)
                                onFail?()

                                resetGame()
                            }
                        }
                    } else {
                        // Nichts erwischt
                        statusMessage = "Daneben gegriffen. Probiere es nochmal!"
                        resetGame()
                    }
                }
            }
        }
    }

    private func findClosestToy(at xPos: CGFloat) -> PlacedToy? {
        // Toleranzbereich von ±36pt
        let candidates = toys.filter { abs($0.x - xPos) < 36 }
        return candidates.min(by: { abs($0.x - xPos) < abs($1.x - xPos) })
    }

    private func resetGame() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
            withAnimation(.easeInOut(duration: 0.6)) {
                clawX = 140
                cableLength = idleCableLen
                clawOpen = 1.0
                caughtToyIndex = nil
                phase = .aiming
            }
        }
    }

    private func initializeToys() {
        var items: [PlacedToy] = []
        var availableIds = ToyItem.catalog.keys.filter { $0 != targetId }
        availableIds.shuffle()

        // 6 Spielzeuge auf dem Boden platzieren, Zielobjekt immer dabei
        let targetSlotIndex = Int.random(in: 1...4)
        var chosenList: [String] = []

        for i in 0..<6 {
            if i == targetSlotIndex {
                chosenList.append(targetId)
            } else if let next = availableIds.popLast() {
                chosenList.append(next)
            }
        }

        // X-Positionen verteilen von 50 bis 235
        let spacing: CGFloat = 38
        for (idx, toyId) in chosenList.enumerated() {
            let px = 50 + CGFloat(idx) * spacing + CGFloat.random(in: -4...4)
            let py = machineHeight - 34 + CGFloat.random(in: -6...4)
            let pRot = Double.random(in: -12...12)
            let pWidth: CGFloat = 58
            items.append(
                PlacedToy(
                    id: idx,
                    toyId: toyId,
                    x: px,
                    y: py,
                    width: pWidth,
                    rotation: pRot,
                    zIndex: Double(idx)
                )
            )
        }

        self.toys = items
    }
}
