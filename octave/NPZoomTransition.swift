//
//  NPZoomTransition.swift
//  octave
//

import SwiftUI

struct NPZoomTransition: ViewModifier {
    var isExpanded: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isExpanded ? 1.0 : 0.8)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}
