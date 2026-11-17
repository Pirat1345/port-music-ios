import SwiftUI
import UIKit

// MARK: - Native Apple Liquid Glass Effect (UIVisualEffectView Bridge)
// Erzeugt die authentische milchig-transiente Frost-Luminanz von Apple Music (RGB ~ 56..64)
public struct AppleLiquidGlassView: UIViewRepresentable {
    public var style: UIBlurEffect.Style
    public var tintAlpha: CGFloat

    public init(style: UIBlurEffect.Style = .systemChromeMaterialDark, tintAlpha: CGFloat = 0.40) {
        self.style = style
        self.tintAlpha = tintAlpha
    }

    public func makeUIView(context: Context) -> UIVisualEffectView {
        let effect: UIVisualEffect
        if let glassClass = NSClassFromString("UIGlassEffect") as? NSObject.Type,
           glassClass.responds(to: NSSelectorFromString("effectWithStyle:")),
           let obj = glassClass.perform(NSSelectorFromString("effectWithStyle:"), with: 0 as AnyObject)?.takeUnretainedValue() as? UIVisualEffect {
            effect = obj
        } else {
            effect = UIBlurEffect(style: style)
        }
        let blurView = UIVisualEffectView(effect: effect)
        // Authentische Apple-Luminanz: Sanfte milchige Frost-Luminanz statt Absaufen auf Schwarz
        blurView.backgroundColor = UIColor(white: 0.35, alpha: tintAlpha)
        blurView.isUserInteractionEnabled = false
        return blurView
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.backgroundColor = UIColor(white: 0.35, alpha: tintAlpha)
    }
}
