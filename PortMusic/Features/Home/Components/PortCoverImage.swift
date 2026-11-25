import SwiftUI
import WebKit

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

    if cleaned.hasPrefix("file://") {
        return URL(string: cleaned)
    }

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

// MARK: - Native WebKit SVG Avatar View
public struct PortSVGAvatarView: UIViewRepresentable {
    public let svgContent: String
    public let size: CGFloat

    public init(svgContent: String, size: CGFloat) {
        self.svgContent = svgContent
        self.size = size
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: size, height: size), configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isUserInteractionEnabled = false
        webView.clipsToBounds = true
        webView.layer.cornerRadius = size / 2
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let cleanSvg = svgContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSvg.isEmpty else { return }
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body {
            width: 100%;
            height: 100%;
            background: transparent;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          svg {
            width: 100% !important;
            height: 100% !important;
            display: block;
            border-radius: 50%;
          }
        </style>
        </head>
        <body>
          \(cleanSvg)
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: URL(string: "http://localhost/"))
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
    @State private var svgString: String?
    @State private var boringColors: (Color, Color, Color, Double)

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
        let safeName = username.isEmpty ? "User" : username
        if let cached = AvatarDataCache.shared.getCachedColors(for: safeName) {
            self._boringColors = State(initialValue: (Color(hex: cached.0), Color(hex: cached.1), Color(hex: cached.2), cached.3))
        } else {
            let initialColors = PortUserAvatarView.deterministicBoringColors(for: safeName)
            self._boringColors = State(initialValue: initialColors)
        }
    }

    public static func deterministicBoringColors(for name: String) -> (Color, Color, Color, Double) {
        // Fallback-Farben abgestimmt auf das Standard-Boring-Avatar-Theme (#ffb238 / #ff4b4b / #000000)
        return (Color(hex: "#ffb238"), Color(hex: "#ff4b4b"), Color.black, 65.0)
    }

    public var body: some View {
        ZStack {
            if let img = rasterImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let svg = svgString, !svg.isEmpty {
                PortSVGAvatarView(svgContent: svg, size: size)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                NativeBoringAvatarView(
                    bgColor: boringColors.0,
                    accentColor: boringColors.1,
                    faceColor: boringColors.2,
                    rotation: boringColors.3,
                    size: size
                )
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

    private func extractBoringColors(from svg: String) -> (Color, Color, Color, Double)? {
        let pattern = "fill=['\"](#[0-9a-fA-F]{6})['\"]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: svg, range: NSRange(svg.startIndex..., in: svg))
        var fills: [String] = []
        for m in matches {
            if let range = Range(m.range(at: 1), in: svg) {
                fills.append(String(svg[range]))
            }
        }
        let colors = fills.filter { $0.lowercased() != "#ffffff" && $0.lowercased() != "#fff" }
        guard colors.count >= 2 else { return nil }
        let bg = Color(hex: colors[0])
        let accent = Color(hex: colors[1])
        let face = colors.count >= 3 ? Color(hex: colors[2]) : Color.black
        var rot = 65.0
        if let rotRange = svg.range(of: "rotate(") {
            let sub = svg[rotRange.upperBound...]
            if let spaceIdx = sub.firstIndex(of: " ") {
                if let r = Double(sub[..<spaceIdx]) { rot = r }
            }
        }
        return (bg, accent, face, rot)
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

        // 2. Inline SVG string oder data:image/svg+xml
        if raw.contains("<svg") || raw.contains("svg+xml") {
            if raw.contains("base64,") {
                if let b64 = raw.components(separatedBy: "base64,").last,
                   let data = Data(base64Encoded: b64.trimmingCharacters(in: .whitespacesAndNewlines)),
                   let str = String(data: data, encoding: .utf8), str.contains("<svg") {
                    if let parsed = extractBoringColors(from: str) {
                        self.boringColors = parsed
                    }
                    self.svgString = str
                    return
                }
            } else if let commaIdx = raw.firstIndex(of: ",") {
                let payload = String(raw[raw.index(after: commaIdx)...])
                let decoded = payload.removingPercentEncoding ?? payload
                if decoded.contains("<svg") {
                    if let parsed = extractBoringColors(from: decoded) {
                        self.boringColors = parsed
                    }
                    self.svgString = decoded
                    return
                }
            } else if raw.contains("<svg") {
                if let parsed = extractBoringColors(from: raw) {
                    self.boringColors = parsed
                }
                self.svgString = raw
                return
            }
        }

        // 3. Remote URL (z.B. /api/files/avatars/... oder http...)
        let effectiveServerURL: String = {
            if !serverURL.isEmpty && !serverURL.contains("localhost") && !serverURL.contains("127.0.0.1") {
                return serverURL
            }
            return SessionManager.shared.serverURL ?? serverURL
        }()
        guard let url = resolveAvatarURL(raw, serverURL: effectiveServerURL) else { return }
        let urlKey = url.absoluteString
        let svgCacheKey = "pm_avatar_svg_\(urlKey)"

        // 3a. Cache-Prüfung für SVG
        if let cachedSvg = UserDefaults.standard.string(forKey: svgCacheKey), !cachedSvg.isEmpty {
            if let parsed = extractBoringColors(from: cachedSvg) {
                self.boringColors = parsed
            }
            self.svgString = cachedSvg
            return
        }

        // 3b. Falls es sich um eine SVG-Datei handelt, direkt abrufen (PortImageCache kann kein SVG dekodieren)
        if url.pathExtension.lowercased() == "svg" || raw.contains(".svg") {
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
                if let str = String(data: data, encoding: .utf8), str.contains("<svg") {
                    UserDefaults.standard.set(str, forKey: svgCacheKey)
                    if let parsed = extractBoringColors(from: str) {
                        self.boringColors = parsed
                        AvatarDataCache.shared.saveColors(bg: "#ffb238", accent: "#ff4b4b", face: "#000000", rot: parsed.3, for: username.isEmpty ? "User" : username)
                    }
                    self.svgString = str
                    return
                }
            } catch {}
            return
        }

        // 3c. Sofort aus Memory-Cache laden falls Rasterbild vorhanden
        if let memImg = PortImageCache.shared.imageFromMemory(for: url) {
            rasterImage = memImg
            return
        }

        // 3d. Über PortImageCache (Disk + Netzwerk) laden
        if let loaded = await PortImageCache.shared.loadImage(for: url) {
            rasterImage = loaded
            return
        }

        // 3e. Direkte HTTP-Abfrage für sonstige Bilder
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
                return
            }

            if let str = String(data: data, encoding: .utf8), str.contains("<svg") {
                UserDefaults.standard.set(str, forKey: svgCacheKey)
                if let parsed = extractBoringColors(from: str) {
                    self.boringColors = parsed
                }
                self.svgString = str
                return
            }
        } catch {}
    }
}

