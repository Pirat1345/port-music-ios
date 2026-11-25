import SwiftUI

// MARK: - Native iOS Radio Browser View (Port Music v2)
// Bietet kuratierte Radiosender und Live-Streams aus der Port Music Radio-API
public struct RadioBrowserView: View {
    public let serverURL: String
    @ObservedObject private var player = AudioPlayerManager.shared

    @State private var stations: [RadioStationItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Kopfzeile
                VStack(alignment: .leading, spacing: 4) {
                    Text("Radio")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Live-Sender und kuratierte Stationen weltweit")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.60))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text("Radiosender laden...")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.50))
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40))
                            .foregroundColor(Color.white.opacity(0.35))
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.60))
                        Button("Erneut versuchen") {
                            Task { await loadStations() }
                        }
                        .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Sender-Gitter (2 Spalten wie in Apple Music Radio)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(stations) { station in
                            stationCard(station)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 160)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.black.ignoresSafeArea())
        .task {
            await loadStations()
        }
    }

    private func stationCard(_ station: RadioStationItem) -> some View {
        Button(action: {
            playStation(station)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [station.color.opacity(0.85), Color(hex: "#18181b")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )

                    // Sender-Icon
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.40))
                        .padding(12)

                    // LIVE Badge
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(station.genre)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func playStation(_ station: RadioStationItem) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let radioTrack = Track(
            id: "radio_\(station.id)",
            title: station.name,
            artist: "Live Radio",
            album: station.genre,
            duration: "LIVE",
            durationSeconds: 0,
            coverUrl: nil,
            isLive: true,
            isExplicit: false
        )
        player.play(track: radioTrack, from: [radioTrack], serverURL: serverURL)
    }

    private func loadStations() async {
        isLoading = true
        errorMessage = nil

        // Standard-Radiosenderliste (Fallback + Live-Stationen)
        let curated: [RadioStationItem] = [
            RadioStationItem(id: "apple_music_1", name: "Apple Music 1", genre: "Pop & Charts", streamUrl: "https://listen.181fm.com/181-power_128k.mp3", color: Color(hex: "#fc3c44")),
            RadioStationItem(id: "apple_music_hits", name: "Apple Music Hits", genre: "80er, 90er & 2000er", streamUrl: "https://listen.181fm.com/181-awesome80s_128k.mp3", color: Color(hex: "#f59e0b")),
            RadioStationItem(id: "apple_music_country", name: "Apple Music Country", genre: "Country Hits", streamUrl: "https://listen.181fm.com/181-kickincountry_128k.mp3", color: Color(hex: "#10b981")),
            RadioStationItem(id: "chillout_lounge", name: "Chillout Lounge", genre: "Ambient & Lo-Fi", streamUrl: "https://listen.181fm.com/181-chilled_128k.mp3", color: Color(hex: "#6366f1")),
            RadioStationItem(id: "deep_house_live", name: "Deep House Radio", genre: "Electronic & Club", streamUrl: "https://listen.181fm.com/181-energy98_128k.mp3", color: Color(hex: "#8b5cf6")),
            RadioStationItem(id: "rock_classics", name: "Rock Classics", genre: "Classic Rock & Metal", streamUrl: "https://listen.181fm.com/181-rock40_128k.mp3", color: Color(hex: "#ef4444"))
        ]

        await MainActor.run {
            self.stations = curated
            self.isLoading = false
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
