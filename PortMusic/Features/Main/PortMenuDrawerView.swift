import SwiftUI

// MARK: - Port Music Menü Drawer (1:1 Web-App Drawer)
// Exakt wie das mobile Sheet ("Menü") in AppLayout.tsx auf der Webseite:
// - App-Branding (Port Music Logo & Titel) ohne Schließen-Button
// - Benutzerprofil-Banner mit Avatar & "Profil ansehen" ohne Kastenrahmen
// - Menüpunkte: Neuigkeiten, Statistiken, Jam, Einstellungen, Abmelden (ohne Trennstrich)
// - Offline-Optionen mit Offline-Modus Schalter am unteren Rand
public struct PortMenuDrawerView: View {
    public let user: UserProfile
    public let serverURL: String
    @Binding public var isPresented: Bool
    public var externalDragOffset: CGFloat = 0
    public var isExternalDragging: Bool = false
    public let onNavigateHome: (() -> Void)?
    public let onOpenProfile: () -> Void
    public let onOpenSettings: () -> Void
    public let onLogout: () -> Void

    @AppStorage("portmusic_offline_mode") private var isOffline: Bool = false
    @ObservedObject private var favorites = FavoritesManager.shared
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var hasFiredBreakoutHaptic: Bool = false
    @State private var unreadCount: Int = 0
    @State private var isJamActive: Bool = false
    @State private var showNewsSheet: Bool = false
    @State private var showStatsSheet: Bool = false
    @State private var showJamSheet: Bool = false
    @State private var showLogoutConfirm: Bool = false

    public init(
        user: UserProfile,
        serverURL: String,
        isPresented: Binding<Bool>,
        externalDragOffset: CGFloat = 0,
        isExternalDragging: Bool = false,
        onNavigateHome: (() -> Void)? = nil,
        onOpenProfile: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onLogout: @escaping () -> Void
    ) {
        self.user = user
        self.serverURL = serverURL
        self._isPresented = isPresented
        self.externalDragOffset = externalDragOffset
        self.isExternalDragging = isExternalDragging
        self.onNavigateHome = onNavigateHome
        self.onOpenProfile = onOpenProfile
        self.onOpenSettings = onOpenSettings
        self.onLogout = onLogout
    }

