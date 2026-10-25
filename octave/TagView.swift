//
//  TagView.swift
//  octave
//

import SwiftUI

struct TagView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(4)
            .background(Color.purple.opacity(0.2))
            .cornerRadius(4)
    }
}
