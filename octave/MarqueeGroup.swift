//
//  MarqueeGroup.swift
//  octave
//

import SwiftUI

struct MarqueeGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}
