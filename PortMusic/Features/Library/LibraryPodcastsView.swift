import SwiftUI

// MARK: - Library Podcasts View (Reuses Apple-Style PodcastsDiscoverView)
public struct LibraryPodcastsView: View {
    public let serverURL: String

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        PodcastsDiscoverView(serverURL: serverURL, embeddedInLibrary: true)
    }
}
