import SwiftUI

public struct SearchView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var searchQuery: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header & Suchleiste
                searchHeaderSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Suchergebnisse oder Leerer Zustand
                if isSearching {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.1)
                        Text("Suche läuft...")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if hasSearched && searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 38))
                            .foregroundColor(Color.white.opacity(0.35))
                        Text("Keine Treffer für \"\(searchQuery)\"")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(PortColors.textPrimary)
                        Text("Überprüfe die Schreibweise oder suche nach einem anderen Begriff.")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.60))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasSearched {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(Color.white.opacity(0.35))
                        Text("Musik entdecken")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)
                        Text("Finde Songs, Interpreten und Alben weltweit.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Ergebnisliste
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(searchResults) { track in
                                Button(action: {
                                    player.play(track: track, from: searchResults, serverURL: serverURL)
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(PortColors.surfaceGlassStrong)
                                                .frame(width: 48, height: 48)

                                            if let cover = track.coverUrl, let url = URL(string: cover) {
                                                AsyncImage(url: url) { phase in
                                                    if case .success(let image) = phase {
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 48, height: 48)
                                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    }
                                                }
                                            } else {
                                                Image(systemName: "music.note")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                        }
                                        .frame(width: 48, height: 48)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(track.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(PortColors.textPrimary)
                                                .lineLimit(1)

                                            Text(track.artist)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.white.opacity(0.65))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(track.duration)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(Color.white.opacity(0.50))
                                    }
                                    .padding(10)
                                    .background(PortColors.surfaceGlass)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(PortColors.borderGlass, lineWidth: 0.8)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            Spacer(minLength: 90)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    // MARK: - Suchleiste
    private var searchHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suche")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(PortColors.textPrimary)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(Color.white.opacity(0.70))

                TextField(
                    "",
                    text: $searchQuery,
                    prompt: Text("Songs, Alben oder Künstler...")
                        .foregroundColor(Color.white.opacity(0.50))
                )
                    .font(.system(size: 15))
                    .foregroundColor(PortColors.textPrimary)
                    .tint(.white)
                    .accentColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResults = []
                        hasSearched = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.70))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PortColors.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(PortColors.borderGlass, lineWidth: 1)
            )
        }
    }

    private func performSearch() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isSearching = true
        hasSearched = true

        Task {
            let token = SessionManager.shared.currentToken
            let results = await MusicService.shared.search(query: q, serverURL: serverURL, token: token)

            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
}
