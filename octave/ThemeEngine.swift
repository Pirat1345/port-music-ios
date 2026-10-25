//
//  ThemeEngine.swift
//  octave
//

import SwiftUI
import Observation

struct OctaveTheme: Codable, Sendable {
    var name: String = "Default"
    var isDark: Bool = true
    var liquidGlassEnabled: Bool = true
}

@Observable
final class ThemeEngine: @unchecked Sendable {
    static let shared = ThemeEngine()
    var active: OctaveTheme = OctaveTheme()
    var liquidGlassEnabled: Bool = true

    func toggleTheme() {
        active.isDark.toggle()
    }
}
