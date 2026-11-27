import Foundation

public enum CellularStreamingMode: String, CaseIterable, Codable, Sendable {
    case offlineOnly = "offline_only"
    case dataSaver = "data_saver"
    case unlimited = "unlimited"

    public var title: String {
        switch self {
        case .offlineOnly: return "Nur Offline-Songs"
        case .dataSaver: return "Datensparmodus"
        case .unlimited: return "Wie im WLAN (Unbegrenzt)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .offlineOnly: return "Nur Offline"
        case .dataSaver: return "Datensparmodus"
        case .unlimited: return "Unbegrenzt"
        }
    }

    public var subtitle: String {
        switch self {
        case .offlineOnly:
            return "Verbraucht 0 MB mobil · Im WLAN automatisch wieder online"
        case .dataSaver:
            return "Low (~48–64 kbps HE-AAC), kein Vorladen von Songs & Covern"
        case .unlimited:
            return "Nutzt WLAN-Qualität und volles Vorladen auch unterwegs"
        }
    }
}

/// Thread-sicherer zentraler Netzwerk-Richtlinien-Speicher + harte URLProtocol-Firewall.
/// Garantierte 0-Byte-Blockade im manuellen Offline-Modus oder bei Mobilfunk mit "Nur Offline-Songs".
public final class PortNetworkFirewall: @unchecked Sendable {
    public static let shared = PortNetworkFirewall()

    public static let manualOfflineKey = "network_manual_offline_mode"
    public static let cellularModeKey = "network_cellular_mode"
    public static let wifiOnlyDownloadsKey = "offline_wifi_only"
    public static let audioQualityKey = "portmusic_audio_quality"

    private struct PolicyState {
        var manualOfflineMode: Bool
        var cellularMode: CellularStreamingMode
        var wifiAudioQuality: String
        var offlineWifiOnly: Bool
        var isPathSatisfied: Bool
        var isCellular: Bool
        var isConstrained: Bool
    }

    private let lock = NSLock()
    private var state: PolicyState

    private init() {
        let ud = UserDefaults.standard
        let manual = ud.bool(forKey: Self.manualOfflineKey)
        let rawCell = ud.string(forKey: Self.cellularModeKey) ?? CellularStreamingMode.dataSaver.rawValue
        let cellMode = CellularStreamingMode(rawValue: rawCell) ?? .dataSaver
        let rawQual = ud.string(forKey: Self.audioQualityKey) ?? "high"
        let wifiQual = (rawQual == "low" || rawQual == "normal") ? "low" : "high"
        let wifiOnly = (ud.object(forKey: Self.wifiOnlyDownloadsKey) as? Bool) ?? true

        self.state = PolicyState(
            manualOfflineMode: manual,
            cellularMode: cellMode,
            wifiAudioQuality: wifiQual,
            offlineWifiOnly: wifiOnly,
            isPathSatisfied: true,
            isCellular: false,
            isConstrained: false
        )
    }

    public static func install() {
        _ = shared
        URLProtocol.registerClass(PortOfflineFirewallProtocol.self)
    }

    public static func applyPolicy(to config: URLSessionConfiguration, isDownload: Bool = false) {
        var classes = config.protocolClasses ?? []
        if !classes.contains(where: { $0 == PortOfflineFirewallProtocol.self }) {
            classes.insert(PortOfflineFirewallProtocol.self, at: 0)
        }
        config.protocolClasses = classes
        config.waitsForConnectivity = false
        if isDownload {
            config.allowsCellularAccess = shared.allowsDownloadsCellular
        } else {
            config.allowsCellularAccess = shared.allowsCellularTraffic
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    public func update(
        manualOfflineMode: Bool? = nil,
        cellularMode: CellularStreamingMode? = nil,
        wifiAudioQuality: String? = nil,
        offlineWifiOnly: Bool? = nil,
        isPathSatisfied: Bool? = nil,
        isCellular: Bool? = nil,
        isConstrained: Bool? = nil
    ) {
        withLock {
            if let v = manualOfflineMode { state.manualOfflineMode = v }
            if let v = cellularMode { state.cellularMode = v }
            if let v = wifiAudioQuality { state.wifiAudioQuality = (v == "low" || v == "normal") ? "low" : "high" }
            if let v = offlineWifiOnly { state.offlineWifiOnly = v }
            if let v = isPathSatisfied { state.isPathSatisfied = v }
            if let v = isCellular { state.isCellular = v }
            if let v = isConstrained { state.isConstrained = v }
        }
    }

    public var allowsOnlineRequests: Bool {
        withLock {
            if state.manualOfflineMode { return false }
            if !state.isPathSatisfied { return false }
            if state.isCellular && state.cellularMode == .offlineOnly { return false }
            return true
        }
    }

    public var allowsCellularTraffic: Bool {
        withLock {
            !state.manualOfflineMode && state.cellularMode != .offlineOnly
        }
    }

    public var allowsDownloads: Bool {
        withLock {
            if state.manualOfflineMode || !state.isPathSatisfied { return false }
            if state.isCellular && (state.cellularMode == .offlineOnly || state.offlineWifiOnly) {
                return false
            }
            return true
        }
    }

    public var allowsDownloadsCellular: Bool {
        withLock {
            !state.manualOfflineMode && state.cellularMode != .offlineOnly && !state.offlineWifiOnly
        }
    }

    public var isDataSaverActive: Bool {
        withLock {
            if state.manualOfflineMode || !state.isPathSatisfied { return false }
            if state.isCellular && state.cellularMode == .offlineOnly { return false }
            return state.isCellular && (state.cellularMode == .dataSaver || state.isConstrained)
        }
    }

    public var effectiveAudioQuality: String {
        withLock {
            let online = !state.manualOfflineMode && state.isPathSatisfied && !(state.isCellular && state.cellularMode == .offlineOnly)
            if online && state.isCellular && (state.cellularMode == .dataSaver || state.isConstrained) {
                return "low"
            }
            return state.wifiAudioQuality
        }
    }

    public func shouldAllowURLRequest(_ request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return true
        }
        return withLock {
            if state.manualOfflineMode || !state.isPathSatisfied {
                return false
            }
            if state.isCellular {
                if state.cellularMode == .offlineOnly {
                    return false
                }
                if !request.allowsCellularAccess {
                    return false
                }
            }
            return true
        }
    }
}

/// Fängt jede HTTP/HTTPS-Anfrage ab (inkl. URLSession.shared & Dritt-Sessions),
/// sobald der Offline-Modus aktiv ist oder mobile Daten gesperrt sind.
public final class PortOfflineFirewallProtocol: URLProtocol, @unchecked Sendable {
    public override class func canInit(with request: URLRequest) -> Bool {
        return !PortNetworkFirewall.shared.shouldAllowURLRequest(request)
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    public override func startLoading() {
        let err = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "Offline-Modus aktiv: Keine ausgehenden Verbindungen erlaubt."]
        )
        client?.urlProtocol(self, didFailWithError: err)
    }

    public override func stopLoading() {}
}
