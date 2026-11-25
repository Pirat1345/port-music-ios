import Foundation
import Combine

@MainActor
public final class PodcastProgressStore: ObservableObject {
    public static let shared = PodcastProgressStore()

    @Published public private(set) var resumeInfo: PodcastResumeInfo? = nil
    @Published public private(set) var episodeProgressMap: [String: PodcastEpisodeProgress] = [:]

    private let resumeStorageKey = "port_music_podcast_resume_v1"
    private let progressStorageKey = "port_music_podcast_episodes_progress_v1"

    private var activeContextByTrackId: [String: (podcastId: String, podcastTitle: String, feedUrl: String?, audioUrl: String?)] = [:]
    private var lastPersistedTimestamp: Date = .distantPast

    private init() {
        loadAll()
    }

    private func loadAll() {
        if let rData = UserDefaults.standard.data(forKey: resumeStorageKey),
           let decoded = try? JSONDecoder().decode(PodcastResumeInfo.self, from: rData) {
            self.resumeInfo = decoded
        }
        if let pData = UserDefaults.standard.data(forKey: progressStorageKey),
           let decodedMap = try? JSONDecoder().decode([String: PodcastEpisodeProgress].self, from: pData) {
            self.episodeProgressMap = decodedMap
        }
    }

    public func setActivePodcastContext(
        trackId: String,
        podcastId: String,
        podcastTitle: String,
        feedUrl: String?,
        audioUrl: String?
    ) {
        activeContextByTrackId[trackId] = (podcastId, podcastTitle, feedUrl, audioUrl)
    }

    public func progress(for episodeId: String) -> PodcastEpisodeProgress? {
        if let direct = episodeProgressMap[episodeId] {
            return direct
        }
        if !episodeId.hasPrefix("pod_"), let prefixed = episodeProgressMap["pod_\(episodeId)"] {
            return prefixed
        }
        if episodeId.hasPrefix("pod_") {
            let stripped = String(episodeId.dropFirst(4))
            if let unprefixed = episodeProgressMap[stripped] {
                return unprefixed
            }
        }
        return nil
    }

    public func recordProgress(
        track: Track,
        positionSeconds: Double,
        durationSeconds: Double,
        isCompleted: Bool = false,
        forcePersist: Bool = false
    ) {
        let isPodcast = track.id.hasPrefix("pod_")
            || track.album == "Podcast"
            || (track.sourceUrl?.hasPrefix("/api/podcasts/stream") == true)
        guard isPodcast else { return }

        let now = Date()
        if !forcePersist && !isCompleted && now.timeIntervalSince(lastPersistedTimestamp) < 2.0 {
            return
        }
        lastPersistedTimestamp = now

        let safeDur = max(0, durationSeconds)
        let safePos = max(0, positionSeconds)
        let ratio = safeDur > 0 ? min(1.0, max(0.0, safePos / safeDur)) : 0.0
        let completed = isCompleted || (safeDur > 30 && safePos >= safeDur - 15)

        let ctx = activeContextByTrackId[track.id]
        let podcastId = ctx?.podcastId ?? track.artist
        let podcastTitle = ctx?.podcastTitle ?? track.artist

        let epProgress = PodcastEpisodeProgress(
            episodeId: track.id,
            podcastId: podcastId,
            positionSeconds: completed ? safeDur : safePos,
            durationSeconds: safeDur,
            progress: completed ? 1.0 : ratio,
            isCompleted: completed,
            updatedAt: now.timeIntervalSince1970
        )

        episodeProgressMap[track.id] = epProgress
        if track.id.hasPrefix("pod_") {
            let rawId = String(track.id.dropFirst(4))
            episodeProgressMap[rawId] = epProgress
        }

        if let encodedMap = try? JSONEncoder().encode(episodeProgressMap) {
            UserDefaults.standard.set(encodedMap, forKey: progressStorageKey)
        }

        if completed {
            if resumeInfo?.episodeId == track.id {
                clearResume()
            }
        } else if safePos > 3.0 {
            let nextResume = PodcastResumeInfo(
                podcastId: podcastId,
                podcastTitle: podcastTitle,
                podcastFeedUrl: ctx?.feedUrl,
                episodeId: track.id,
                episodeTitle: track.title,
                cover: track.coverUrl,
                audioUrl: ctx?.audioUrl ?? track.sourceUrl,
                positionSeconds: safePos,
                durationSeconds: safeDur,
                progress: ratio,
                updatedAt: now.timeIntervalSince1970
            )
            self.resumeInfo = nextResume
            if let encodedResume = try? JSONEncoder().encode(nextResume) {
                UserDefaults.standard.set(encodedResume, forKey: resumeStorageKey)
            }
        }
    }

    public func clearResume() {
        self.resumeInfo = nil
        UserDefaults.standard.removeObject(forKey: resumeStorageKey)
    }
}
