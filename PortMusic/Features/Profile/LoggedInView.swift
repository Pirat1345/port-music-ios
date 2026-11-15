import SwiftUI

/// Compatibility wrapper for ProfileSettingsView
public struct LoggedInView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    public init(user: UserProfile, serverURL: String, onLogout: @escaping () -> Void) {
        self.user = user
        self.serverURL = serverURL
        self.onLogout = onLogout
    }

    public var body: some View {
        ProfileSettingsView(user: user, serverURL: serverURL, onLogout: onLogout)
    }
}
