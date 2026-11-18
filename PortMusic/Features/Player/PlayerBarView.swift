import SwiftUI

// MARK: - Floating Frosted Glass MiniPlayer (Apple Liquid Glass Kapsel mit Gestensteuerung)
public struct PlayerBarView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let isInline: Bool
    public let onOpenFullscreen: () -> Void
    public let onLongPress: (() -> Void)?

    @State private var dragProgress: Double? = nil
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var textOpacity: Double = 1.0
    @State private var hasSwiped: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragDirectionLocked: Bool = false
    @State private var isTransitioning: Bool = false
    @State private var touchStartTime: Date? = nil
    @State private var longPressWorkItem: DispatchWorkItem? = nil
    @State private var didTriggerLongPress: Bool = false

    public init(
        serverURL: String,
        isInline: Bool = false,
        onOpenFullscreen: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.serverURL = serverURL
        self.isInline = isInline
        self.onOpenFullscreen = onOpenFullscreen
        self.onLongPress = onLongPress
    }

    private var progress: Double {
        if let drag = dragProgress {
            return drag
        }
        guard player.duration > 0, !player.currentTime.isNaN && player.currentTime.isFinite else {
            return 0.0
        }
        return max(0.0, min(1.0, player.currentTime / player.duration))
    }

    private var activeProgress: Double {
        progress
    }

    // MARK: - Rubber Band Resistance Helper (1.5 Zeichen / ~14pt Schwelle mit spürbarem Widerstand)
    private func computeDampedDragOffset(_ rawDx: CGFloat) -> CGFloat {
        let absDx = abs(rawDx)
        let threshold: CGFloat = 14.0 // ca. 1.5 Buchstaben
        if absDx <= threshold {
            return rawDx
        }
        let excess = absDx - threshold
        let maxAdditional: CGFloat = 12.0 // Maximal ca. 26pt Gesamtauslenkung
        let dampedExcess = maxAdditional * (1.0 - exp(-excess / 30.0))
        let signedDamped = (threshold + dampedExcess) * (rawDx < 0 ? -1.0 : 1.0)
        return signedDamped
    }

    // MARK: - Dynamische Horizontale Fade-Maske (Nur aktiv beim Verschieben, kein Blur im Ruhezustand!)
    private var dynamicEdgeFadeMask: some View {
        let absOffset = abs(horizontalDragOffset)
        // Nur wenn tatsächlich verschoben wird (absOffset > 0.5), wird an der jeweiligen Seite ausgeblendet
        let leftFade: CGFloat = (horizontalDragOffset < -0.5) ? min(0.09, (absOffset / 14.0) * 0.09) : 0.0
        let rightFade: CGFloat = (horizontalDragOffset > 0.5) ? min(0.09, (absOffset / 14.0) * 0.09) : 0.0

        return LinearGradient(
            stops: [
                .init(color: leftFade > 0.001 ? .clear : .black, location: 0.0),
                .init(color: .black, location: max(0.0001, leftFade)),
                .init(color: .black, location: min(0.9999, 1.0 - rightFade)),
                .init(color: rightFade > 0.001 ? .clear : .black, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var edgeFadeMask: some View {
        dynamicEdgeFadeMask
    }

    public var body: some View {
        if let track = player.currentTrack {
            ZStack(alignment: .bottom) {
                if isInline {
                    inlineContentView(track: track)
                        .transition(AnyTransition.opacity)
                } else {
                    expandedContentView(track: track)
                        .transition(AnyTransition.opacity)
                }
            }
            .frame(height: isInline ? 62 : 48)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.18), location: 0.0),
                                    .init(color: Color.white.opacity(0.04), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
            )
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isInline)
        }
    }

    // MARK: - Swipe & Tap Gesture (Präzise Trennung von Antippen, Wischen und langem Drücken)
    private var swipeAndTapGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { val in
                guard !isTransitioning else { return }
                let dx = val.translation.width
                let dy = val.translation.height
                let distance = hypot(dx, dy)

                // Bei neuem Touch: Startzeit merken und Long-Press-Timer starten
                if touchStartTime == nil {
                    touchStartTime = Date()
                    didTriggerLongPress = false

                    // Timer für langes Drücken (0.38s)
                    let workItem = DispatchWorkItem { [onLongPress] in
                        didTriggerLongPress = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        DispatchQueue.main.async {
                            onLongPress?()
                        }
                    }
                    longPressWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: workItem)
                }

                // Natürliche Fingerbewegung auf kapazitivem Display tolerieren (bis 20 Punkte)
                if distance > 20 {
                    longPressWorkItem?.cancel()
                    longPressWorkItem = nil
                }

                if distance > 14 {
                    hasSwiped = true
                }

                // Richtungssperre: Nach 14 Punkten feststellen, ob der Zug horizontal erfolgt
                if !dragDirectionLocked && distance > 14 {
                    dragDirectionLocked = true
                    isDragging = abs(dx) > abs(dy)
                }

                // Wenn horizontal eingerastet: Verzögerungsfrei ohne Federanimation direkt dem Finger folgen
                if isDragging {
                    let target = computeDampedDragOffset(dx)
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        horizontalDragOffset = target
                    }
                }
            }
            .onEnded { val in
                // Laufenden Timer verwerfen
                longPressWorkItem?.cancel()
                longPressWorkItem = nil

                guard !isTransitioning else {
                    touchStartTime = nil
                    didTriggerLongPress = false
                    return
                }

                let dx = val.translation.width
                let dy = val.translation.height
                let velocityX = val.predictedEndTranslation.width - val.translation.width
                let velocityY = val.predictedEndTranslation.height - val.translation.height
                let distance = hypot(dx, dy)
                let pressDuration = touchStartTime.map { Date().timeIntervalSince($0) } ?? 0

                // Wenn bereits ein Long-Press ausgelöst wurde: Nicht zusätzlich Fullscreen öffnen!
                if didTriggerLongPress {
                    didTriggerLongPress = false
                    touchStartTime = nil
                    hasSwiped = false
                    isDragging = false
                    dragDirectionLocked = false
                    return
                }

                touchStartTime = nil

                // 1. Reiner Tap oder gedrückt gehaltener Finger ohne Wischen
                if !hasSwiped || distance < 15 {
                    if pressDuration < 0.38 {
                        // Kurzer Klick -> Vollbild öffnen
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onOpenFullscreen()
                    } else {
                        // Gedrückt gehalten -> Leisten-Einstellungen öffnen
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onLongPress?()
                    }
                }
                // 2. Wischen nach oben: Vollbild-Player öffnen (wie in Apple Music)
                else if dy < -25 || velocityY < -35 {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                        onOpenFullscreen()
                    }
                }
                // 3. Wischen nach links: Nächster Titel (Cover bleibt fest, alter Name gleitet nach links raus, neuer kommt von rechts)
                else if dx < -16 || velocityX < -40 {
                    isTransitioning = true
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    // Text gleitet in die linke Fade-Maske und blendet aus
                    withAnimation(.easeOut(duration: 0.16)) {
                        horizontalDragOffset = -42
                        textOpacity = 0.0
                    }
                    player.next(serverURL: serverURL)
                    // Neuer Songtext gleitet von rechts aus der Fade-Maske zur Mitte
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        horizontalDragOffset = 42
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            horizontalDragOffset = 0
                            textOpacity = 1.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            isTransitioning = false
                        }
                    }
                }
                // 4. Wischen nach rechts: Vorheriger Titel (Cover bleibt fest, alter Name gleitet nach rechts raus, vorheriger kommt von links)
                else if dx > 16 || velocityX > 40 {
                    isTransitioning = true
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    // Text gleitet in die rechte Fade-Maske und blendet aus
                    withAnimation(.easeOut(duration: 0.16)) {
                        horizontalDragOffset = 42
                        textOpacity = 0.0
                    }
                    player.previous(serverURL: serverURL)
                    // Vorheriger Songtext gleitet von links aus der Fade-Maske zur Mitte
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        horizontalDragOffset = -42
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            horizontalDragOffset = 0
                            textOpacity = 1.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            isTransitioning = false
                        }
                    }
                }
                // 5. Losgelassen ohne Schwelle: Geschmeidig zur Mitte zurückfedern
                else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        horizontalDragOffset = 0
                        textOpacity = 1.0
                    }
                }

                // Zustand zurücksetzen
                hasSwiped = false
                isDragging = false
                dragDirectionLocked = false
            }
    }

    // MARK: - Inline Minibar (Exakt wie in Octave: Sitzt im minimierten Zustand zwischen linkem und rechtem 62pt-Kreis)
    @ViewBuilder
    private func inlineContentView(track: Track) -> some View {
        HStack(spacing: 10) {
            // Antippbarer & Wischbarer Info-Bereich (Cover bleibt fest, nur Text gleitet)
            HStack(spacing: 10) {
                // Mini Cover Artwork (38x38, 8pt Radius) - Bleibt fest an Ort und Stelle
                let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 38, height: 38)
                }
                .shadow(color: Color.black.opacity(0.30), radius: 3, y: 1)

                // Titel - Nur der Text verschiebt sich beim Wischen mit dynamischem Rand-Fade!
                Text(track.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: horizontalDragOffset)
                    .opacity(textOpacity)
                    .mask(dynamicEdgeFadeMask)
                    .animation(nil, value: horizontalDragOffset)
            }
            .contentShape(Rectangle())
            .gesture(swipeAndTapGesture)

            // Play / Pause Button (34x34 runder Glasbutton mit isoliertem Touch-Target)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 34, height: 34)
                .contentShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
    }

    // MARK: - Vollwertige Schwebende Minibar (Im Ruhezustand über der durchgehenden Leiste)
    @ViewBuilder
    private func expandedContentView(track: Track) -> some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 10) {
                // Linker Bereich: Cover + Titel + Interpret (Cover bleibt fest, nur Text gleitet)
                HStack(spacing: 10) {
                    // Cover-Artwork (44x44 Standard) - Bleibt fest an Ort und Stelle
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)

                        let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                        PortCachedAsyncImage(url: resolved) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: {
                            Image(systemName: "music.note")
                                .font(.system(size: 15))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1.5)

                    // Titel und Interpret - Nur dieser Textblock gleitet beim Wischen mit dynamischem Rand-Fade!
                    let displayTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Titel" : track.title
                    let displayArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Interpret" : track.artist

                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayTitle)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(displayArtist)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: horizontalDragOffset)
                    .opacity(textOpacity)
                    .mask(dynamicEdgeFadeMask)
                    .animation(nil, value: horizontalDragOffset)

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
                .gesture(swipeAndTapGesture)

                // Rechter Bereich: Apple Music Transport-Buttons (Play/Pause, Weiter)
                HStack(spacing: 6) {
                    // Play/Pause Button mit isoliertem, zuverlässigem Touch-Target
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        player.togglePlayPause()
                    }) {
                        ZStack {
                            if player.isBuffering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.80)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Nächster Titel (forward.fill) mit isoliertem Touch-Target
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        player.next(serverURL: serverURL)
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.90))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)

            // 2px filigrane Fortschrittslinie direkt am unteren Rand der Kapsel
            timelineScrubberSection
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
        }
    }

    // MARK: - Timeline Scrubber Section
    private var timelineScrubberSection: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ratio = max(0.0, min(1.0, activeProgress))

            ZStack(alignment: .leading) {
                // Hintergrund-Leiste
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 2.5)

                // Aktiver Fortschritt
                Capsule()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: max(0, w * CGFloat(ratio)), height: 2.5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let r = max(0.0, min(1.0, Double(val.location.x / w)))
                        dragProgress = r
                    }
                    .onEnded { val in
                        let r = max(0.0, min(1.0, Double(val.location.x / w)))
                        let target = r * player.duration
                        player.seek(to: target)
                        dragProgress = nil
                    }
            )
        }
        .frame(height: 2.5)
    }
}
