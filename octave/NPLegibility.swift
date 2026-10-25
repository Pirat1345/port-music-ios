//
//  NPLegibility.swift
//  octave
//

import SwiftUI

struct NPLegibility {
    static func contrastColor(for luminance: Double) -> Color {
        luminance > 0.5 ? .black : .white
    }
}