public struct PortCoverImage: View {
    public let coverUrl: String?
    public let serverURL: String
    public let placeholderIcon: String
    public let trackId: String?

    public init(
        coverUrl: String?,
        serverURL: String,
        placeholderIcon: String = "music.note",
        trackId: String? = nil
    ) {
        self.coverUrl = coverUrl
        self.serverURL = serverURL
        self.placeholderIcon = placeholderIcon
        self.trackId = trackId
    }

    public var body: some View {
        let offlineCoverURL = trackId.flatMap { OfflineDownloadManager.shared.localCoverFileURL(for: $0) }
        let resolved = offlineCoverURL ?? resolveCoverURL(coverUrl, serverURL: serverURL)
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

/// Renders a playlist cover matching Web `PlaylistCover.tsx`:
/// 1. Explicit custom cover image
/// 2. 2x2 collage when at least 4 unique track covers exist
/// 3. Single cover when 1..3 track covers exist
/// 4. Centered placeholder icon when empty
public struct PlaylistArtworkView: View {
    public let coverUrl: String?
    public let trackCovers: [String]?
    public var cornerRadius: CGFloat = 12
    public var iconSize: CGFloat = 32
    public var placeholderIcon: String = "music.note.list"
    public let serverURL: String

    public init(
        coverUrl: String?,
        trackCovers: [String]? = nil,
        cornerRadius: CGFloat = 12,
        iconSize: CGFloat = 32,
        placeholderIcon: String = "music.note.list",
        serverURL: String
    ) {
        self.coverUrl = coverUrl
        self.trackCovers = trackCovers
        self.cornerRadius = cornerRadius
        self.iconSize = iconSize
        self.placeholderIcon = placeholderIcon
        self.serverURL = serverURL
    }

    private func isDefaultCover(_ raw: String?) -> Bool {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return true
        }
        return trimmed.contains("cover-1.")
            || trimmed == "/default-cover.svg"
            || trimmed.hasSuffix("/default-cover.svg")
            || trimmed == "/default-playlist.svg"
    }

    private var customCoverURL: URL? {
        guard !isDefaultCover(coverUrl), let coverUrl else { return nil }
        return resolveCoverURL(coverUrl, serverURL: serverURL)
    }

    private var uniqueTrackCoverURLs: [URL] {
        guard let trackCovers, !trackCovers.isEmpty else { return [] }
        var seen = Set<String>()
        var urls: [URL] = []
        for raw in trackCovers {
            guard !isDefaultCover(raw) else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(trimmed).inserted, let resolved = resolveCoverURL(trimmed, serverURL: serverURL) {
                urls.append(resolved)
                if urls.count >= 4 { break }
            }
        }
        return urls
    }

    public var body: some View {
        ZStack(alignment: .center) {
            Color(hex: "#18181b")

            if let custom = customCoverURL {
                PortCachedAsyncImage(url: custom) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    emptyPlaceholder
                }
            } else {
                let covers = uniqueTrackCoverURLs
                if covers.count >= 4 {
                    GeometryReader { geo in
                        let tileW = max(1, geo.size.width / 2)
                        let tileH = max(1, geo.size.height / 2)
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                mosaicTile(url: covers[0], width: tileW, height: tileH)
                                mosaicTile(url: covers[1], width: tileW, height: tileH)
                            }
                            HStack(spacing: 0) {
                                mosaicTile(url: covers[2], width: tileW, height: tileH)
                                mosaicTile(url: covers[3], width: tileW, height: tileH)
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                } else if let first = covers.first {
                    PortCachedAsyncImage(url: first) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        emptyPlaceholder
                    }
                } else {
                    emptyPlaceholder
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func mosaicTile(url: URL, width: CGFloat, height: CGFloat) -> some View {
        PortCachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } placeholder: {
            Color(hex: "#202024")
                .frame(width: width, height: height)
        }
    }

    private var emptyPlaceholder: some View {
        ZStack(alignment: .center) {
            Color(hex: "#18181b")
            Image(systemName: placeholderIcon)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundColor(Color.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
