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
        if let direct = URL(string: cleaned) {
            return direct
        }
        if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let direct = URL(string: encoded) {
            return direct
        }
        return nil
    }

    let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    let cleanBase = base.hasPrefix("http://") || base.hasPrefix("https://") ? base : "http://\(base)"
    let path = cleaned.hasPrefix("/") ? cleaned : "/\(cleaned)"
    let full = "\(cleanBase)\(path)"
    if let direct = URL(string: full) {
        return direct
    }
    if let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let direct = URL(string: encoded) {
        return direct
    }
    return nil
}

public func resolveAvatarURL(_ raw: String?, serverURL: String) -> URL? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    if raw.hasPrefix("data:image") {
        return nil
    }
    if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
        if let direct = URL(string: raw) {
            return direct
        }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let direct = URL(string: encoded) {
            return direct
        }
        return nil
    }
    let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    let cleanBase = base.hasPrefix("http://") || base.hasPrefix("https://") ? base : "http://\(base)"
    let path = raw.hasPrefix("/") ? raw : "/\(raw)"
    let full = "\(cleanBase)\(path)"
    if let direct = URL(string: full) {
        return direct
    }
    if let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let direct = URL(string: encoded) {
        return direct
    }
    return nil
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
        let resolved = resolveCoverURL(coverUrl, serverURL: serverURL)
        PortCachedAsyncImage(url: resolved) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color(hex: "#161618")
                Image(systemName: placeholderIcon)
                    .font(.system(size: 26))
                    .foregroundColor(Color.white.opacity(0.25))
            }
        }
    }
}
