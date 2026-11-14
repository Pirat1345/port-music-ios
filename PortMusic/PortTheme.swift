import SwiftUI

enum PortColors {
    // Pure OLED black background
    static let background = Color.black

    // Glassmorphic dark surfaces matching the web login shell
    static let surface = Color(red: 18/255, green: 18/255, blue: 20/255)
    static let surfaceGlass = Color.white.opacity(0.05)
    static let surfaceElevated = Color(red: 26/255, green: 26/255, blue: 30/255)

    // Subtle white borders
    static let border = Color.white.opacity(0.12)
    static let borderHover = Color.white.opacity(0.24)
    static let borderFocused = Color.white.opacity(0.40)

    // Stylish white button tokens matching web login (<button className="bg-white text-neutral-950">)
    static let buttonBackground = Color.white
    static let buttonText = Color(red: 10/255, green: 10/255, blue: 10/255)
    static let buttonDisabled = Color.white.opacity(0.15)
    static let buttonDisabledText = Color.white.opacity(0.40)

    // Monochromatic white text hierarchy
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.45)

    // Subtle white-toned status badges (no loud green)
    static let statusSuccessBg = Color.white.opacity(0.08)
    static let statusSuccessBorder = Color.white.opacity(0.22)
    static let statusErrorBg = Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.10)
    static let statusErrorBorder = Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.28)
}

extension Font {
    // Manosque custom font matching the web login title (<h1 className="font-manosque text-5xl">)
    static func manosque(size: CGFloat) -> Font {
        return Font.custom("Manosque-Regular", size: size)
    }
}
