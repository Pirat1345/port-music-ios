import MetalKit
import SwiftUI
import UIKit

public struct MetalSilkBackgroundView: UIViewRepresentable {
    public init() {}

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> UIView {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = MetalSilkRenderer(device: device) else {
            let fallbackView = UIView()
            fallbackView.backgroundColor = UIColor(
                red: 0.018,
                green: 0.022,
                blue: 0.028,
                alpha: 1.0
            )
            return fallbackView
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(
            red: 0.018,
            green: 0.022,
            blue: 0.028,
            alpha: 1.0
        )
        // Cap contentScaleFactor at 1.5 to match WebGL DPR cap and eliminate thermal throttling
        mtkView.contentScaleFactor = min(UIScreen.main.scale, 1.5)
        mtkView.preferredFramesPerSecond = 60

        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        mtkView.isPaused = reduceMotion
        mtkView.enableSetNeedsDisplay = reduceMotion

        mtkView.delegate = renderer
        context.coordinator.renderer = renderer
        context.coordinator.mtkView = mtkView
        context.coordinator.startObserving()

        return mtkView
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}

    public static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopObserving()
        if let mtkView = uiView as? MTKView {
            mtkView.delegate = nil
        }
    }

    public final class Coordinator: NSObject {
        var renderer: MetalSilkRenderer?
        weak var mtkView: MTKView?
        private var observer: NSObjectProtocol?

        func startObserving() {
            observer = NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, let view = self.mtkView else { return }
                let reduce = UIAccessibility.isReduceMotionEnabled
                view.isPaused = reduce
                view.enableSetNeedsDisplay = reduce
                if reduce {
                    view.setNeedsDisplay()
                }
            }
        }

        func stopObserving() {
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
                observer = nil
            }
        }

        deinit {
            stopObserving()
        }
    }
}
