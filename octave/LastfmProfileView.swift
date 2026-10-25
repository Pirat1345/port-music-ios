//
//  LastfmProfileView.swift
//  octave
//

import SwiftUI

struct LastfmProfileView: View {
    var body: some View {
        Form {
            Section("Last.fm Connection") {
                Text("Connect your Last.fm account to scrobble tracks automatically.")
            }
        }
        .navigationTitle("Last.fm")
    }
}
