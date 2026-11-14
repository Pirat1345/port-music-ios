import SwiftUI

enum PortColors {
    static let background = Color.black
    static let surface = Color(red: 18/255, green: 18/255, blue: 20/255)
    static let surfaceElevated = Color(red: 26/255, green: 26/255, blue: 30/255)
    static let border = Color.white.opacity(0.10)
    static let borderFocused = Color.white.opacity(0.28)
    static let brand = Color(red: 99/255, green: 102/255, blue: 241/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 161/255, green: 161/255, blue: 170/255)
    static let textMuted = Color(red: 113/255, green: 113/255, blue: 122/255)
    static let success = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let successBackground = Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.12)
    static let error = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let errorBackground = Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.12)
}
