import SwiftUI

public struct PodcastGenreConfig: Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let iconName: String
    public let accentHex: String
    public let description: String
}

public enum PodcastCategories {
    public static let all: [PodcastGenreConfig] = [
        PodcastGenreConfig(id: 1488, name: "Wahre Kriminalfälle", iconName: "magnifyingglass", accentHex: "#6366f1", description: "Spannende Ermittlungen, mysteriöse Fälle und echte Kriminalgeschichten."),
        PodcastGenreConfig(id: 1303, name: "Comedy", iconName: "face.smiling.fill", accentHex: "#f97316", description: "Humor, Satire, Stand-up und heitere Unterhaltungs-Talks."),
        PodcastGenreConfig(id: 1324, name: "Gesellschaft und Kultur", iconName: "globe.europe.africa.fill", accentHex: "#f43f5e", description: "Persönliche Geschichten, Philosophie, Zeitgeist und Gesellschaft."),
        PodcastGenreConfig(id: 1311, name: "Nachrichten", iconName: "newspaper.fill", accentHex: "#38bdf8", description: "Tägliche Berichte, politische Analysen und weltweites Geschehen."),
        PodcastGenreConfig(id: 1511, name: "Gesundheit und Fitness", iconName: "heart.text.square.fill", accentHex: "#60a5fa", description: "Mentale Gesundheit, Ernährung, Medizin und körperliche Fitness."),
        PodcastGenreConfig(id: 1545, name: "Sport", iconName: "trophy.fill", accentHex: "#4ade80", description: "Fußball, Formel 1, US-Sport, Hintergründe und Sportler-Interviews."),
        PodcastGenreConfig(id: 1321, name: "Wirtschaft", iconName: "briefcase.fill", accentHex: "#93c5fd", description: "Start-ups, Finanzen, Aktienmarkt, Karriere und Wirtschaftsanalysen."),
        PodcastGenreConfig(id: 1304, name: "Bildung", iconName: "graduationcap.fill", accentHex: "#2dd4bf", description: "Sprachen lernen, Weiterbildung, Erziehung und Wissen für den Alltag."),
        PodcastGenreConfig(id: 1301, name: "Kunst", iconName: "paintpalette.fill", accentHex: "#fb7185", description: "Design, Literatur, Bildende Kunst und kreatives Schaffen."),
        PodcastGenreConfig(id: 1315, name: "Wissenschaft", iconName: "atom", accentHex: "#34d399", description: "Astronomie, Physik, Biologie, Forschung und wissenschaftliche Entdeckungen."),
        PodcastGenreConfig(id: 1512, name: "Geschichte", iconName: "building.columns.fill", accentHex: "#fbbf24", description: "Epochen, historische Wendepunkte, Biografien und Zeitzeugen."),
        PodcastGenreConfig(id: 1314, name: "Religion und Spiritualität", iconName: "sparkles", accentHex: "#38bdf8", description: "Meditation, Glaube, Achtsamkeit und Lebensphilosophie."),
        PodcastGenreConfig(id: 1305, name: "Kinder und Familie", iconName: "figure.2.and.child.holdinghands", accentHex: "#6ee7b7", description: "Gute-Nacht-Geschichten, Hörspiele und Wissen für die ganze Familie."),
        PodcastGenreConfig(id: 1310, name: "Musik", iconName: "music.note", accentHex: "#f87171", description: "Songwriting, Alben-Reviews, Interviews mit Musikern und Genres."),
        PodcastGenreConfig(id: 1309, name: "TV und Film", iconName: "film.fill", accentHex: "#f472b6", description: "Kino-Kritiken, Serien-Talks, Popkultur und Hinter den Kulissen."),
        PodcastGenreConfig(id: 1318, name: "Technologie", iconName: "cpu.fill", accentHex: "#818cf8", description: "KI, Gadgets, Programmierung, Internetkultur und Zukunftstrends.")
    ]

    public static let discoverShelves: [(genreId: Int, title: String, subtitle: String)] = [
        (1324, "Gesellschaft und Kultur", "Persönliche Geschichten, Zeitgeist und Gesellschaft"),
        (1303, "Comedy", "Humor, Satire und beliebte Unterhaltungs-Talks"),
        (1488, "Wahre Kriminalfälle", "Packende Ermittlungen und echte Kriminalgeschichten"),
        (1511, "Gesundheit und Fitness", "Mentale Gesundheit, Ernährung und Wohlbefinden"),
        (1311, "Nachrichten & Politik", "Tägliche Berichte und Analysen")
    ]
}

public enum PodcastSubscriptionStore {
    private static let storageKey = "port_music_subscribed_podcasts"

    public static func load() -> [PodcastItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([PodcastItem].self, from: data) else {
            return []
        }
        return saved
    }

    public static func isSubscribed(_ podcast: PodcastItem) -> Bool {
        load().contains {
            $0.id == podcast.id || (!podcast.feedUrl.isEmpty && $0.feedUrl == podcast.feedUrl)
        }
    }

    @discardableResult
    public static func toggle(_ podcast: PodcastItem) -> Bool {
        var current = load()
        if let idx = current.firstIndex(where: {
            $0.id == podcast.id || (!podcast.feedUrl.isEmpty && $0.feedUrl == podcast.feedUrl)
        }) {
            current.remove(at: idx)
            save(current)
            return false
        } else {
            current.insert(podcast, at: 0)
            save(current)
            return true
        }
    }

    private static func save(_ list: [PodcastItem]) {
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
