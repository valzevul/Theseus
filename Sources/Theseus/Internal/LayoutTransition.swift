import UIKit
import QuartzCore

/// A lightweight animation transition helper for coordinating layout changes
public enum LayoutTransition {
    case immediate
    case animated(duration: TimeInterval, curve: AnimationCurve)

    public enum AnimationCurve {
        case easeInOut
        case easeIn
        case easeOut
        case linear
        case spring(damping: CGFloat, initialVelocity: CGFloat)

        var timingFunction: CAMediaTimingFunction? {
            switch self {
            case .easeInOut:
                return CAMediaTimingFunction(name: .easeInEaseOut)
            case .easeIn:
                return CAMediaTimingFunction(name: .easeIn)
            case .easeOut:
                return CAMediaTimingFunction(name: .easeOut)
            case .linear:
                return CAMediaTimingFunction(name: .linear)
            case .spring:
                return nil // Springs use UIView animation
            }
        }
    }

    public func updateFrame(view: UIView, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            view.frame = frame
            completion?(true)

        case .animated(let duration, let curve):
            performAnimation(duration: duration, curve: curve, animations: {
                view.frame = frame
            }, completion: completion)
        }
    }

    public func updateFrame(layer: CALayer, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = frame
            CATransaction.commit()
            completion?(true)

        case .animated(let duration, let curve):
            performLayerAnimation(layer: layer, keyPath: "bounds", toValue: CGRect(origin: .zero, size: frame.size), duration: duration, curve: curve)
            performLayerAnimation(layer: layer, keyPath: "position", toValue: CGPoint(x: frame.midX, y: frame.midY), duration: duration, curve: curve, completion: completion)
        }
    }

    public func updateAlpha(view: UIView, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            view.alpha = alpha
            completion?(true)

        case .animated(let duration, let curve):
            performAnimation(duration: duration, curve: curve, animations: {
                view.alpha = alpha
            }, completion: completion)
        }
    }

    public func updateAlpha(layer: CALayer, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self {
        case .immediate:
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.opacity = Float(alpha)
            CATransaction.commit()
            completion?(true)

        case .animated(let duration, let curve):
            performLayerAnimation(layer: layer, keyPath: "opacity", toValue: Float(alpha), duration: duration, curve: curve, completion: completion)
        }
    }

    public func updateTransformScale(layer: CALayer, scale: CGPoint, completion: ((Bool) -> Void)? = nil) {
        let transform = CATransform3DMakeScale(scale.x, scale.y, 1.0)

        switch self {
        case .immediate:
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.transform = transform
            CATransaction.commit()
            completion?(true)

        case .animated(let duration, let curve):
            performLayerAnimation(layer: layer, keyPath: "transform", toValue: transform, duration: duration, curve: curve, completion: completion)
        }
    }

    /// `node` is any object exposing a `view` through KVC (ASDisplayNode-like).
    public func updateFrame(node: AnyObject, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        if let view = (node as? NSObject)?.value(forKey: "view") as? UIView {
            updateFrame(view: view, frame: frame, completion: completion)
        }
    }

    // MARK: - Private Helpers

    private func performAnimation(
        duration: TimeInterval,
        curve: AnimationCurve,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)?
    ) {
        switch curve {
        case .spring(let damping, let initialVelocity):
            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: damping,
                initialSpringVelocity: initialVelocity,
                options: [],
                animations: animations,
                completion: completion
            )

        default:
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: curve.animationOptions,
                animations: animations,
                completion: completion
            )
        }
    }

    private static let animationTokenKey = "theseusLayoutTransitionToken"

    private func performLayerAnimation(
        layer: CALayer,
        keyPath: String,
        toValue: Any,
        duration: TimeInterval,
        curve: AnimationCurve,
        completion: ((Bool) -> Void)? = nil
    ) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = layer.value(forKeyPath: keyPath)
        animation.toValue = toValue
        animation.duration = duration
        animation.timingFunction = curve.timingFunction
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        // Tag the animation so the completion removes only this one; a newer transition on
        // the same key must not be snapped to its end. KVC tag, not identity: CALayer copies on add.
        let token = UUID().uuidString
        animation.setValue(token, forKey: Self.animationTokenKey)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak layer] in
            if let layer = layer,
               let current = layer.animation(forKey: keyPath),
               (current.value(forKey: Self.animationTokenKey) as? String) == token {
                layer.removeAnimation(forKey: keyPath)
            }
            completion?(true)
        }

        CATransaction.setDisableActions(true)
        layer.setValue(toValue, forKeyPath: keyPath)

        layer.add(animation, forKey: keyPath)
        CATransaction.commit()
    }
}

extension LayoutTransition.AnimationCurve {
    var animationOptions: UIView.AnimationOptions {
        switch self {
        case .easeInOut:
            return .curveEaseInOut
        case .easeIn:
            return .curveEaseIn
        case .easeOut:
            return .curveEaseOut
        case .linear:
            return .curveLinear
        case .spring:
            return []
        }
    }
}
