import Foundation

// MARK: - REST DTOs (matching backend handlers/jams.rs camelCase)

public struct JamMemberDTO: Codable, Identifiable, Equatable {
    public let deviceId: String
    public let deviceName: String
    public let userId: String?
    public let username: String?
    public let displayName: String?
    public let avatar: String?
    public let lastSeen: String

    public var id: String { deviceId }
}

public struct ActiveJamDTO: Codable, Identifiable, Equatable {
    public let jamId: String
    public let jamName: String?
    public let isPublic: Bool
    public let mode: String
    public let memberCount: Int
    public let members: [JamMemberDTO]
    public let clockDeviceId: String?
    public let updatedAt: String?
    public let globalVolume: Double?

    public var id: String { jamId }
}

public struct JamsListResponse: Codable {
    public let jams: [ActiveJamDTO]
}

public struct CreateJamRequest: Codable {
    public let jamName: String
    public let mode: String
    public let isPublic: Bool
    public let clockDeviceId: String?
}

public struct CreateJamResponse: Codable {
    public let jamId: String
    public let jamName: String
    public let mode: String
    public let isPublic: Bool
    public let jam: ActiveJamDTO
}

// MARK: - WebSocket Models (matching backend sync/src/protocol.rs)

public struct JamWSClientInfo: Codable, Identifiable, Equatable {
    public let clientId: String
    public let displayName: String
    public let isAdmin: Bool
    public let rttMs: Double
    public let lastSeenMs: Double
    public let loadedTrackId: String?
    public let nudgeMs: Double?
    public let compensationMs: Double?

    public var id: String { clientId }

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case displayName = "display_name"
        case isAdmin = "is_admin"
        case rttMs = "rtt_ms"
        case lastSeenMs = "last_seen_ms"
        case loadedTrackId = "loaded_track_id"
        case nudgeMs = "nudge_ms"
        case compensationMs = "compensation_ms"
    }
}

public struct JamQueueTrack: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let cover: String?
    public let duration: String?
    public let durationSeconds: UInt32?
    public let sourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, cover, duration
        case durationSeconds = "duration_seconds"
        case sourceUrl = "source_url"
    }

    public init(from track: Track) {
        self.id = track.id
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.cover = track.coverUrl
        self.duration = track.duration
        self.durationSeconds = track.durationSeconds > 0 ? UInt32(track.durationSeconds.rounded()) : nil
        self.sourceUrl = track.sourceUrl
    }

    public func toTrack() -> Track {
        let durSec = Double(durationSeconds ?? 0)
        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration ?? "0:00",
            durationSeconds: durSec,
            coverUrl: cover,
            isLive: false,
            isExplicit: false,
            sourceUrl: sourceUrl
        )
    }
}

public struct JamPlaybackState: Codable, Equatable {
    public let status: String
    public let trackId: String?
    public let streamUrl: String?
    public let title: String?
    public let artist: String?
    public let coverUrl: String?
    public let serverTimeToExecute: Double
    public let trackPositionSeconds: Double
    public let queue: [JamQueueTrack]?

    enum CodingKeys: String, CodingKey {
        case status
        case trackId = "track_id"
        case streamUrl = "stream_url"
        case title, artist
        case coverUrl = "cover_url"
        case serverTimeToExecute = "server_time_to_execute"
        case trackPositionSeconds = "track_position_seconds"
        case queue
    }
}

public struct JamNTPMeasurement: Equatable {
    public let t0: Double
    public let t1: Double
    public let t2: Double
    public let t3: Double
    public let clockOffsetMs: Double
    public let roundTripDelayMs: Double
}

public enum JamConnectionState: String, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting

    public var displayTitle: String {
        switch self {
        case .disconnected: return "Getrennt"
        case .connecting: return "Verbinde..."
        case .connected: return "Verbunden"
        case .reconnecting: return "Verbindung wird hergestellt..."
        }
    }
}

/// Ausgelagerter Hochfrequenz-Status für Position & NTP-Telemetrie,
/// damit Views wie LibraryView oder MainTabView bei laufender Wiedergabe
/// nicht unnötig neu gerendert werden und die iPhone-UI absolut flüssig bleibt.
@MainActor
public final class JamProgressStore: ObservableObject {
    public static let shared = JamProgressStore()

    @Published public var currentPosition: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var clockOffsetMs: Double = 0.0
    @Published public var minRttMs: Double = 0.0
    @Published public var pureProbeCount: Int = 0
    @Published public var impureProbeCount: Int = 0

    private init() {}

    public func reset() {
        currentPosition = 0.0
        duration = 0.0
        clockOffsetMs = 0.0
        minRttMs = 0.0
        pureProbeCount = 0
        impureProbeCount = 0
    }
}
