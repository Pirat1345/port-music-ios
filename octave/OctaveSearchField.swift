//
//  OctaveSearchField.swift
//  octave
//

import SwiftUI

struct OctaveSearchField: View {
    @Binding var text: String
    var onCommit: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Artists, Songs, Lyrics, and more", text: $text)
                .onSubmit(onCommit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(12)
    }
}
