import SwiftUI

public enum PortColors {
    public static let background = Color(red: 0.025, green: 0.028, blue: 0.035)
    public static let surface = Color(red: 0.08, green: 0.085, blue: 0.10)
    public static let surfaceGlass = Color.white.opacity(0.08)
    public static let surfaceGlassStrong = Color.white.opacity(0.14)
    public static let borderGlass = Color.white.opacity(0.22)
    public static let borderGlassFocus = Color.white.opacity(0.90)

    // Klar lesbare, rein weisse und kontraststarke Schriftfarben
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white
    public static let textMuted = Color.white.opacity(0.85)

    public static let accentOrange = Color(red: 0.98, green: 0.36, blue: 0.00)
    public static let successGreen = Color(red: 0.13, green: 0.77, blue: 0.45)
    public static let errorRed = Color(red: 0.94, green: 0.27, blue: 0.27)

    public static let buttonPrimaryBg = Color.white
    public static let buttonPrimaryText = Color.black
}

extension Font {
    public static func manosque(size: CGFloat) -> Font {
        if UIFont(name: "Manosque-Regular", size: size) != nil {
            return .custom("Manosque-Regular", size: size)
        }
        if UIFont(name: "Manosque", size: size) != nil {
            return .custom("Manosque", size: size)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }
}

public struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    public func body(content: Content) -> some View {
        content
            .background(PortColors.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(PortColors.borderGlass, lineWidth: 1)
            )
    }
}

extension View {
    public func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

extension Color {
    public init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
