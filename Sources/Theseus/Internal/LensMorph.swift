import QuartzCore
import UIKit

/// Core Animation helpers for the knob-to-lens morphs. `transform(mapping:onto:)` scales
/// about the centre then translates, which is how the per-axis `transform.*` key paths compose.
enum LensMorph {
    static func transform(mapping from: CGRect, onto to: CGRect) -> CATransform3D {
        let scale = CATransform3DMakeScale(to.width / from.width, to.height / from.height, 1.0)
        return CATransform3DConcat(scale, CATransform3DMakeTranslation(to.midX - from.midX, to.midY - from.midY, 0.0))
    }

    static func lerp(_ a: CATransform3D, _ b: CATransform3D, _ s: CGFloat) -> CATransform3D {
        var result = CATransform3DIdentity
        result.m11 = a.m11 + (b.m11 - a.m11) * s
        result.m22 = a.m22 + (b.m22 - a.m22) * s
        result.m41 = a.m41 + (b.m41 - a.m41) * s
        result.m42 = a.m42 + (b.m42 - a.m42) * s
        return result
    }

    static func spring(
        _ keyPath: String,
        from: Any,
        to: Any,
        stiffness: CGFloat,
        damping: CGFloat,
        initialVelocity: CGFloat = 0,
        duration: TimeInterval? = nil
    ) -> CASpringAnimation {
        let spring = CASpringAnimation(keyPath: keyPath)
        spring.fromValue = from
        spring.toValue = to
        spring.mass = 1
        spring.stiffness = stiffness
        spring.damping = damping
        spring.initialVelocity = initialVelocity
        spring.duration = duration ?? spring.settlingDuration
        return spring
    }

    static func spring(
        _ keyPath: String,
        from: CGFloat,
        to: CGFloat,
        omega: CGFloat,
        dampingRatio: CGFloat,
        initialVelocity: CGFloat = 0,
        duration: TimeInterval? = nil
    ) -> CASpringAnimation {
        spring(
            keyPath,
            from: from,
            to: to,
            stiffness: omega * omega,
            damping: 2 * dampingRatio * omega,
            initialVelocity: initialVelocity,
            duration: duration
        )
    }

    static func criticalSpring(_ keyPath: String, from: CGFloat, to: CGFloat, omega: CGFloat) -> CASpringAnimation {
        spring(keyPath, from: from, to: to, stiffness: omega * omega, damping: 2.0 * omega)
    }

    static func eased(_ keyPath: String, from: CGFloat, to: CGFloat, duration: TimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    static func fade(
        _ layer: CALayer,
        from: CGFloat,
        to: CGFloat,
        duration: TimeInterval,
        delay: TimeInterval = 0,
        curve: CAMediaTimingFunctionName = .linear
    ) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: curve)
        if delay > 0 {
            animation.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
            animation.fillMode = .backwards
        }
        layer.add(animation, forKey: "opacity")
        layer.opacity = Float(to)
    }

    static func animateTransform(
        _ layer: CALayer,
        from: CATransform3D,
        to: CATransform3D,
        across: (String, CGFloat, CGFloat) -> CAPropertyAnimation,
        upDown: (String, CGFloat, CGFloat) -> CAPropertyAnimation
    ) {
        layer.add(across("transform.scale.x", from.m11, to.m11), forKey: "transform.scale.x")
        layer.add(upDown("transform.scale.y", from.m22, to.m22), forKey: "transform.scale.y")
        layer.add(across("transform.translation.x", from.m41, to.m41), forKey: "transform.translation.x")
        layer.add(upDown("transform.translation.y", from.m42, to.m42), forKey: "transform.translation.y")
        layer.transform = to
    }

    static func animateTransform(
        _ layer: CALayer,
        from: CATransform3D,
        to: CATransform3D,
        scale: (String, CGFloat, CGFloat) -> CAPropertyAnimation,
        move: (String, CGFloat, CGFloat) -> CAPropertyAnimation
    ) {
        layer.add(scale("transform.scale.x", from.m11, to.m11), forKey: "transform.scale.x")
        layer.add(scale("transform.scale.y", from.m22, to.m22), forKey: "transform.scale.y")
        layer.add(move("transform.translation.x", from.m41, to.m41), forKey: "transform.translation.x")
        layer.add(move("transform.translation.y", from.m42, to.m42), forKey: "transform.translation.y")
        layer.transform = to
    }

    static func sRGBComponents(_ color: CGColor?) -> [CGFloat]? {
        guard let color = color,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: space, intent: .defaultIntent, options: nil),
              let components = converted.components,
              components.count == 4 else { return nil }
        return components
    }

    static func reset(_ layer: CALayer) {
        layer.removeAllAnimations()
        layer.transform = CATransform3DIdentity
    }

    static func criticallyDamped(_ t: TimeInterval, omega: CGFloat) -> CGFloat {
        guard t > 0 else { return 0 }
        let x = omega * CGFloat(t)
        return 1 - (1 + x) * exp(-x)
    }

    static func underdamped(_ t: TimeInterval, stiffness: CGFloat, damping: CGFloat, initialVelocity: CGFloat = 0) -> CGFloat {
        guard t > 0 else { return 0 }
        let omega = sqrt(stiffness)
        let zeta = damping / (2 * omega)
        let time = CGFloat(t)
        guard zeta < 1 else {
            return 1 - exp(-omega * time) * (1 + (omega - initialVelocity) * time)
        }
        let damped = omega * sqrt(1 - zeta * zeta)
        let envelope = exp(-zeta * omega * time)
        return 1 - envelope * (cos(damped * time) + ((zeta * omega - initialVelocity) / damped) * sin(damped * time))
    }

    static func easeOut(_ progress: CGFloat) -> CGFloat {
        bezier(progress, x1: 0.0, x2: 0.58)
    }

    static func easeInOut(_ progress: CGFloat) -> CGFloat {
        bezier(progress, x1: 0.42, x2: 0.58)
    }

    private static func bezier(_ progress: CGFloat, x1: CGFloat, x2: CGFloat) -> CGFloat {
        let p = min(max(progress, 0), 1)
        var u = p
        for _ in 0..<8 {
            let x = 3 * (1 - u) * (1 - u) * u * x1 + 3 * (1 - u) * u * u * x2 + u * u * u
            let dx = 3 * (1 - u) * (1 - u) * x1 + 6 * (1 - u) * u * (x2 - x1) + 3 * u * u * (1 - x2)
            guard dx > 1e-6 else { break }
            u = min(max(u - (x - p) / dx, 0), 1)
        }
        return u * u * (3 - 2 * u)
    }

    final class Driver {
        private var link: DisplayLinkDriver.Link?
        private var start: CFTimeInterval = 0

        func run(_ step: @escaping (TimeInterval) -> Bool) {
            stop()
            start = CACurrentMediaTime()
            link = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] _ in
                guard let self = self else { return }
                if step(CACurrentMediaTime() - self.start) {
                    self.stop()
                }
            }
        }

        func stop() {
            link?.invalidate()
            link = nil
        }
    }
}
