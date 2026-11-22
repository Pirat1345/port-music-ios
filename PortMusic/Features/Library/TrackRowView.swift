import SwiftUI

// MARK: - Animated Equalizer Bars Live Indicator
public struct EqualizerBarsView: View {
    @State private var isAnimating: Bool = false
    public var color: Color = Color(hex: "#fc3c44")

    public init(color: Color = Color(hex: "#fc3c44")) {
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 2.5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2.5, height: isAnimating ? 15 : 4)
                .animation(Animation.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: isAnimating)
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2.5, height: isAnimating ? 7 : 16)
                .animation(Animation.easeInOut(duration: 0.35).repeatForever(autoreverses: true).delay(0.12), value: isAnimating)
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2.5, height: isAnimating ? 16 : 5)
                .animation(Animation.easeInOut(duration: 0.50).repeatForever(autoreverses: true).delay(0.24), value: isAnimating)
        }
        .frame(height: 18)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Mobile TrackRow Component (Feature #16)
public struct TrackRowView: View {
    public let track: Track
    public var index: Int? = nil
    public var contextQueue: [Track] = []
    public let serverURL: String
    public var isLiked: Bool = false
    public var isDownloaded: Bool = false
    public var showCover: Bool = true
    public var showTrackNumber: Bool = false
    public var onToggleLike: (() -> Void)? = nil
    public var onSelectArtist: ((String) -> Void)? = nil
    public var onSelectAlbum: ((String) -> Void)? = nil
    public var onAddToPlaylist: (() -> Void)? = nil
    public var onTap: (() -> Void)? = nil

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @State private var localLiked: Bool = false
    @State private var showShareSheet: Bool = false

    public init(
        track: Track,
        index: Int? = nil,
        contextQueue: [Track] = [],
        serverURL: String,
        isLiked: Bool = false,
        isDownloaded: Bool = false,
        showCover: Bool = true,
        showTrackNumber: Bool = false,
        onToggleLike: (() -> Void)? = nil,
        onSelectArtist: ((String) -> Void)? = nil,
        onSelectAlbum: ((String) -> Void)? = nil,
        onAddToPlaylist: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.track = track
        self.index = index
        self.contextQueue = contextQueue
        self.serverURL = serverURL
        self.isLiked = isLiked
        self.isDownloaded = isDownloaded
        self.showCover = showCover
        self.showTrackNumber = showTrackNumber
        self.onToggleLike = onToggleLike
        self.onSelectArtist = onSelectArtist
        self.onSelectAlbum = onSelectAlbum
        self.onAddToPlaylist = onAddToPlaylist
        self.onTap = onTap
        self._localLiked = State(initialValue: isLiked)
    }

    private var isPlayingThis: Bool {
        player.currentTrack?.id == track.id
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Optional: Track Index Number (fuer Alben / Playlists)
            if showTrackNumber, let idx = index {
                Text("\(idx + 1)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : Color.white.opacity(0.40))
                    .frame(width: 24, alignment: .center)
            }

            // Thumbnail Artwork mit 6px Rundung & Play-State-Overlay
            if showCover {
                artworkView
            }

            // Title & Artist / Album Metadaten
            titleAndArtistView

            Spacer(minLength: 6)

            // Right-Side Controls: Offline-Badge, Heart-Toggle & 3-Dots Action Menu
            HStack(spacing: 4) {
                if isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#10b981"))
                        .padding(.trailing, 2)
                }

                // Heart Like Toggle Button
                Button(action: toggleLikeAction) {
                    Image(systemName: localLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(localLiked ? Color(hex: "#fc3c44") : Color.white.opacity(0.40))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // 3-Dots Action Menu
                actionMenu
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .background(
            isPlayingThis
                ? Color.white.opacity(0.08)
                : Color.white.opacity(0.02)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap()
        }
        .onAppear {
            self.localLiked = isLiked
        }
        .onChange(of: isLiked) { newVal in
            self.localLiked = newVal
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [
                "Höre '\(track.title)' von \(track.artist) auf Port Music",
                serverURL
            ])
        }
    }

    // MARK: - Artwork with Play State Overlay
    private var artworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#1c1c1f"))
                .frame(width: 44, height: 44)

            let localCover = OfflineDownloadManager.shared.localCoverFileURL(for: track.id)
            let resolved = localCover ?? resolveCoverURL(track.coverUrl, serverURL: serverURL)
            PortCachedAsyncImage(url: resolved) { img in
                img
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } placeholder: {
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(Color.white.opacity(0.35))
            }

            // Play State Overlay
            if isPlayingThis {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.60))
                        .frame(width: 44, height: 44)

                    if player.isPlaying {
                        EqualizerBarsView(color: Color(hex: "#fc3c44"))
                    } else {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#fc3c44"))
                    }
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
    }

    // MARK: - Title & Artist
    private var titleAndArtistView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(track.title)
                    .font(.system(size: 14, weight: isPlayingThis ? .bold : .medium))
                    .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : .white)
                    .lineLimit(1)

                if track.isExplicit {
                    Text("E")
                        .font(.system(size: 8.5, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 2.5))
                }
            }

            HStack(spacing: 4) {
                if offlineManager.isDownloaded(trackId: track.id) || isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#00d26a"))
                }

                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#a0a0a0"))
                    .lineLimit(1)

                if let album = track.album, !album.isEmpty, album != track.title {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#a0a0a0").opacity(0.6))
                    Text(album)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#a0a0a0").opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - 3-Dots Action Menu
    private var actionMenu: some View {
        Menu {
            // Offline Download Aktion
            if offlineManager.isDownloaded(trackId: track.id) {
                Button(role: .destructive, action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    offlineManager.removeDownload(trackId: track.id)
                }) {
                    Label("Download entfernen", systemImage: "trash")
                }
            } else if offlineManager.isDownloading(trackId: track.id) {
                Button(action: {}) {
                    Label("Wird heruntergeladen...", systemImage: "arrow.down.circle")
                }
                .disabled(true)
            } else {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    Task {
                        await offlineManager.downloadTrack(
                            track: track,
                            serverURL: serverURL,
                            token: SessionManager.shared.currentToken
                        )
                    }
                }) {
                    Label("Herunterladen", systemImage: "arrow.down.circle")
                }
            }

            Divider()

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.playNext(track: track)
            }) {
                Label("Als nächstes abspielen", systemImage: "text.insert")
            }

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.addToQueue(track: track)
            }) {
                Label("Zur Warteschlange hinzufügen", systemImage: "text.append")
            }

            if let onAddToPlaylist = onAddToPlaylist {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onAddToPlaylist()
                }) {
                    Label("Zu Playlist hinzufügen", systemImage: "music.note.list")
                }
            }

            if let onSelectArtist = onSelectArtist, !track.artist.isEmpty {
                Button(action: {
                    onSelectArtist(track.artist)
                }) {
                    Label("Zu Künstler: \(track.artist)", systemImage: "person.fill")
                }
            }

            if let onSelectAlbum = onSelectAlbum, let album = track.album, !album.isEmpty {
                Button(action: {
                    onSelectAlbum(album)
                }) {
                    Label("Zu Album: \(album)", systemImage: "opticaldisc")
                }
            }

            Divider()

            Button(action: {
                showShareSheet = true
            }) {
                Label("Teilen", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.50))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions
    private func handleRowTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if let customTap = onTap {
            customTap()
            return
        }

        if isPlayingThis {
            player.togglePlayPause()
        } else {
            let queue = !contextQueue.isEmpty ? contextQueue : [track]
            player.play(track: track, from: queue, serverURL: serverURL)
        }
    }

    private func toggleLikeAction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        localLiked.toggle()
        onToggleLike?()

        let token = SessionManager.shared.currentToken
        Task {
            _ = await MusicService.shared.toggleFavorite(track: track, serverURL: serverURL, token: token)
        }
    }
}

// MARK: - UIKit UIActivityViewController Wrapper for Sharing
public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
