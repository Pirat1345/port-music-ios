import SwiftUI

// MARK: - Local Uploaded Audio Files View (/api/files/audio)
public struct LibraryLocalFilesView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var tracks: [Track] = []
    @State private var isLoading: Bool = true
    @State private var searchQuery: String = ""

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    private var filteredTracks: [Track] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(q)
            || $0.artist.lowercased().contains(q)
            || ($0.album?.lowercased().contains(q) ?? false)
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.40))
                    TextField("Lokale Dateien durchsuchen...", text: $searchQuery)
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

                if !filteredTracks.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if let first = filteredTracks.first {
                                player.play(track: first, from: filteredTracks, serverURL: serverURL)
                            }
                        }) {
                            HStack(spacing: 7) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Abspielen")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            let shuffled = filteredTracks.shuffled()
                            if let first = shuffled.first {
                                player.play(track: first, from: shuffled, serverURL: serverURL)
                            }
                        }) {
                            HStack(spacing: 7) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Zufallswiedergabe")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                if isLoading && tracks.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else if filteredTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 38))
                            .foregroundColor(Color.white.opacity(0.30))
                        Text(tracks.isEmpty ? "Keine hochgeladenen Dateien" : "Keine Treffer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                        Text("Eigene MP3/FLAC/M4A-Dateien, die über das Web-Dashboard hochgeladen wurden, erscheinen hier.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                            TrackRowView(
                                track: track,
                                index: index,
                                contextQueue: filteredTracks,
                                serverURL: serverURL,
                                isLiked: FavoritesManager.shared.isFavorite(track.id),
                                isDownloaded: false,
                                showCover: true,
                                showTrackNumber: false
                            )
                        }
                    }
                }

                Spacer(minLength: 120)
            }
        }
        .refreshable {
            await loadFiles()
        }
        .task {
            await loadFiles()
        }
    }

    private func loadFiles() async {
        isLoading = true
        let token = SessionManager.shared.currentToken
        let items = await MusicService.shared.fetchLocalAudioFiles(serverURL: serverURL, token: token)
        await MainActor.run {
            self.tracks = items
            self.isLoading = false
        }
    }
}
