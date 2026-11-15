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

// MARK: - Avatar Cache (In-Memory + UserDefaults)
public final class AvatarDataCache {
    public static let shared = AvatarDataCache()
    private let memoryCache = NSCache<NSString, NSString>()
    private let defaults = UserDefaults.standard
    private let prefix = "port-musik-avatar-cache-v1:"

    private init() {}

    public func getCachedSvg(for key: String) -> String? {
        if let mem = memoryCache.object(forKey: key as NSString) {
            return mem as String
        }
        if let stored = defaults.string(forKey: prefix + key) {
            memoryCache.setObject(stored as NSString, forKey: key as NSString)
            return stored
        }
        return nil
    }

    public func saveSvg(_ svg: String, for key: String) {
        memoryCache.setObject(svg as NSString, forKey: key as NSString)
        defaults.set(svg, forKey: prefix + key)
    }
}

// MARK: - Native SVG Vector Avatar Viewer (WKWebView)
public struct SVGAvatarWebView: UIViewRepresentable {
    public let svgString: String

    public init(svgString: String) {
        self.svgString = svgString
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        var cleanSvg = svgString
            .replacingOccurrences(of: "%23", with: "#")
            .replacingOccurrences(of: "%20", with: " ")
            .replacingOccurrences(of: "%27", with: "'")
            .replacingOccurrences(of: "%22", with: "\"")

        if let decoded = cleanSvg.removingPercentEncoding, decoded.contains("<svg") {
            cleanSvg = decoded
        }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { width: 100%; height: 100%; background: transparent; overflow: hidden; display: flex; align-items: center; justify-content: center; }
        svg { width: 100%; height: 100%; border-radius: 50%; display: block; }
        img { width: 100%; height: 100%; object-fit: cover; border-radius: 50%; display: block; }
        </style>
        </head>
        <body>
        \(cleanSvg)
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Reusable Port User Avatar View
public struct PortUserAvatarView: View {
    public let rawAvatar: String?
    public let username: String
    public let serverURL: String
    public let size: CGFloat
    public let isSelected: Bool

    @State private var loadedSvg: String?
    @State private var loadedImage: UIImage?
    @State private var hasFailed: Bool = false

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
            if let svg = loadedSvg {
                SVGAvatarWebView(svgString: svg)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let img = loadedImage {
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
        .task(id: rawAvatar) {
            await resolveAndLoad()
        }
    }

    private var fallbackMonogram: some View {
        let initial = username.prefix(1).uppercased()
        return ZStack {
            Circle()
                .fill(isSelected ? Color.white : Color.white.opacity(0.18))
            Text(initial.isEmpty ? "U" : initial)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundColor(isSelected ? .black : .white)
        }
        .frame(width: size, height: size)
    }

    @MainActor
    private func resolveAndLoad() async {
        guard let raw = rawAvatar?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            hasFailed = true
            return
        }

        // 1. Raw inline SVG
        if raw.contains("<svg") {
            let svgStr = extractSVG(from: raw)
            loadedSvg = svgStr
            return
        }

        // 2. data:image/svg+xml
        if raw.hasPrefix("data:image/svg+xml") {
            if let commaIndex = raw.firstIndex(of: ",") {
                let payload = String(raw[raw.index(after: commaIndex)...])
                let decoded = payload.removingPercentEncoding ?? payload
                if decoded.contains("<svg") {
                    loadedSvg = decoded
                    return
                }
            }
        }

        // 3. data:image/png or jpeg (base64)
        if raw.hasPrefix("data:image"),
           let base64Part = raw.components(separatedBy: ",").last,
           let data = Data(base64Encoded: base64Part),
           let img = UIImage(data: data) {
            loadedImage = img
            return
        }

        // 4. Remote URL or server path (e.g. /api/files/avatars/...)
        guard let url = resolveAvatarURL(raw, serverURL: serverURL) else {
            hasFailed = true
            return
        }

        let urlKey = url.absoluteString

        // Check local cache first
        if let cachedSvg = AvatarDataCache.shared.getCachedSvg(for: urlKey) {
            loadedSvg = cachedSvg
            return
        }

        // Fetch from network
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 10.0
            if let token = SessionManager.shared.currentToken, !token.isEmpty {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                hasFailed = true
                return
            }

            // Check if SVG content
            if let str = String(data: data, encoding: .utf8), (str.contains("<svg") || str.contains("<?xml")) {
                let clean = extractSVG(from: str)
                AvatarDataCache.shared.saveSvg(clean, for: urlKey)
                loadedSvg = clean
                return
            }

            // Fallback to raster image
            if let img = UIImage(data: data) {
                loadedImage = img
                return
            }

            hasFailed = true
        } catch {
            hasFailed = true
        }
    }

    private func extractSVG(from raw: String) -> String {
        if let start = raw.range(of: "<svg", options: .caseInsensitive),
           let end = raw.range(of: "</svg>", options: [.caseInsensitive, .backwards]) {
            return String(raw[start.lowerBound...end.upperBound])
        }
        return raw
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
