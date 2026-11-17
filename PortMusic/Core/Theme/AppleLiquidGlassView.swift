import SwiftUI
import UIKit
import ObjectiveC

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
        if let glassClass = NSClassFromString("UIGlassEffect") as? AnyObject.Type {
            typealias EffectWithStyleFunc = @convention(c) (AnyClass, Selector, Int) -> AnyObject?
            let sel = NSSelectorFromString("effectWithStyle:")
            if let method = class_getClassMethod(glassClass, sel) {
                let imp = method_getImplementation(method)
                let fn = unsafeBitCast(imp, to: EffectWithStyleFunc.self)
                if let obj = fn(glassClass as! AnyClass, sel, 0) as? UIVisualEffect {
                    if obj.responds(to: NSSelectorFromString("setInteractive:")) {
                        _ = obj.perform(NSSelectorFromString("setInteractive:"), with: true as AnyObject)
                    }
                    effect = obj
                } else {
                    effect = UIBlurEffect(style: style)
                }
            } else {
                effect = UIBlurEffect(style: style)
            }
        } else {
            effect = UIBlurEffect(style: style)
        }

        let blurView = UIVisualEffectView(effect: effect)
        blurView.isUserInteractionEnabled = false

        if isCapsule,
           let configClass = NSClassFromString("UICornerConfiguration") as? AnyObject.Type {
            typealias CapsuleConfigFunc = @convention(c) (AnyClass, Selector) -> AnyObject?
            let sel = NSSelectorFromString("capsuleConfiguration")
            if let method = class_getClassMethod(configClass, sel) {
                let imp = method_getImplementation(method)
                let fn = unsafeBitCast(imp, to: CapsuleConfigFunc.self)
                if let config = fn(configClass as! AnyClass, sel) {
                    typealias SetCornerConfigFunc = @convention(c) (AnyObject, Selector, AnyObject) -> Void
                    let setSel = NSSelectorFromString("setCornerConfiguration:")
                    if let setMethod = class_getInstanceMethod(type(of: blurView), setSel) {
                        let setImp = method_getImplementation(setMethod)
                        let setFn = unsafeBitCast(setImp, to: SetCornerConfigFunc.self)
                        setFn(blurView, setSel, config)
                    }
                }
            }
            blurView.layer.cornerCurve = .continuous
            blurView.clipsToBounds = true
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
        if isCapsule {
            uiView.layer.cornerRadius = uiView.bounds.height / 2
            uiView.layer.cornerCurve = .continuous
            uiView.clipsToBounds = true
        }
        if tintAlpha > 0 {
            uiView.backgroundColor = UIColor(white: style == .systemUltraThinMaterialLight ? 1.0 : 0.35, alpha: tintAlpha)
        }
    }
}
