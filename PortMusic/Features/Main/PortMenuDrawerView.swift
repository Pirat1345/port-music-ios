import SwiftUI

// MARK: - Port Music Menü Drawer (1:1 Web-App Drawer)
// Exakt wie das mobile Sheet ("Menü") in AppLayout.tsx auf der Webseite:
// - App-Branding (Port Music Logo & Titel)
// - Benutzerprofil-Banner mit Avatar & "Profil ansehen"
// - Menüpunkte: Neuigkeiten, Statistiken, Jam, Einstellungen, Abmelden
// - Offline-Optionen mit Offline-Modus Schalter am unteren Rand
public struct PortMenuDrawerView: View {
    public let user: UserProfile
    public let serverURL: String
    @Binding public var isPresented: Bool
    public let onOpenProfile: () -> Void
    public let onOpenSettings: () -> Void
    public let onLogout: () -> Void

    @AppStorage("portmusic_offline_mode") private var isOffline: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var showNewsSheet: Bool = false
    @State private var showStatsSheet: Bool = false
    @State private var showJamSheet: Bool = false
    @State private var showLogoutConfirm: Bool = false

    public init(
        user: UserProfile,
        serverURL: String,
        isPresented: Binding<Bool>,
        onOpenProfile: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onLogout: @escaping () -> Void
    ) {
        self.user = user
        self.serverURL = serverURL
        self._isPresented = isPresented
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
            let drawerWidth = min(320, geo.size.width * 0.82)
            let safeTop = max(geo.safeAreaInsets.top, deviceSafeTop)
            let safeBottom = max(geo.safeAreaInsets.bottom, 16)

            ZStack(alignment: .leading) {
                // 1. Abgedunkelter Hintergrund (Backdrop)
                Color.black.opacity(0.60)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeDrawer()
                    }

                // 2. Menü-Seitenleiste (Drawer Container von links)
                VStack(alignment: .leading, spacing: 0) {
                    // Safe-Area Abstand oben
                    Spacer().frame(height: safeTop + 12)

                    // Kopfbereich: Port Music Branding & Schließen-Button
                    headerBrandingSection

                    // Benutzerprofil-Banner (Avatar + Name + "Profil ansehen")
                    profileBannerSection
                        .padding(.top, 24)

                    // Navigations-Menüpunkte (Neuigkeiten, Statistiken, Jam, Einstellungen, Abmelden)
                    menuItemsSection
                        .padding(.top, 20)

                    Spacer(minLength: 16)

                    // Offline-Optionen am unteren Rand
                    offlineSection
                        .padding(.bottom, safeBottom + 12)
                }
                .padding(.horizontal, 20)
                .frame(width: drawerWidth, height: geo.size.height, alignment: .topLeading)
                .background(
                    Color(hex: "#0e0e12")
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1),
                            alignment: .trailing
                        )
                )
                .offset(x: min(0, dragOffset))
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            if val.translation.width < 0 {
                                dragOffset = val.translation.width
                            }
                        }
                        .onEnded { val in
                            if val.translation.width < -80 || val.predictedEndTranslation.width < -120 {
                                closeDrawer()
                            } else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            dragOffset = -340
            isPresented = false
        }
    }

    // MARK: - 1. Branding Header (Logo + "Port Music" + Schließen-Button)
    private var headerBrandingSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#8b5cf6"), Color(hex: "#6366f1")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Port Music")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(-0.3)

            Spacer()

            Button(action: { closeDrawer() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.60))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - 2. Profil-Banner (Avatar + Name + "Profil ansehen")
    private var profileBannerSection: some View {
        Button(action: {
            closeDrawer()
            onOpenProfile()
        }) {
            HStack(spacing: 14) {
                PortUserAvatarView(
                    rawAvatar: user.avatar,
                    username: user.username,
                    serverURL: serverURL,
                    size: 46
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.username)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("Profil ansehen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.50))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 3. Menüpunkte
    private var menuItemsSection: some View {
        VStack(spacing: 4) {
            // Neuigkeiten
            menuRowButton(
                icon: "bell.fill",
                title: "Neuigkeiten",
                badge: nil
            ) {
                showNewsSheet = true
            }

            // Statistiken
            menuRowButton(
                icon: "chart.bar.fill",
                title: "Statistiken",
                badge: nil
            ) {
                showStatsSheet = true
            }

            // Jam
            menuRowButton(
                icon: "antenna.radiowaves.left.and.right",
                title: "Jam",
                badge: nil
            ) {
                showJamSheet = true
            }

            // Einstellungen
            menuRowButton(
                icon: "gearshape.fill",
                title: "Einstellungen",
                badge: nil
            ) {
                closeDrawer()
                onOpenSettings()
            }

            // Trennlinie vor Abmelden
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 6)

            // Abmelden
            Button(action: {
                showLogoutConfirm = true
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.85))
                        .frame(width: 24)

                    Text("Abmelden")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.85))

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func menuRowButton(
        icon: String,
        title: String,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.70))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.001))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 4. Offline-Optionen (Unten)
    private var offlineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            Text("OFFLINE-OPTIONEN")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.white.opacity(0.40))
                .tracking(0.6)

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
                    .tint(Color.purple)
            }
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
                            statsTile(title: "Favoriten", value: "\(FavoritesManager.shared.favoriteTrackIds.count) Titel", icon: "heart.fill")
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
