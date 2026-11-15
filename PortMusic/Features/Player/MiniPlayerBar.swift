import SwiftUI

/// Compatibility wrapper for PlayerBarView
public struct MiniPlayerBar: View {
    public let serverURL: String
    public let onOpenFullscreen: () -> Void

    public init(serverURL: String, onOpenFullscreen: @escaping () -> Void) {
        self.serverURL = serverURL
        self.onOpenFullscreen = onOpenFullscreen
    }

    public var body: some View {
        PlayerBarView(serverURL: serverURL, onOpenFullscreen: onOpenFullscreen)
    }
}
