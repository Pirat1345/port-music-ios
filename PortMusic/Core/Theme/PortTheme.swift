import SwiftUI

public enum PortColors {
    public static let background = Color(red: 0.025, green: 0.028, blue: 0.035)
    public static let surface = Color(red: 0.08, green: 0.085, blue: 0.10)
    public static let surfaceGlass = Color.white.opacity(0.06)
    public static let surfaceGlassStrong = Color.white.opacity(0.10)
    public static let borderGlass = Color.white.opacity(0.14)
    public static let borderGlassFocus = Color.white.opacity(0.85)

    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.68)
    public static let textMuted = Color.white.opacity(0.42)

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
