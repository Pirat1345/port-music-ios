import SwiftUI

public func resolveCoverURL(_ raw: String?, serverURL: String) -> URL? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    if raw.contains("default-cover") || raw.contains("d41d8cd98f00b204e9800998ecf8427e") || raw.contains("52ab317011e8e6f8748ec3b7d9f38ddd") {
        return nil
    }

    var cleaned = raw
        .replacingOccurrences(of: "{w}x{h}", with: "600x600")
        .replacingOccurrences(of: "{w}", with: "600")
        .replacingOccurrences(of: "{h}", with: "600")
        .replacingOccurrences(of: "100x100bb", with: "600x600bb")

    if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://") {
        return URL(string: cleaned)
    }

    let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    let cleanBase = base.hasPrefix("http://") || base.hasPrefix("https://") ? base : "http://\(base)"
    let path = cleaned.hasPrefix("/") ? cleaned : "/\(cleaned)"
    return URL(string: "\(cleanBase)\(path)")
}

public struct PortCoverImage: View {
    public let coverUrl: String?
    public let serverURL: String
    public let placeholderIcon: String

    public init(
        coverUrl: String?,
        serverURL: String,
        placeholderIcon: String = "music.note"
    ) {
        self.coverUrl = coverUrl
        self.serverURL = serverURL
        self.placeholderIcon = placeholderIcon
    }

    public var body: some View {
        ZStack {
            Color(hex: "#161618")

            if let resolved = resolveCoverURL(coverUrl, serverURL: serverURL) {
                AsyncImage(url: resolved) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: placeholderIcon)
                            .font(.system(size: 26))
                            .foregroundColor(Color.white.opacity(0.25))
                    case .empty:
                        Color(hex: "#18181b")
                    @unknown default:
                        Image(systemName: placeholderIcon)
                            .font(.system(size: 26))
                            .foregroundColor(Color.white.opacity(0.25))
                    }
                }
            } else {
                Image(systemName: placeholderIcon)
                    .font(.system(size: 26))
                    .foregroundColor(Color.white.opacity(0.25))
            }
        }
    }
}
