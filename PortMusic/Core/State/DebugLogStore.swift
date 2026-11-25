import Foundation
import Combine

@MainActor
public final class DebugLogStore: ObservableObject {
    public static let shared = DebugLogStore()

    public enum Category: String, CaseIterable {
        case stream = "Playback / Stream"
        case system = "Netzwerk & System"
    }

    public struct Entry: Identifiable, Equatable {
        public let id: Int
        public let timestamp: Date
        public let category: Category
        public let tag: String
        public let message: String
    }

    @Published public private(set) var entries: [Entry] = []
    private var nextSeq: Int = 1
    private let maxEntries: Int = 300
    private let bootTime = Date()

    private init() {
        log(tag: "boot", category: .system, message: "Port Music iOS Diagnose initialisiert")
    }

    public func log(tag: String, category: Category = .stream, message: String) {
        let entry = Entry(
            id: nextSeq,
            timestamp: Date(),
            category: category,
            tag: tag,
            message: message
        )
        nextSeq += 1
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func clear() {
        entries.removeAll()
    }

    public func elapsedString(for date: Date) -> String {
        let delta = max(0, date.timeIntervalSince(bootTime))
        return String(format: "+%.2fs", delta)
    }

    public func formattedAll(session: SessionManager, player: AudioPlayerManager) -> String {
        var lines: [String] = []
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        lines.append("=== Port Music iOS Diagnose ===")
        lines.append("Version: \(appVersion)")
        lines.append("Netzwerk: \(session.networkInterface.rawValue) (\(session.networkStatusRaw))")
        lines.append("Offline-Modus: \(session.isOfflineMode ? "Aktiv" : "Online")")
        lines.append("Server-URL: \(session.serverURL ?? "-")")
        if let cur = player.currentTrack {
            lines.append("Aktiver Titel: \(cur.title) - \(cur.artist) (live=\(cur.isLive), offline=\(player.isPlayingOffline))")
        }
        lines.append("--- Ereignisse (\(entries.count)) ---")
        for e in entries {
            lines.append("\(elapsedString(for: e.timestamp)) [\(e.tag)] \(e.message)")
        }
        return lines.joined(separator: "\n")
    }
}
