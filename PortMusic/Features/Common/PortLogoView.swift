import SwiftUI

public struct PortLogoView: View {
    public var size: CGFloat = 64

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        Group {
            if let img = resolvedLogoImage() {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback mit Port Music Farbschema
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.55), radius: 8, x: 0, y: 4)
    }

    private func resolvedLogoImage() -> UIImage? {
        if let uiImg = UIImage(named: "PortLogo") {
            return uiImg
        }
        if let uiImg = UIImage(named: "port-logo") {
            return uiImg
        }
        if let path = Bundle.main.path(forResource: "port-logo", ofType: "png"),
           let uiImg = UIImage(contentsOfFile: path) {
            return uiImg
        }
        if let path = Bundle.main.path(forResource: "port-logo-512", ofType: "png"),
           let uiImg = UIImage(contentsOfFile: path) {
            return uiImg
        }
        return nil
    }
}