    private var deviceSafeTop: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            let top = window.safeAreaInsets.top
            if top > 0 { return top }
        }
        let isPad = (UIDevice.current.userInterfaceIdiom == .pad)
        return isPad ? 24 : 50
    }

    public var body: some View {
        GeometryReader { geo in
            let drawerWidth: CGFloat = min(280, geo.size.width * 0.78)
            let safeTop = max(geo.safeAreaInsets.top, deviceSafeTop)
            let safeBottom = max(geo.safeAreaInsets.bottom, 16)

            // Berechne die absolute Position des Drawers
            let currentOffset: CGFloat = isPresented
                ? (isDragging ? min(0, dragTranslation) : 0)
                : (isDragging ? min(0, -drawerWidth + dragTranslation) : -drawerWidth)

            let progress: Double = max(0, min(1.0, Double((drawerWidth + currentOffset) / drawerWidth)))
            let backdropOpacity: Double = progress * 0.60

            ZStack(alignment: .leading) {
                // 1. Abgedunkelter Hintergrund (Backdrop)
                Color.black.opacity(backdropOpacity)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .allowsHitTesting(isPresented || isDragging)
                    .onTapGesture {
                        closeDrawer()
                    }

                // 2. Menü-Seitenleiste (Drawer Container von links)
                VStack(alignment: .leading, spacing: 0) {
                    // Safe-Area Abstand oben
                    Spacer().frame(height: safeTop + 24)

                    // Kopfbereich: Port Music Branding (Logo + Titel)
                    headerBrandingSection

                    // Benutzerprofil-Banner (Avatar + Name + "Profil ansehen")
                    profileBannerSection
                        .padding(.top, 32)

                    // Navigations-Menüpunkte (Neuigkeiten, Statistiken, Jam, Einstellungen, Abmelden)
                    menuItemsSection
                        .padding(.top, 24)

                    Spacer(minLength: 16)

                    // Offline-Optionen am unteren Rand
                    offlineSection
                        .padding(.bottom, safeBottom + 20)
                }
                .padding(.horizontal, 20)
                .frame(width: drawerWidth, height: geo.size.height, alignment: .topLeading)
                .background(
                    Color(hex: "#0b0b0e")
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1),
                            alignment: .trailing
                        )
                )
                .offset(x: currentOffset)
                .allowsHitTesting(isPresented || isDragging)
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            guard isPresented else { return }
                            if val.translation.width < 0 {
                                isDragging = true
                                dragTranslation = val.translation.width
                            }
                        }
                        .onEnded { val in
                            guard isPresented, isDragging else { return }
                            let dx = val.translation.width
                            let velocity = val.predictedEndTranslation.width - val.translation.width
                            isDragging = false
                            if dx < -65 || velocity < -80 {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                    isPresented = false
                                    dragTranslation = 0
                                }
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                                    isPresented = true
                                    dragTranslation = 0
                                }
                            }
                        }
                )

                // 3. Rand-Gesten-Sensor (AirPods-Haptik: Erst schwer/magnetisch, dann freier Sprung)
                if !isPresented {
                    Color.clear
                        .frame(width: 28)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                                .onChanged { val in
                                    let dx = val.translation.width
                                    guard dx > 0 else { return }
                                    isDragging = true

                                    let breakoutThreshold: CGFloat = 45.0
                                    let effectiveOffset: CGFloat
                                    if dx < breakoutThreshold {
                                        // AirPods-Magnetverschluss: Erste 45pt stark gedämpft (starker Anfangswiderstand)
                                        effectiveOffset = -drawerWidth + (dx * 0.45)
                                    } else {
                                        // Magnetische Verriegelung gelöst: Knackiger Haptik-Klick & freies Aufgleiten
                                        if !hasFiredBreakoutHaptic {
                                            hasFiredBreakoutHaptic = true
                                            let generator = UIImpactFeedbackGenerator(style: .rigid)
                                            generator.prepare()
                                            generator.impactOccurred()
                                        }
                                        let baseOffset = -drawerWidth + (breakoutThreshold * 0.45)
                                        let freeDx = dx - breakoutThreshold
                                        effectiveOffset = min(0, baseOffset + (freeDx * 1.18))
                                    }
                                    dragTranslation = effectiveOffset - (-drawerWidth)
                                }
                                .onEnded { val in
                                    guard isDragging else { return }
                                    let dx = val.translation.width
                                    let velocity = val.predictedEndTranslation.width - val.translation.width
                                    let shouldOpen = dx >= 45.0 || velocity > 60

                                    hasFiredBreakoutHaptic = false
                                    isDragging = false

                                    if shouldOpen {
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                                            isPresented = true
                                            dragTranslation = 0
                                        }
                                    } else {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                            isPresented = false
                                            dragTranslation = 0
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                Task {
                    await fetchUnreadCount()
                }
            }
            .sheet(isPresented: $showNewsSheet) {
                newsSheetView
            }
            .sheet(isPresented: $showStatsSheet) {
                statsSheetView
            }
            .sheet(isPresented: $showJamSheet) {
                jamSheetView
            }
            .confirmationDialog(
                "Möchten Sie sich wirklich abmelden?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Abmelden", role: .destructive) {
                    closeDrawer()
                    onLogout()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    private func closeDrawer() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            isPresented = false
            dragTranslation = 0
            isDragging = false
        }
    }

    // MARK: - 1. Branding Header (Logo + "Port Music" wie Link to="/" in AppLayout.tsx)
    private var headerBrandingSection: some View {
        Button(action: {
            closeDrawer()
            onNavigateHome?()
        }) {
            HStack(spacing: 10) {
                PortLogoView(size: 32)

                Text("Port Music")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 2. Profil-Banner (Avatar + Name + "Profil ansehen" wie button in AppLayout.tsx)
    private var profileBannerSection: some View {
        Button(action: {
            closeDrawer()
            onOpenProfile()
        }) {
            HStack(spacing: 12) {
                PortUserAvatarView(
                    rawAvatar: user.avatar,
                    username: user.username,
                    serverURL: serverURL,
                    size: 48
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName ?? user.username)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("Profil ansehen")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 3. Menüpunkte (nav flex-col gap-1 in AppLayout.tsx)
    private var menuItemsSection: some View {
        VStack(spacing: 4) {
            // Neuigkeiten
            let badgeText = unreadCount > 0 ? (unreadCount > 99 ? "99+" : "\(unreadCount)") : nil
            menuRowButton(
                icon: "bell",
                title: "Neuigkeiten",
                badge: badgeText
            ) {
                showNewsSheet = true
            }

            // Statistiken
            menuRowButton(
                icon: "chart.bar.xaxis",
                title: "Statistiken",
                badge: nil
            ) {
                showStatsSheet = true
            }

            // Jam
            menuRowButton(
                icon: "antenna.radiowaves.left.and.right",
                title: "Jam",
                badge: nil,
                isLive: isJamActive
            ) {
                showJamSheet = true
            }

            // Einstellungen
            menuRowButton(
                icon: "gearshape",
                title: "Einstellungen",
                badge: nil
            ) {
                closeDrawer()
                onOpenSettings()
            }

            // Abmelden
            menuRowButton(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Abmelden",
                badge: nil,
                titleColor: Color(hex: "#f87171"),
                iconColor: Color(hex: "#f87171").opacity(0.85)
            ) {
                showLogoutConfirm = true
            }
        }
    }

    private func menuRowButton(
        icon: String,
        title: String,
        badge: String?,
        isLive: Bool = false,
        titleColor: Color = .white,
        iconColor: Color = Color.white.opacity(0.60),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(titleColor)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.red)
                        .clipShape(Capsule())
                }

                if isLive {
                    Circle()
                        .fill(Color(hex: "#8b5cf6"))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.001))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 4. Offline-Optionen (Unten fixiert)
    private var offlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)

            Text("OFFLINE-OPTIONEN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.50))
                .tracking(1.0)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline-Modus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Text(isOffline ? "Status: Offline" : "Status: Online")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.50))
                }

                Spacer()

                Toggle("", isOn: $isOffline)
                    .labelsHidden()
                    .tint(Color(hex: "#8b5cf6"))
            }
        }
    }

    // MARK: - Unread Count Fetching
    private struct NotificationSummary: Decodable {
        let id: String?
        let read: Bool?
    }

    private func fetchUnreadCount() async {
        guard !serverURL.isEmpty, let base = URL(string: serverURL) else { return }
        let url = base.appendingPathComponent("api/notifications")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = SessionManager.shared.currentToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            if let list = try? JSONDecoder().decode([NotificationSummary].self, from: data) {
                let unread = list.filter { !($0.read ?? false) }.count
                await MainActor.run {
                    self.unreadCount = unread
                }
            }
        } catch {
            // Silently ignore network failures
        }
    }

    // MARK: - Modale Sheets für Neuigkeiten, Statistiken & Jam
    private var newsSheetView: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 18) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "#8b5cf6"))
                        .padding(.top, 24)

                    Text("Neuigkeiten")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Keine neuen Benachrichtigungen vorhanden. Ihr System ist auf dem aktuellsten Stand.")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Spacer()
                }
            }
            .navigationTitle("Neuigkeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { showNewsSheet = false }
                }
            }
        }
    }

    private var statsSheetView: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: "#6366f1"))
                            .padding(.top, 20)

                        Text("Statistiken")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        VStack(spacing: 12) {
                            statsTile(title: "Wiedergabe", value: "Aktiv", icon: "play.circle.fill")
                            statsTile(title: "Favoriten", value: "\(favorites.favoritedTrackIds.count) Titel", icon: "heart.fill")
                            statsTile(title: "Server", value: "Verbunden", icon: "network")
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Statistiken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { showStatsSheet = false }
                }
            }
        }
    }

    private func statsTile(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#8b5cf6"))
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.70))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var jamSheetView: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 18) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "#8b5cf6"))
                        .padding(.top, 24)

                    Text("Jam Session")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Hören Sie gemeinsam mit Freunden Musik in Echtzeit. Jam Sessions synchronisieren die Wiedergabe automatisch über den Server.")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Spacer()
                }
            }
            .navigationTitle("Jam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { showJamSheet = false }
                }
            }
        }
    }
}
