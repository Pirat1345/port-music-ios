import SwiftUI
import UIKit

public struct PortCachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder

        if let url = url, let cached = PortImageCache.shared.imageFromMemory(for: url) {
            _uiImage = State(initialValue: cached)
        }
    }

    public var body: some View {
        ZStack {
            if let img = uiImage {
                content(Image(uiImage: img))
                    .transition(.opacity)
            } else {
                placeholder()
                    .transition(.opacity)
            }
        }
        .task(id: url) {
            guard uiImage == nil, let url = url else { return }
            if let loaded = await PortImageCache.shared.loadImage(for: url) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.uiImage = loaded
                }
            }
        }
    }
}
