import SwiftUI

public struct PortArtistCard: View {
    public let artist: DiscoveryArtist
    public let onSelect: () -> Void

    public init(artist: DiscoveryArtist, onSelect: @escaping () -> Void) {
        self.artist = artist
        self.onSelect = onSelect
    }

    private var initials: String {
        let parts = artist.name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(artist.name.prefix(2)).uppercased()
    }

    private var fanCountText: String {
        if let fans = artist.nbFan, fans > 0 {
            if fans >= 1_000_000 {
                return String(format: "%.1fM Fans", Double(fans) / 1_000_000.0)
            } else if fans >= 1_000 {
                return String(format: "%dK Fans", fans / 1_000)
            } else {
                return "\(fans) Fans"
            }
        }
        return "Künstler"
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#18181b"))
                        .frame(width: 120, height: 120)

                    Text(initials)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.70))

                    if let pic = artist.picture, let url = URL(string: pic) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)

                VStack(spacing: 2) {
                    Text(artist.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)
                        .lineLimit(1)
                        .frame(width: 120)

                    Text(fanCountText)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                        .frame(width: 120)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
