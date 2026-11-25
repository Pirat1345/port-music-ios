import SwiftUI

// MARK: - Apple Music Style Radio View (Web RadioPage.tsx Parity + Offline Mode)
public struct RadioBrowserView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var curatedData: CuratedRadioResponse? = nil
    @State private var directoryStations: [RadioBrowserStation] = []
    @State private var favorites: [LibraryRadioStation] = []

    @State private var query: String = ""
    @State private var selectedTag: String? = nil
    @State private var selectedCountry: String = ""
    @State private var showFavoritesOnly: Bool = false

    @State private var isLoadingCurated: Bool = true
    @State private var isLoadingDirectory: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var loadingMixId: String? = nil
    @State private var hasMore: Bool = false
    @State private var offlineNoticeMessage: String? = nil
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    private let batchSize = 40

    private let genres: [(tag: String, label: String)] = [
        ("pop", "Pop"),
        ("rock", "Rock"),
        ("jazz", "Jazz"),
        ("classical", "Klassik"),
        ("electronic", "Electronic"),
        ("dance", "Dance"),
        ("lofi", "Lofi"),
        ("hip hop", "Hip-Hop"),
        ("news", "News"),
        ("metal", "Metal"),
        ("reggae", "Reggae"),
        ("80s", "80s")
    ]

    private let countries: [(code: String, label: String)] = [
        ("", "Alle Länder"),
        ("DE", "Deutschland"),
        ("AT", "Österreich"),
        ("CH", "Schweiz"),
        ("GB", "UK"),
        ("US", "USA"),
        ("FR", "Frankreich"),
        ("IT", "Italien"),
        ("ES", "Spanien"),
        ("NL", "Niederlande"),
        ("PL", "Polen"),
        ("TR", "Türkei")
    ]

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    private var isDirectoryActive: Bool {
        showFavoritesOnly
            || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedTag != nil
            || !selectedCountry.isEmpty
    }

    private var favoriteIds: Set<String> {
        Set(favorites.map(\.id))
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if sessionManager.isOfflineMode {
                    offlineBanner
                }

                if let msg = offlineNoticeMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Text(msg)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { offlineNoticeMessage = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.60))
                        }
                    }
                    .padding(11)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                }

                searchAndFiltersSection

                if isDirectoryActive {
                    directorySection
                } else if isLoadingCurated && curatedData == nil {
                    curatedSkeletonSection
                } else if let curated = curatedData {
                    curatedSections(curated)
                } else {
                    emptyFallbackView
                }

                Spacer(minLength: 150)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.black.ignoresSafeArea())
        .refreshable {
            await loadInitialData()
        }
        .task {
            await loadInitialData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task { await loadInitialData() }
        }
    }

    // MARK: - Header & Offline Banner
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Radio")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text("Live-Sender, kuratierte Shows und globale Stationen")
                    .font(.system(size: 13.5))
                    .foregroundColor(Color.white.opacity(0.58))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline-Modus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("Live-Radio erfordert eine Internetverbindung.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.65))
            }
            Spacer()
            Button("Verbinden") {
                Task {
                    _ = await sessionManager.retryConnection()
                    await loadInitialData()
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Search & Filters
    private var searchAndFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.45))

                TextField("Sender suchen — Pop, Jazz, Chill…", text: $query)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onChange(of: query) { _ in
                        showFavoritesOnly = false
                        scheduleDirectoryQuery()
                    }
                    .onSubmit {
                        Task { await loadDirectory(offset: 0) }
                    }

                if isLoadingDirectory {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else if !query.isEmpty {
                    Button(action: {
                        query = ""
                        selectedTag = nil
                        scheduleDirectoryQuery()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(hex: "#18181b"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Favoriten Pill
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showFavoritesOnly.toggle()
                        if showFavoritesOnly {
                            selectedTag = nil
                            query = ""
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                                .font(.system(size: 11.5, weight: .bold))
                            Text("Favoriten (\(favorites.count))")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundColor(showFavoritesOnly ? .black : .white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(showFavoritesOnly ? Color.white : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Länder-Auswahl
                    Menu {
                        ForEach(countries, id: \.code) { item in
                            Button(action: {
                                selectedCountry = item.code
                                showFavoritesOnly = false
                                scheduleDirectoryQuery()
                            }) {
                                HStack {
                                    Text(item.label)
                                    if selectedCountry == item.code {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        let activeCountry = countries.first(where: { $0.code == selectedCountry })?.label ?? "Alle Länder"
                        HStack(spacing: 5) {
                            Image(systemName: "globe")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text(activeCountry)
                                .font(.system(size: 12.5, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(selectedCountry.isEmpty ? Color.white.opacity(0.85) : .black)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(selectedCountry.isEmpty ? Color.white.opacity(0.08) : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }

                    // Genre Pills
                    ForEach(genres, id: \.tag) { g in
                        let isSel = selectedTag == g.tag
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showFavoritesOnly = false
                            if isSel {
                                selectedTag = nil
                            } else {
                                selectedTag = g.tag
                            }
                            scheduleDirectoryQuery()
                        }) {
                            Text(g.label)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(isSel ? .black : Color.white.opacity(0.85))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(isSel ? Color.white : Color.white.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Curated Apple Music Radio View
    @ViewBuilder
    private func curatedSections(_ data: CuratedRadioResponse) -> some View {
        // 1. Top Featured Live Stations Carousel
        if !data.heroes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(data.heroes) { hero in
                        heroCard(hero)
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        // 2. On Air Now (Jetzt auf Sendung)
        if !data.onAirNow.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Jetzt auf Sendung")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 14
                ) {
                    ForEach(data.onAirNow) { station in
                        onAirCard(station)
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        // 3. Stations for You (Sender für dich)
        if !data.stationsForYou.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#fa2d48"))
                        Text("Sender für dich")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Persönliches Radio basierend auf deinen Top-Künstlern")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(data.stationsForYou) { item in
                            stationForYouCard(item)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }

        // 4. Editorial Shelves
        ForEach(data.shelves) { shelf in
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(hex: "#fa2d48"))
                        Text(shelf.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    if !shelf.subtitle.isEmpty {
                        Text(shelf.subtitle)
                            .font(.system(size: 12.5))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(shelf.items) { item in
                            shelfStationCard(item)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }

        // 5. Featured Mixes (Endless Curated Song Mixes)
        if !data.featuredMixes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Empfohlene Mixes")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Endlose Song-Mixes zum direkt Loslegen")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .padding(.horizontal, 20)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 16
                ) {
                    ForEach(data.featuredMixes) { mix in
                        featuredMixCard(mix)
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        // 6. More to Explore
        if !data.explore.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mehr entdecken")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)

                VStack(spacing: 0) {
                    ForEach(Array(data.explore.enumerated()), id: \.element.id) { idx, cat in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showFavoritesOnly = false
                            selectedTag = cat.tag
                            query = ""
                            scheduleDirectoryQuery()
                        }) {
                            HStack {
                                Text(cat.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.35))
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 46)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if idx < data.explore.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(hex: "#161618"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1))
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Curated Card Builders
    private func heroCard(_ hero: RadioHeroStation) -> some View {
        let isThisPlaying = player.currentTrack?.id == "radio_\(hero.id)" && player.isPlaying
        let isOffline = sessionManager.isOfflineMode

        return Button(action: {
            playStation(id: hero.id, name: hero.title, url: hero.streamUrl, cover: hero.cover, genre: hero.subtitle)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    PortCoverImage(
                        coverUrl: hero.cover,
                        serverURL: serverURL,
                        placeholderIcon: "dot.radiowaves.left.and.right"
                    )
                    .frame(width: 268, height: 268)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.45), radius: 10, y: 4)

                    Circle()
                        .fill(Color(hex: "#fa2d48"))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isThisPlaying ? 0 : 1)
                        )
                        .shadow(color: Color.black.opacity(0.40), radius: 6, y: 2)
                        .padding(12)
                }
                .opacity(isOffline ? 0.55 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    if !hero.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(hero.time)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.50))
                            .lineLimit(1)
                    }
                    Text(hero.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(hero.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(2)
                }
                .frame(width: 268, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func onAirCard(_ station: RadioOnAirStation) -> some View {
        let isThisPlaying = player.currentTrack?.id == "radio_\(station.id)" && player.isPlaying
        return Button(action: {
            playStation(id: station.id, name: station.title, url: station.streamUrl, cover: station.cover, genre: station.time)
        }) {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#18181b"))
                        .aspectRatio(136.0 / 88.0, contentMode: .fit)

                    PortCachedAsyncImage(url: resolveCoverURL(station.cover, serverURL: serverURL)) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 20))
                            .foregroundColor(Color.white.opacity(0.30))
                    }

                    if isThisPlaying {
                        Color.black.opacity(0.45)
                        EqualizerBarsView(color: Color(hex: "#fa2d48"))
                    }
                }
                .aspectRatio(136.0 / 88.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isThisPlaying ? Color(hex: "#fa2d48") : Color.white.opacity(0.10), lineWidth: isThisPlaying ? 1.5 : 1))
                .opacity(sessionManager.isOfflineMode ? 0.55 : 1.0)

                Text(station.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isThisPlaying ? Color(hex: "#fa2d48") : .white)
                    .lineLimit(1)

                if !station.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(station.time)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.50))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func stationForYouCard(_ item: RadioShelfItem) -> some View {
        let isThisPlaying = player.currentTrack?.id == "radio_\(item.id)" && player.isPlaying
        return Button(action: {
            playStation(id: item.id, name: item.title, url: item.streamUrl, cover: item.cover, genre: item.subtitle)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    if let collages = item.artistCollages, collages.count >= 3 {
                        ZStack {
                            LinearGradient(
                                colors: [Color(hex: item.radioField ?? "#333333"), Color(hex: "#111111")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            GeometryReader { geo in
                                let w = geo.size.width
                                PortCoverImage(coverUrl: collages[0], serverURL: serverURL, placeholderIcon: "person.fill")
                                    .frame(width: w * 0.58, height: w * 0.58)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                    .position(x: w * 0.37, y: w * 0.34)

                                PortCoverImage(coverUrl: collages[1], serverURL: serverURL, placeholderIcon: "person.fill")
                                    .frame(width: w * 0.30, height: w * 0.30)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                    .position(x: w * 0.45, y: w * 0.80)

                                PortCoverImage(coverUrl: collages[2], serverURL: serverURL, placeholderIcon: "person.fill")
                                    .frame(width: w * 0.34, height: w * 0.34)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                    .position(x: w * 0.76, y: w * 0.63)
                            }
                        }
                        .frame(width: 152, height: 152)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        PortCoverImage(coverUrl: item.cover, serverURL: serverURL, placeholderIcon: "dot.radiowaves.left.and.right")
                            .frame(width: 152, height: 152)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if isThisPlaying {
                        Circle()
                            .fill(Color(hex: "#fa2d48"))
                            .frame(width: 34, height: 34)
                            .overlay(EqualizerBarsView(color: .white))
                            .padding(8)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .opacity(sessionManager.isOfflineMode ? 0.55 : 1.0)

                Text(item.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 152, alignment: .leading)

                Text(item.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.58))
                    .lineLimit(1)
                    .frame(width: 152, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func shelfStationCard(_ item: RadioShelfItem) -> some View {
        let isThisPlaying = player.currentTrack?.id == "radio_\(item.id)" && player.isPlaying
        let isFav = favoriteIds.contains(item.id)

        return VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: {
                    playStation(id: item.id, name: item.title, url: item.streamUrl, cover: item.cover, genre: item.subtitle)
                }) {
                    PortCoverImage(
                        coverUrl: item.cover,
                        serverURL: serverURL,
                        placeholderIcon: "dot.radiowaves.left.and.right"
                    )
                    .frame(width: 152, height: 152)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isThisPlaying ? Color(hex: "#fa2d48") : Color.white.opacity(0.10), lineWidth: isThisPlaying ? 1.5 : 1))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    let libStation = LibraryRadioStation(
                        id: item.id,
                        name: item.title,
                        url: item.streamUrl,
                        favicon: item.cover,
                        tags: item.subtitle.isEmpty ? nil : [item.subtitle]
                    )
                    Task { await toggleFavorite(libStation) }
                }) {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isFav ? Color(hex: "#fa2d48") : .white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)

                Circle()
                    .fill(Color(hex: "#fa2d48"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: isThisPlaying ? 0 : 1)
                    )
                    .padding(8)
                    .allowsHitTesting(false)
            }
            .frame(width: 152, height: 152)
            .opacity(sessionManager.isOfflineMode ? 0.55 : 1.0)

            Text(item.title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 152, alignment: .leading)

            Text(item.subtitle)
                .font(.system(size: 11.5))
                .foregroundColor(Color.white.opacity(0.58))
                .lineLimit(1)
                .frame(width: 152, alignment: .leading)
        }
    }

    private func featuredMixCard(_ mix: RadioFeaturedMix) -> some View {
        let isLoadingMix = loadingMixId == mix.id
        return Button(action: {
            Task { await playFeaturedMix(mix) }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#18181b"))
                        .aspectRatio(1, contentMode: .fit)

                    PortCachedAsyncImage(url: resolveCoverURL(mix.cover, serverURL: serverURL)) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 28))
                            .foregroundColor(Color.white.opacity(0.30))
                    }

                    LinearGradient(
                        colors: [Color.black.opacity(0.60), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )

                    Circle()
                        .fill(Color(hex: "#fa2d48"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Group {
                                if isLoadingMix {
                                    ProgressView().tint(.white).scaleEffect(0.75)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .offset(x: 1)
                                }
                            }
                        )
                        .padding(10)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .opacity(sessionManager.isOfflineMode ? 0.55 : 1.0)

                Text(mix.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(mix.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Directory / Search / Favorites Grid
    private var directorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Button(action: {
                    query = ""
                    selectedTag = nil
                    selectedCountry = ""
                    showFavoritesOnly = false
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Zurück zu Radio")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())

                Text(directoryHeading)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 20)

            let list: [RadioBrowserStation] = showFavoritesOnly
                ? favorites.map {
                    RadioBrowserStation(
                        id: $0.id,
                        name: $0.name,
                        url: $0.url,
                        favicon: $0.favicon,
                        tags: $0.tags,
                        country: $0.country,
                        codec: $0.codec,
                        bitrate: $0.bitrate,
                        votes: nil,
                        hls: nil,
                        description: nil,
                        time: nil,
                        badge: nil
                    )
                }
                : directoryStations

            if isLoadingDirectory && list.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 56)
            } else if list.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: sessionManager.isOfflineMode ? "wifi.slash" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 36))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text(showFavoritesOnly
                         ? "Noch keine Radiosender als Favorit gespeichert"
                         : (sessionManager.isOfflineMode ? "Verzeichnis im Offline-Modus nicht verfügbar" : "Keine Radiosender gefunden"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .padding(.horizontal, 20)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 16
                ) {
                    ForEach(list) { station in
                        directoryStationCard(station)
                    }
                }
                .padding(.horizontal, 20)

                if !showFavoritesOnly && hasMore && !sessionManager.isOfflineMode {
                    Button(action: {
                        Task { await loadDirectory(offset: directoryStations.count) }
                    }) {
                        HStack(spacing: 8) {
                            if isLoadingMore {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            }
                            Text(isLoadingMore ? "Lädt..." : "Weitere Sender laden")
                                .font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var directoryHeading: String {
        if showFavoritesOnly { return "Favoriten" }
        if let tag = selectedTag { return "Kategorie: \(tag.capitalized)" }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { return "Ergebnisse: \(q)" }
        if let c = countries.first(where: { $0.code == selectedCountry }), !selectedCountry.isEmpty {
            return "Sender aus \(c.label)"
        }
        return "Weltweite Sender"
    }

    private func directoryStationCard(_ station: RadioBrowserStation) -> some View {
        let isThisPlaying = player.currentTrack?.id == "radio_\(station.id)" && player.isPlaying
        let isFav = favoriteIds.contains(station.id)
        let cover = resolveDirectoryStationCover(station)
        let sub = station.tags?.prefix(2).joined(separator: " • ") ?? (station.country ?? "Live Stream")

        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: {
                    playStation(id: station.id, name: station.name, url: station.url ?? "", cover: cover, genre: sub)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "#18181b"))
                            .aspectRatio(1, contentMode: .fit)

                        PortCachedAsyncImage(url: resolveCoverURL(cover, serverURL: serverURL)) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 26))
                                .foregroundColor(Color.white.opacity(0.30))
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isThisPlaying ? Color(hex: "#fa2d48") : Color.white.opacity(0.10), lineWidth: isThisPlaying ? 1.5 : 1))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    Task { await toggleFavorite(station.toLibraryStation()) }
                }) {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isFav ? Color(hex: "#fa2d48") : .white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)

                Circle()
                    .fill(Color(hex: "#fa2d48"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: isThisPlaying ? 0 : 1)
                    )
                    .padding(8)
                    .allowsHitTesting(false)
            }
            .opacity(sessionManager.isOfflineMode ? 0.55 : 1.0)

            Text(station.name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(isThisPlaying ? Color(hex: "#fa2d48") : .white)
                .lineLimit(1)

            Text(sub.isEmpty ? "Live Stream" : sub)
                .font(.system(size: 11.5))
                .foregroundColor(Color.white.opacity(0.55))
                .lineLimit(1)
        }
    }

    private var curatedSkeletonSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 268, height: 268)
                    }
                }
                .padding(.horizontal, 20)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 12
            ) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .aspectRatio(136.0 / 88.0, contentMode: .fit)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var emptyFallbackView: some View {
        VStack(spacing: 12) {
            Image(systemName: sessionManager.isOfflineMode ? "wifi.slash" : "dot.radiowaves.left.and.right")
                .font(.system(size: 38))
                .foregroundColor(Color.white.opacity(0.32))
            Text(sessionManager.isOfflineMode
                 ? "Keine zwischengespeicherten Radiosender vorhanden"
                 : "Radiosender konnten nicht geladen werden")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                Task { await loadInitialData() }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
    }

    // MARK: - Actions & Networking
    private func resolveDirectoryStationCover(_ station: RadioBrowserStation) -> String? {
        if let fav = station.favicon,
           fav.hasPrefix("http://") || fav.hasPrefix("https://") || fav.hasPrefix("/") {
            return fav
        }
        let target = station.url ?? ""
        let encodedUrl = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? target
        let encodedName = station.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? station.name
        return "/api/radio/cover?url=\(encodedUrl)&name=\(encodedName)"
    }

    private func playStation(id: String, name: String, url: String, cover: String?, genre: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if sessionManager.isOfflineMode {
            offlineNoticeMessage = "Live-Radio erfordert eine aktive Internetverbindung."
            return
        }
        let trackId = "radio_\(id)"
        if player.currentTrack?.id == trackId {
            player.togglePlayPause()
            return
        }
        let radioTrack = Track(
            id: trackId,
            title: name,
            artist: genre.isEmpty ? "Live Radio" : genre,
            album: "Radio",
            duration: "Radio",
            durationSeconds: 0,
            coverUrl: cover,
            isLive: true,
            isExplicit: false,
            sourceUrl: url
        )
        player.play(track: radioTrack, from: [radioTrack], serverURL: serverURL)
    }

    private func playFeaturedMix(_ mix: RadioFeaturedMix) async {
        guard let deezerRadioId = mix.deezerRadioId else { return }
        if sessionManager.isOfflineMode {
            await MainActor.run {
                offlineNoticeMessage = "Radio-Mixes erfordern eine aktive Internetverbindung."
            }
            return
        }
        await MainActor.run { loadingMixId = mix.id }
        let token = SessionManager.shared.currentToken
        let queue = await MusicService.shared.fetchRadioMixTracks(
            mixId: deezerRadioId,
            mixTitle: mix.title,
            fallbackCover: mix.cover,
            serverURL: serverURL,
            token: token
        )
        await MainActor.run {
            loadingMixId = nil
            if let first = queue.first {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.play(track: first, from: queue, serverURL: serverURL)
            } else {
                offlineNoticeMessage = "Für diesen Mix wurden keine Titel gefunden."
            }
        }
    }

    private func toggleFavorite(_ station: LibraryRadioStation) async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if sessionManager.isOfflineMode {
            await MainActor.run {
                offlineNoticeMessage = "Favoriten können nur online geändert werden."
            }
            return
        }
        let wasFav = favoriteIds.contains(station.id)
        let token = SessionManager.shared.currentToken
        let ok = await MusicService.shared.toggleRadioFavorite(
            station: station,
            isFavorite: wasFav,
            serverURL: serverURL,
            token: token
        )
        if ok {
            let refreshed = await MusicService.shared.fetchRadioFavorites(serverURL: serverURL, token: token)
            await MainActor.run {
                self.favorites = refreshed
            }
        }
    }

    private func loadInitialData() async {
        isLoadingCurated = true
        if let cached = MusicService.shared.cachedCuratedRadio() {
            await MainActor.run { self.curatedData = cached }
        }
        let cachedFavs = MusicService.shared.cachedRadioFavorites()
        if !cachedFavs.isEmpty {
            await MainActor.run { self.favorites = cachedFavs }
        }

        let token = SessionManager.shared.currentToken
        async let curatedTask = MusicService.shared.fetchCuratedRadio(serverURL: serverURL, token: token)
        async let favsTask = MusicService.shared.fetchRadioFavorites(serverURL: serverURL, token: token)

        let (curated, favs) = await (curatedTask, favsTask)
        await MainActor.run {
            if let c = curated { self.curatedData = c }
            self.favorites = favs
            self.isLoadingCurated = false
        }
    }

    private func scheduleDirectoryQuery() {
        searchDebounceTask?.cancel()
        guard isDirectoryActive, !showFavoritesOnly else {
            directoryStations = []
            isLoadingDirectory = false
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            await loadDirectory(offset: 0)
        }
    }

    private func loadDirectory(offset: Int) async {
        guard !showFavoritesOnly else { return }
        if sessionManager.isOfflineMode {
            await MainActor.run {
                self.isLoadingDirectory = false
                self.isLoadingMore = false
            }
            return
        }
        await MainActor.run {
            if offset == 0 {
                self.isLoadingDirectory = true
            } else {
                self.isLoadingMore = true
            }
        }

        let token = SessionManager.shared.currentToken
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetched: [RadioBrowserStation]
        if !q.isEmpty {
            fetched = await MusicService.shared.searchRadioStations(
                query: q,
                country: selectedCountry,
                limit: batchSize,
                offset: offset,
                serverURL: serverURL,
                token: token
            )
        } else if let tag = selectedTag {
            fetched = await MusicService.shared.fetchRadioStationsByTag(
                tag: tag,
                country: selectedCountry,
                limit: batchSize,
                offset: offset,
                serverURL: serverURL,
                token: token
            )
        } else {
            fetched = await MusicService.shared.fetchTopRadioStations(
                country: selectedCountry,
                limit: batchSize,
                offset: offset,
                serverURL: serverURL,
                token: token
            )
        }

        await MainActor.run {
            if offset == 0 {
                self.directoryStations = fetched
            } else {
                let existingIds = Set(self.directoryStations.map(\.id))
                let unique = fetched.filter { !existingIds.contains($0.id) }
                self.directoryStations.append(contentsOf: unique)
            }
            self.hasMore = fetched.count >= batchSize
            self.isLoadingDirectory = false
            self.isLoadingMore = false
        }
    }
}

public struct RadioStationItem: Identifiable {
    public let id: String
    public let name: String
    public let genre: String
    public let streamUrl: String
    public let color: Color
}
