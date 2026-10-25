//
//  NotificationSettingsCard.swift
//  octave
//

import SwiftUI

struct NotificationSettingsCard: View {
    var body: some View {
        Toggle("New Music Notifications", isOn: .constant(true))
            .padding()
    }
}
