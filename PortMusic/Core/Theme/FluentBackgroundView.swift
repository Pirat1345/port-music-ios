import SwiftUI

public struct FluentBackgroundView: View {
    @State private var animateBlobs: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Basis: Tiefes Graphit-Schwarz passend zum Web-Shader
            Color(red: 0.02, green: 0.025, blue: 0.035)
                .ignoresSafeArea()

            // Schwebende organische Seiden- und Lichtquellen
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                ZStack {
                    // Blob 1: Gedämpftes Indigo / Slate (oben links nach Mitte)
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.18, green: 0.22, blue: 0.50).opacity(0.45),
                                    Color(red: 0.10, green: 0.12, blue: 0.28).opacity(0.15),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: w * 0.45
                            )
                        )
                        .frame(width: w * 0.9, height: w * 0.9)
                        .offset(
                            x: animateBlobs ? -w * 0.15 : -w * 0.05,
                            y: animateBlobs ? -h * 0.10 : -h * 0.02
                        )
                        .scaleEffect(animateBlobs ? 1.08 : 0.95)

                    // Blob 2: Port Music Marken-Orange Akzent (sanft pulsierend in der Mitte rechts)
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.98, green: 0.36, blue: 0.00).opacity(0.22),
                                    Color(red: 0.85, green: 0.25, blue: 0.00).opacity(0.08),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 10,
                                endRadius: w * 0.40
                            )
                        )
                        .frame(width: w * 0.85, height: w * 0.85)
                        .offset(
                            x: animateBlobs ? w * 0.18 : w * 0.08,
                            y: animateBlobs ? h * 0.08 : h * 0.18
                        )
                        .scaleEffect(animateBlobs ? 0.94 : 1.06)

                    // Blob 3: Kühle Meeresblau / Cyan-Lichtwelle (unten links)
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.08, green: 0.32, blue: 0.45).opacity(0.35),
                                    Color(red: 0.05, green: 0.18, blue: 0.28).opacity(0.12),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: w * 0.45
                            )
                        )
                        .frame(width: w * 0.95, height: w * 0.95)
                        .offset(
                            x: animateBlobs ? -w * 0.18 : -w * 0.08,
                            y: animateBlobs ? h * 0.25 : h * 0.15
                        )
                        .scaleEffect(animateBlobs ? 1.05 : 0.92)

                    // Blob 4: Subtiler Seidenglanz (heller Schein)
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 5,
                                endRadius: w * 0.35
                            )
                        )
                        .frame(width: w * 0.7, height: w * 0.7)
                        .offset(
                            x: animateBlobs ? w * 0.05 : -w * 0.08,
                            y: animateBlobs ? -h * 0.05 : h * 0.05
                        )
                }
                .blur(radius: 65)
            }
            .ignoresSafeArea()

            // Vignette: Dunkelt Ränder ab für maximalen Kontrast der Glass-Karten
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.40),
                    Color.black.opacity(0.85)
                ]),
                center: .center,
                startRadius: 180,
                endRadius: 550
            )
            .ignoresSafeArea()

            // Subtile Glassmorphism-Überlagerung
            Color.black.opacity(0.20)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 9.0).repeatForever(autoreverses: true)) {
                animateBlobs = true
            }
        }
    }
}
