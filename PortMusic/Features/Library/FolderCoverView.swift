import SwiftUI

// MARK: - MacBook / macOS Style 2.5D Folder Cover (Mirrors Web FolderCover.tsx)
private struct FolderBackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 240.0
        let sy = rect.height / 240.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        var path = Path()
        // Tab + Rueckwand im 240x240 Raster analog Web BACK_PATH
        path.move(to: p(20, 186))
        path.addLine(to: p(20, 58))
        path.addQuadCurve(to: p(30, 48), control: p(20, 48))
        path.addLine(to: p(86, 48))
        path.addCurve(to: p(106, 62), control1: p(96, 48), control2: p(96, 62))
        path.addLine(to: p(206, 62))
        path.addQuadCurve(to: p(220, 76), control: p(220, 62))
        path.addLine(to: p(220, 186))
        path.addQuadCurve(to: p(206, 200), control: p(220, 200))
        path.addLine(to: p(34, 200))
        path.addQuadCurve(to: p(20, 186), control: p(20, 200))
        path.closeSubpath()
        return path
    }
}

private struct FolderFrontShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 240.0
        let sy = rect.height / 240.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        var path = Path()
        // Vorderwand im 240x240 Raster analog Web FRONT_PATH
        path.move(to: p(20, 98))
        path.addQuadCurve(to: p(34, 84), control: p(20, 84))
        path.addLine(to: p(206, 84))
        path.addQuadCurve(to: p(220, 98), control: p(220, 84))
        path.addLine(to: p(220, 186))
        path.addQuadCurve(to: p(206, 200), control: p(220, 200))
        path.addLine(to: p(34, 200))
        path.addQuadCurve(to: p(20, 186), control: p(20, 200))
        path.closeSubpath()
        return path
    }
}

private struct FolderCoverSlot {
    let xRatio: CGFloat
    let yRatio: CGFloat
    let sizeRatio: CGFloat
    let angle: Double
    let zIndex: Double
}

public struct FolderCoverView: View {
    public let folder: LibraryFolder
    public let playlists: [DiscoveryPlaylist]
    public let serverURL: String
    public var isHighlighted: Bool = false

    public init(
        folder: LibraryFolder,
        playlists: [DiscoveryPlaylist],
        serverURL: String,
        isHighlighted: Bool = false
    ) {
        self.folder = folder
        self.playlists = playlists
        self.serverURL = serverURL
        self.isHighlighted = isHighlighted
    }

    private func slots(for count: Int) -> [FolderCoverSlot] {
        switch count {
        case 1:
            return [
                FolderCoverSlot(xRatio: 0.50, yRatio: 0.34, sizeRatio: 0.42, angle: 0, zIndex: 1)
            ]
        case 2:
            return [
                FolderCoverSlot(xRatio: 0.31, yRatio: 0.36, sizeRatio: 0.36, angle: -5, zIndex: 1),
                FolderCoverSlot(xRatio: 0.69, yRatio: 0.36, sizeRatio: 0.36, angle: 5, zIndex: 2)
            ]
        default:
            return [
                FolderCoverSlot(xRatio: 0.28, yRatio: 0.37, sizeRatio: 0.32, angle: -8, zIndex: 1),
                FolderCoverSlot(xRatio: 0.50, yRatio: 0.31, sizeRatio: 0.37, angle: 0, zIndex: 3),
                FolderCoverSlot(xRatio: 0.72, yRatio: 0.37, sizeRatio: 0.32, angle: 8, zIndex: 2)
            ]
        }
    }

    private var accentTint: Color {
        switch (folder.color ?? "").lowercased() {
        case "emerald": return Color(hex: "#10b981")
        case "purple": return Color(hex: "#a855f7")
        case "blue": return Color(hex: "#3b82f6")
        case "amber": return Color(hex: "#f59e0b")
        case "rose", "red": return Color(hex: "#fc3c44")
        default: return Color.white
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let shown = Array(playlists.prefix(3))
            let layoutSlots = slots(for: shown.count)

            ZStack {
                // Bodenschatten analog SVG ellipse
                Ellipse()
                    .fill(Color.black.opacity(0.60))
                    .frame(width: w * 0.72, height: h * 0.06)
                    .blur(radius: 6)
                    .position(x: w * 0.50, y: h * 0.87)

                // Rueckwand (macOS Ordner-Tab + dunkler Verlauf)
                FolderBackShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#26262c"), Color(hex: "#18181c")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        FolderBackShape()
                            .stroke(
                                LinearGradient(
                                    colors: [accentTint.opacity(0.20), accentTint.opacity(0.03)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )

                // Aufgefaecherte Playlist-Cover: ragen oben ueber die Ordnerkante hinaus (kein Clip auf BackShape!)
                if !shown.isEmpty {
                    ZStack {
                        ForEach(Array(shown.enumerated()), id: \.offset) { idx, pl in
                            let slot = layoutSlots[idx]
                            let cardSize = min(w, h) * slot.sizeRatio
                            let popOffset: CGFloat = isHighlighted ? -h * 0.06 : 0

                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(hex: "#1f1f25"))
                                    .frame(width: cardSize, height: cardSize)

                                let fallbackCov = !pl.cover.isEmpty ? pl.cover : (pl.trackCovers?.first ?? "")
                                PortCachedAsyncImage(url: resolveCoverURL(fallbackCov, serverURL: serverURL)) { img in
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: cardSize, height: cardSize)
                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                } placeholder: {
                                    Image(systemName: "music.note")
                                        .font(.system(size: cardSize * 0.34, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.35))
                                }
                            }
                            .frame(width: cardSize, height: cardSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(0.55), radius: 5, y: 3)
                            .rotationEffect(.degrees(slot.angle), anchor: .bottom)
                            .position(x: w * slot.xRatio, y: h * slot.yRatio + popOffset)
                            .zIndex(slot.zIndex)
                        }
                    }
                    .zIndex(10)
                }

                // Schattensaum ueber der Taschen-Kante, damit Cover optisch drinnen stecken
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w * (200.0 / 240.0), height: h * (14.0 / 240.0))
                    .position(x: w * 0.50, y: h * (77.0 / 240.0))
                    .clipShape(FolderBackShape())
                    .zIndex(15)

                // Vorderwand (abgerundete Mac-Ordner-Tasche mit Lichtkante oben)
                FolderFrontShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#36363d"), Color(hex: "#202025")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        FolderFrontShape()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: accentTint.opacity(0.26), location: 0.0),
                                        .init(color: accentTint.opacity(0.07), location: 0.3),
                                        .init(color: Color.white.opacity(0.03), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .offset(y: isHighlighted ? 2 : 0)
                    .zIndex(20)
            }
            .offset(y: h * 0.11)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isHighlighted)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
