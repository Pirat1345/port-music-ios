import SwiftUI
import UIKit

// MARK: - Native Apple Liquid Glass Effect (UIVisualEffectView Bridge)
// Erzeugt die authentische milchig-transiente Frost-Luminanz von Apple Music mit echter Linsenbrechung
public struct AppleLiquidGlassView: UIViewRepresentable {
    public var style: UIBlurEffect.Style
    public var tintAlpha: CGFloat
    public var isCapsule: Bool

    public init(style: UIBlurEffect.Style = .systemChromeMaterialDark, tintAlpha: CGFloat = 0.40, isCapsule: Bool = false) {
        self.style = style
        self.tintAlpha = tintAlpha
        self.isCapsule = isCapsule
    }

    public func makeUIView(context: Context) -> UIVisualEffectView {
        let effect: UIVisualEffect
        if let glassClass = NSClassFromString("UIGlassEffect") as? NSObject.Type,
           glassClass.responds(to: NSSelectorFromString("effectWithStyle:")),
           let obj = glassClass.perform(NSSelectorFromString("effectWithStyle:"), with: 0 as AnyObject)?.takeUnretainedValue() as? UIVisualEffect {
            if obj.responds(to: NSSelectorFromString("setInteractive:")) {
                _ = obj.perform(NSSelectorFromString("setInteractive:"), with: true as AnyObject)
            }
            effect = obj
        } else {
            effect = UIBlurEffect(style: style)
        }
        let blurView = UIVisualEffectView(effect: effect)
        blurView.isUserInteractionEnabled = false

        if isCapsule,
           let configClass = NSClassFromString("UICornerConfiguration") as? NSObject.Type,
           configClass.responds(to: NSSelectorFromString("capsuleConfiguration")),
           blurView.responds(to: NSSelectorFromString("setCornerConfiguration:")),
           let config = configClass.perform(NSSelectorFromString("capsuleConfiguration"))?.takeUnretainedValue() {
            _ = blurView.perform(NSSelectorFromString("setCornerConfiguration:"), with: config)
            blurView.clipsToBounds = false
        } else if isCapsule {
            blurView.layer.cornerCurve = .continuous
            blurView.clipsToBounds = true
        }

        if tintAlpha > 0 {
            blurView.backgroundColor = UIColor(white: style == .systemUltraThinMaterialLight ? 1.0 : 0.35, alpha: tintAlpha)
        }
        return blurView
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        if isCapsule,
           let configClass = NSClassFromString("UICornerConfiguration") as? NSObject.Type,
           configClass.responds(to: NSSelectorFromString("capsuleConfiguration")),
           uiView.responds(to: NSSelectorFromString("setCornerConfiguration:")),
           let config = configClass.perform(NSSelectorFromString("capsuleConfiguration"))?.takeUnretainedValue() {
            _ = uiView.perform(NSSelectorFromString("setCornerConfiguration:"), with: config)
            uiView.clipsToBounds = false
        } else if isCapsule {
            uiView.layer.cornerRadius = uiView.bounds.height / 2
            uiView.layer.cornerCurve = .continuous
            uiView.clipsToBounds = true
        }
        if tintAlpha > 0 {
            uiView.backgroundColor = UIColor(white: style == .systemUltraThinMaterialLight ? 1.0 : 0.35, alpha: tintAlpha)
        }
    }
}
