import SwiftUI

public enum AudioQualityTier: String, CaseIterable, Identifiable {
    case normal = "normal"
    case high = "high"
    case lossless = "lossless"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .normal: return "Normal (128 kbps AAC)"
        case .high: return "Hoch (256 kbps AAC)"
        case .lossless: return "Lossless HiFi (FLAC)"
        }
    }

    public var subtitle: String {
        switch self {
        case .normal: return "Geringer Datenverbrauch für unterwegs"
        case .high: return "Beste Balance aus Klang und Datenrate"
        case .lossless: return "Unkomprimierte originale Studioqualität"
        }
    }

    public var iconName: String {
        switch self {
        case .normal: return "speaker.wave.1.fill"
        case .high: return "speaker.wave.2.fill"
        case .lossless: return "speaker.wave.3.fill"
        }
    }
}

public struct ProfileSettingsView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    @AppStorage("portmusic_audio_quality") private var selectedAudioQuality: String = AudioQualityTier.high.rawValue
    @State private var cacheSizeDisplay: String = "Berechne..."
    @State private var isClearingCache: Bool = false
    @State private var showCacheClearedBanner: Bool = false

    @State private var pingLatency: Int? = nil
    @State private var isPingingServer: Bool = false
    @State private var isServerReachable: Bool? = nil
    @State private var pingDetail: String = "Prüfe..."

    public init(user: UserProfile, serverURL: String, onLogout: @escaping () -> Void) {
        self.user = user
        self.serverURL = serverURL
        self.onLogout = onLogout
    }

    public var body: some View {
        ZStack {
            // Pitch Black Background (#000000)
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 16)

                    // ── MARKEN-KOPFZEILE ──
                    brandHeaderSection

                    // ── 1. BENUTZERPROFIL-KARTE ──
                    userProfileCard

                    // ── 2. SERVER & VERBINDUNG ──
                    serverStatusCard

                    // ── 3. STREAMING-QUALITÄT ──
                    audioQualityCard

                    // ── 4. SPEICHER & CACHE-MANAGEMENT ──
                    cacheManagementCard

                    // ── 5. ÜBER DIE APP ──
                    aboutAppCard

                    // ── 6. ABMELDEN BUTTON ──
                    logoutSection

                    // Ausreichender Abstand nach unten fuer Minibar + Bottom TabBar
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .onAppear {
            if AudioQualityTier(rawValue: selectedAudioQuality) == nil {
                selectedAudioQuality = AudioQualityTier.high.rawValue
            }
        }
        .task {
            if AudioQualityTier(rawValue: selectedAudioQuality) == nil {
                selectedAudioQuality = AudioQualityTier.high.rawValue
            }
            refreshCacheSize()
            await pingServer()
        }
    }

    // MARK: - Marken-Kopfzeile
    private var brandHeaderSection: some View {
        VStack(spacing: 8) {
            PortLogoView(size: 58)

            Text("Port Music")
                .font(.manosque(size: 40))
                .foregroundColor(PortColors.textPrimary)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

            Text("Profil & Einstellungen")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.65))
                .textCase(.uppercase)
                .tracking(1.4)
        }
    }

    // MARK: - 1. Benutzerprofil-Karte
    private var userProfileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Avatar mit Bild oder Monogramm
                ZStack {
                    Circle()
                        .fill(PortColors.surfaceGlassStrong)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(PortColors.borderGlass, lineWidth: 1.5)
                        )

                    if let avatarURLString = user.avatar,
                       let avatarURL = URL(string: avatarURLString) {
                        PortCachedAsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                        } placeholder: {
                            userInitialsView
                        }
                    } else {
                        userInitialsView
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(user.username)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)
                        .lineLimit(1)

                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.70))
                            .lineLimit(1)
                    }

                    if let role = user.role, !role.isEmpty {
                        HStack(spacing: 6) {
                            Text(role.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )

                            Text("• Online")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(PortColors.successGreen)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private var userInitialsView: some View {
        Text(String(user.username.prefix(1)).uppercased())
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(PortColors.textPrimary)
    }

    // MARK: - 2. Server & Verbindungsstatus
    private var serverStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("SERVER & VERBINDUNG", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Color.white.opacity(0.70))

                Spacer()

                Button(action: {
                    Task { await pingServer() }
                }) {
                    HStack(spacing: 4) {
                        if isPingingServer {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text("Prüfen")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .disabled(isPingingServer)
            }

            Divider().background(PortColors.borderGlass)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(serverURL)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if isPingingServer {
                            HStack(spacing: 5) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.65)
                                Text("Verbindung wird geprüft...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.70))
                            }
                        } else {
                            let statusColor = (isServerReachable == true) ? PortColors.successGreen : (isServerReachable == false ? PortColors.errorRed : Color.white.opacity(0.60))
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                Text(pingDetail)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(statusColor)
                            }

                            if let latency = pingLatency, isServerReachable == true {
                                Text("(\(latency) ms)")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.65))
                            }
                        }
                    }
                }

                Spacer()

                if isPingingServer {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else if isServerReachable == true {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundColor(PortColors.successGreen)
                } else if isServerReachable == false {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundColor(PortColors.errorRed)
                } else {
                    Image(systemName: "shield")
                        .font(.system(size: 22))
                        .foregroundColor(Color.white.opacity(0.40))
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - 3. Streaming-Qualität
    private var audioQualityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("AUDIO-STREAMING QUALITÄT", systemImage: "waveform")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Color.white.opacity(0.70))

            Divider().background(PortColors.borderGlass)

            VStack(spacing: 10) {
                ForEach(AudioQualityTier.allCases) { tier in
                    let isSelected = (selectedAudioQuality == tier.rawValue)

                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            selectedAudioQuality = tier.rawValue
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: tier.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isSelected ? .white : Color.white.opacity(0.50))
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.title)
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.85))

                                Text(tier.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.55))
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.20), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - 4. Speicher & Cache-Management
    private var cacheManagementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("SPEICHER & CACHE", systemImage: "internaldrive.fill")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Color.white.opacity(0.70))

            Divider().background(PortColors.borderGlass)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Belegter Cover- & Audio-Cache")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    Text(cacheSizeDisplay)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(PortColors.textPrimary)
                }

                Spacer()

                Button(action: performClearCache) {
                    HStack(spacing: 6) {
                        if isClearingCache {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text("Cache leeren")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .disabled(isClearingCache)
            }

            if showCacheClearedBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PortColors.successGreen)
                    Text("Cache erfolgreich geleert")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    // MARK: - 5. Über die App
    private var aboutAppCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ÜBER PORT MUSIC", systemImage: "info.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Color.white.opacity(0.70))

            Divider().background(PortColors.borderGlass)

            VStack(spacing: 8) {
                aboutRow(label: "App-Version", value: "v2.0.0 (Octave Edition)")
                aboutRow(label: "Architektur", value: "Native SwiftUI & AVFoundation")
                aboutRow(label: "Design", value: "Dark Glassmorphism Standard")
                aboutRow(label: "Streaming", value: "Online Dynamic Stream Engine")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.60))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - 6. Abmelden Section
    private var logoutSection: some View {
        Button(action: {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            onLogout()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Abmelden")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(PortColors.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PortColors.buttonPrimaryBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.white.opacity(0.12), radius: 8, y: 2)
        }
        .padding(.top, 4)
    }

    // MARK: - Aktionen
    private func refreshCacheSize() {
        let totalBytes = PortImageCache.shared.calculateDiskCacheSize()
        if totalBytes == 0 {
            self.cacheSizeDisplay = "0 KB"
        } else {
            self.cacheSizeDisplay = PortImageCache.shared.formattedDiskCacheSize()
        }
    }

    private func performClearCache() {
        isClearingCache = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        DispatchQueue.global(qos: .userInitiated).async {
            PortImageCache.shared.clearAllCache()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.refreshCacheSize()
                self.isClearingCache = false
                withAnimation {
                    self.showCacheClearedBanner = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        self.showCacheClearedBanner = false
                    }
                }
            }
        }
    }

    private func pingServer() async {
        isPingingServer = true
        let status = await ServerPingService.shared.ping(rawInput: serverURL)
        switch status {
        case .success(_, let latencyMs, let detail):
            self.isServerReachable = true
            self.pingLatency = latencyMs
            self.pingDetail = detail.isEmpty ? "Verbunden" : detail
        case .failure(let reason):
            self.isServerReachable = false
            self.pingLatency = nil
            self.pingDetail = reason.isEmpty ? "Verbindung fehlgeschlagen" : reason
        default:
            self.isServerReachable = nil
            self.pingLatency = nil
            self.pingDetail = "Status unbekannt"
        }
        isPingingServer = false
    }
}
