import SwiftUI

// MARK: - Saved Radio Stations in Library (Strictly Isolated Live Radio)
public struct LibraryRadioView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var stations: [LibraryRadioStation] = []
    @State private var isLoading: Bool = true
    @State private var searchQuery: String = ""

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    private var filteredStations: [LibraryRadioStation] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return stations }
        return stations.filter {
            $0.name.lowercased().contains(q)
            || ($0.country?.lowercased().contains(q) ?? false)
            || ($0.tags?.contains(where: { $0.lowercased().contains(q) }) ?? false)
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Gespeicherte Sender")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                        Text("\(stations.count) Sender in deiner Mediathek")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.42))
                    }

                    Spacer()

                    NavigationLink(destination: RadioBrowserView(serverURL: serverURL)) {
                        HStack(spacing: 6) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Entdecken")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.40))
                    TextField("Radiosender durchsuchen...", text: $searchQuery)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.40))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))

                if isLoading && stations.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else if filteredStations.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 38))
                            .foregroundColor(Color.white.opacity(0.30))
                        Text(stations.isEmpty ? "Noch keine Radiosender gespeichert" : "Keine passenden Sender gefunden")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                        Text("Tippe im Radio-Bereich auf das Herz-Symbol, um Sender hier abzulegen.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        NavigationLink(destination: RadioBrowserView(serverURL: serverURL)) {
                            Text("Alle Sender entdecken")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredStations) { station in
                            stationRow(station)
                        }
                    }
                }

                Spacer(minLength: 120)
            }
        }
        .refreshable {
            await loadFavorites()
        }
        .task {
            await loadFavorites()
        }
    }

    private func stationRow(_ station: LibraryRadioStation) -> some View {
        let radioId = "radio_\(station.id)"
        let isPlayingThis = player.currentTrack?.id == radioId && player.isPlaying

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#18181b"))
                    .frame(width: 54, height: 54)

                let coverURL = resolveStationCover(station)
                PortCachedAsyncImage(url: coverURL) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } placeholder: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#fc3c44"))
                }

                if isPlayingThis {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 54, height: 54)
                    EqualizerBarsView(color: Color(hex: "#fc3c44"))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(station.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : .white)
                        .lineLimit(1)

                    if isPlayingThis {
                        Text("ON AIR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#fc3c44"))
                            .clipShape(Capsule())
                    }
                }

                Text(stationSubtitle(station))
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.50))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                Task { await removeFavorite(station) }
            }) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#fc3c44"))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                if isPlayingThis {
                    player.togglePlayPause()
                } else {
                    playStation(station)
                }
            }) {
                Image(systemName: isPlayingThis ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isPlayingThis {
                player.togglePlayPause()
            } else {
                playStation(station)
            }
        }
    }

    private func stationSubtitle(_ station: LibraryRadioStation) -> String {
        var parts: [String] = []
        if let country = station.country, !country.isEmpty {
            parts.append(country)
        }
        if let tags = station.tags?.prefix(2), !tags.isEmpty {
            parts.append(tags.joined(separator: ", "))
        }
        if let bitrate = station.bitrate, bitrate > 0 {
            parts.append("\(bitrate) kbps")
        }
        return parts.isEmpty ? "Live Stream" : parts.joined(separator: " • ")
    }

    private func resolveStationCover(_ station: LibraryRadioStation) -> URL? {
        guard let fav = station.favicon, !fav.isEmpty else { return nil }
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if fav.hasPrefix("http://") || fav.hasPrefix("https://") {
            var comps = URLComponents(string: "\(base)/api/radio/cover")
            comps?.queryItems = [
                URLQueryItem(name: "url", value: fav),
                URLQueryItem(name: "name", value: station.name)
            ]
            return comps?.url
        }
        return resolveCoverURL(fav, serverURL: serverURL)
    }

    private func playStation(_ station: LibraryRadioStation) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let stationTrack = Track(
            id: "radio_\(station.id)",
            title: station.name,
            artist: "Live Radio",
            album: station.tags?.first ?? station.country ?? "Radio",
            duration: "Radio",
            durationSeconds: 0,
            coverUrl: station.favicon,
            isLive: true,
            isExplicit: false,
            sourceUrl: station.url
        )
        player.play(track: stationTrack, from: [stationTrack], serverURL: serverURL)
    }

    private func loadFavorites() async {
        isLoading = true
        let token = SessionManager.shared.currentToken
        let list = await MusicService.shared.fetchRadioFavorites(serverURL: serverURL, token: token)
        await MainActor.run {
            self.stations = list
            self.isLoading = false
        }
    }

    private func removeFavorite(_ station: LibraryRadioStation) async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let token = SessionManager.shared.currentToken
        let ok = await MusicService.shared.toggleRadioFavorite(station: station, isFavorite: true, serverURL: serverURL, token: token)
        if ok {
            await MainActor.run {
                stations.removeAll { $0.id == station.id }
            }
        }
    }
}
