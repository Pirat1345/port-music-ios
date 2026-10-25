//
//  NPCoverEdge.swift
//  octave
//

import SwiftUI

struct NPCoverEdge: View {
    var body: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
