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
    var base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    if !base.hasPrefix("http://") && !base.hasPrefix("https://") {
        base = "http://\(base)"
    }
    if base.hasSuffix("/api") {
        base = String(base.dropLast(4))
    }
    var path = raw
    if !path.hasPrefix("/") {
        path = "/\(path)"
    }
    if path.hasPrefix("/files/avatars/") {
        path = "/api" + path
    }
    let full = "\(base)\(path)"
    if let direct = URL(string: full) {
        return direct
    }
    if let encoded = full.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let direct = URL(string: encoded) {
        return direct
    }
    return nil
}

// MARK: - Avatar Cache (In-Memory + UserDefaults)
public final class AvatarDataCache {
    public static let shared = AvatarDataCache()
    private let defaults = UserDefaults.standard
    private let prefix = "port-musik-avatar-cache-v1:"

    private init() {}

    public func getCachedColors(for key: String) -> (String, String, String, Double)? {
        let stored = defaults.string(forKey: prefix + key)
        guard let s = stored else { return nil }
        let parts = s.components(separatedBy: "|")
        guard parts.count >= 4 else { return nil }
        let rot = Double(parts[3]) ?? 65.0
        return (parts[0], parts[1], parts[2], rot)
    }

    public func saveColors(bg: String, accent: String, face: String, rot: Double, for key: String) {
        let s = "\(bg)|\(accent)|\(face)|\(rot)"
        defaults.set(s, forKey: prefix + key)
    }
}

// MARK: - 100% Native Vector Boring Avatar (Zero WebKit - Crash Free & Ultra-Fast)
public struct NativeBoringAvatarView: View {
    public let bgColor: Color
    public let accentColor: Color
    public let faceColor: Color
    public let rotation: Double
    public let size: CGFloat

    public init(
        bgColor: Color = Color(hex: "#ffb238"),
        accentColor: Color = Color(hex: "#ff4b4b"),
        faceColor: Color = Color.black,
        rotation: Double = 65,
        size: CGFloat = 24
    ) {
        self.bgColor = bgColor
        self.accentColor = accentColor
        self.faceColor = faceColor
        self.rotation = rotation
        self.size = size
    }

    public var body: some View {
        ZStack {
            // 1. Hintergrund-Kreis
            Circle()
                .fill(bgColor)

            // 2. Sekundäre rotierte Form (Akzent-Blob)
            RoundedRectangle(cornerRadius: size * 0.32)
                .fill(accentColor)
                .frame(width: size * 0.90, height: size * 0.90)
                .rotationEffect(.degrees(rotation))
                .offset(x: size * 0.04, y: -size * 0.04)

            // 3. Gesichtszüge (Augen + Mund)
            VStack(spacing: max(1.5, size * 0.09)) {
                // Augen
                HStack(spacing: max(3, size * 0.26)) {
                    Capsule()
                        .fill(faceColor)
                        .frame(width: max(1.8, size * 0.07), height: max(2.5, size * 0.11))
                    Capsule()
                        .fill(faceColor)
                        .frame(width: max(1.8, size * 0.07), height: max(2.5, size * 0.11))
                }
                .padding(.top, size * 0.06)

                // Mund (Lächeln)
                Capsule()
                    .fill(faceColor)
                    .frame(width: max(4, size * 0.26), height: max(1.5, size * 0.06))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Reusable Port User Avatar View
public struct PortUserAvatarView: View {
    public let rawAvatar: String?
    public let username: String
    public let serverURL: String
    public let size: CGFloat
    public let isSelected: Bool

    @State private var rasterImage: UIImage?

    public init(
        rawAvatar: String?,
        username: String,
        serverURL: String,
        size: CGFloat = 28,
        isSelected: Bool = false
    ) {
        self.rawAvatar = rawAvatar
        self.username = username
        self.serverURL = serverURL
        self.size = size
        self.isSelected = isSelected
    }

    public var body: some View {
        ZStack {
            if let img = rasterImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackMonogram
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5)
        )
        .task(id: rawAvatar) {
            await resolveAvatar()
        }
    }

    private var fallbackMonogram: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2c2d35"), Color(hex: "#16161a")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if !username.isEmpty {
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
    }

    @MainActor
    private func resolveAvatar() async {
        guard let raw = rawAvatar?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return
        }

        // 1. data:image/png oder jpeg (base64)
        if raw.hasPrefix("data:image"), !raw.contains("svg") {
            if let base64Part = raw.components(separatedBy: ",").last,
               let data = Data(base64Encoded: base64Part, options: .ignoreUnknownCharacters),
               let img = UIImage(data: data) {
                rasterImage = img
                return
            }
        }

        // 2. Remote URL (z.B. /api/files/avatars/... oder http...)
        guard let url = resolveAvatarURL(raw, serverURL: serverURL) else { return }

        // 2a. Sofort aus Memory-Cache laden falls vorhanden
        if let memImg = PortImageCache.shared.imageFromMemory(for: url) {
            rasterImage = memImg
            return
        }

        // 2b. Über PortImageCache (Disk + Netzwerk) laden
        if let loaded = await PortImageCache.shared.loadImage(for: url) {
            rasterImage = loaded
            return
        }

        // 2c. Direkte HTTP-Abfrage fuer Bilddateien
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 8.0
            if let token = SessionManager.shared.currentToken, !token.isEmpty {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }

            if let img = UIImage(data: data) {
                rasterImage = img
                PortImageCache.shared.storeImageInMemory(img, for: url)
                return
            }
        } catch {}
    }
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
