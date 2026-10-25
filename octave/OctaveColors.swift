//
//  OctaveColors.swift
//  octave / Port Music
//

import SwiftUI

extension Color {
    // Port Music Design Tokens (DESIGN_GUIDELINES.md)
    static let portBrand = Color(red: 29 / 255.0, green: 185 / 255.0, blue: 84 / 255.0) // #1db954
    static let portBrandLight = Color(red: 30 / 255.0, green: 215 / 255.0, blue: 96 / 255.0) // #1ed760
    static let portBackground = Color(red: 10 / 255.0, green: 10 / 255.0, blue: 10 / 255.0) // #0a0a0a
    static let portSurface = Color(red: 18 / 255.0, green: 18 / 255.0, blue: 18 / 255.0) // #121212
    static let portSurfaceElevated = Color(red: 24 / 255.0, green: 24 / 255.0, blue: 24 / 255.0) // #181818
    static let portBorder = Color(white: 1.0, opacity: 0.08) // rgba(255,255,255,0.08)
    static let portTextSecondary = Color(red: 161 / 255.0, green: 161 / 255.0, blue: 170 / 255.0) // #a1a1aa
    static let portTextMuted = Color(red: 113 / 255.0, green: 113 / 255.0, blue: 122 / 255.0) // #71717a

    static var octaveAccent: Color {
        portBrand
    }
}
