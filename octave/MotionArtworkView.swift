//
//  MotionArtworkView.swift
//  octave
//

import SwiftUI
import AVKit

struct MotionArtworkView: View {
    let videoURL: URL?

    var body: some View {
        if let videoURL {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .disabled(true)
        } else {
            EmptyView()
        }
    }
}
