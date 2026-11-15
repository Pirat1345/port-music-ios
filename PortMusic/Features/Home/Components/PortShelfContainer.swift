import SwiftUI

public struct PortShelfContainer<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}
