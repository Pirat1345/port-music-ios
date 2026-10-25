//
//  NowPlayingPresenter.swift
//  octave
//

import SwiftUI
import Observation

@Observable
final class NowPlayingPresenter: @unchecked Sendable {
    var isMounted: Bool = false
    var isDragging: Bool = false
    var isFullyOpen: Bool = false
    var progress: Double = 0.0
    var cardDrop: Double = 0.0
    var springVelocity: Double = 0.0

    func handleDrag(offset: CGFloat) {
        progress = max(0.0, min(1.0, Double(offset / 400.0)))
    }
}
