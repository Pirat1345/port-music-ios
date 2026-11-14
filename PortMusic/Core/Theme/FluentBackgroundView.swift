import SwiftUI

public struct FluentBackgroundView: View {
    public init() {}

    public var body: some View {
        ZStack {
            // OLED graphite black base matching shader
            Color(red: 0.018, green: 0.022, blue: 0.028)
                .ignoresSafeArea()

            // Native Metal Silk Shader Background
            MetalSilkBackgroundView()
                .ignoresSafeArea()
        }
    }
}
