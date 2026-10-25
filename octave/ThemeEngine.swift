//
//  ThemeEngine.swift
//  octave
//

import SwiftUI
import Observation

struct PortTheme: Codable, Sendable {
    var name: String = "Default"
    var isDark: Bool = true
    var liquidGlassEnabled: Bool = true
}

typealias OctaveTheme = PortTheme

@Observable
final class ThemeEngine: @unchecked Sendable {
    static let shared = ThemeEngine()
    var active: PortTheme = PortTheme()
    var liquidGlassEnabled: Bool = true

    func toggleTheme() {
        active.isDark.toggle()
    }
}
