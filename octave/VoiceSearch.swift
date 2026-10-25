//
//  VoiceSearch.swift
//  octave
//

import SwiftUI
import Speech

struct VoiceSearch: View {
    var body: some View {
        VStack {
            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(.purple)
            Text("Listening for song title or artist...")
                .font(.headline)
        }
    }
}
