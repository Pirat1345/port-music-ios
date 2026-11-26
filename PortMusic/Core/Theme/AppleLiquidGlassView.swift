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
                        // Wichtig: clipsToBounds muss false sein, damit die optische Randbrechung (Refraktions-Saum)
                        // von UICornerConfiguration gerendert und nicht abgeschnitten wird
                        blurView.clipsToBounds = false
                    } else {
                        blurView.layer.cornerCurve = .continuous
                        blurView.clipsToBounds = true
                    }
                } else {
                    blurView.layer.cornerCurve = .continuous
                    blurView.clipsToBounds = true
                }
            } else {
                blurView.layer.cornerCurve = .continuous
                blurView.clipsToBounds = true
            }
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
            let hasCornerConfig = NSClassFromString("UICornerConfiguration") != nil && uiView.responds(to: NSSelectorFromString("setCornerConfiguration:"))
            if !hasCornerConfig {
                uiView.layer.cornerRadius = uiView.bounds.height / 2
                uiView.layer.cornerCurve = .continuous
                uiView.clipsToBounds = true
            } else {
                uiView.clipsToBounds = false
            }
        }
        if tintAlpha > 0 {
            uiView.backgroundColor = UIColor(white: style == .systemUltraThinMaterialLight ? 1.0 : 0.35, alpha: tintAlpha)
        }
    }
}

// MARK: - Native iOS 26 Liquid Glass Container & Shape Modifiers (mit sicherem Blur-Fallback)

public struct PortBottomGlassContainer<Content: View>: View {
    public let spacing: CGFloat
    public let useLiquidGlass: Bool
    @ViewBuilder public let content: () -> Content

    public init(
        spacing: CGFloat = 12,
        useLiquidGlass: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.useLiquidGlass = useLiquidGlass
        self.content = content
    }

    public var body: some View {
        #if compiler(>=6.2)
        if useLiquidGlass, #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                HStack(spacing: spacing) {
                    content()
                }
            }
        } else {
            HStack(spacing: spacing) {
                content()
            }
        }
        #else
        HStack(spacing: spacing) {
            content()
        }
        #endif
    }
}

public extension View {
    @ViewBuilder
    func portLiquidGlassCapsule(interactive: Bool = true, enabled: Bool = true) -> some View {
        #if compiler(>=6.2)
        if enabled, #available(iOS 26.0, *) {
            self
                .glassEffect(interactive ? .regular.interactive() : .regular, in: Capsule())
        } else {
            self.background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.18), location: 0.0),
                                    .init(color: Color.white.opacity(0.04), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
            )
        }
        #else
        self.background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
        )
        #endif
    }

    @ViewBuilder
    func portLiquidGlassCircle(interactive: Bool = true, enabled: Bool = true) -> some View {
        #if compiler(>=6.2)
        if enabled, #available(iOS 26.0, *) {
            self
                .glassEffect(interactive ? .regular.interactive() : .regular, in: Circle())
        } else {
            self.background(
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.18), location: 0.0),
                                    .init(color: Color.white.opacity(0.04), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
            )
        }
        #else
        self.background(
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
        )
        #endif
    }

    @ViewBuilder
    func portGlassEffectID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID, enabled: Bool = true) -> some View {
        #if compiler(>=6.2)
        if enabled, #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
