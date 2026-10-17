import CoreGraphics
import QuartzCore

/// Motion of the pressed knob glass on iOS 27: it trails the finger on a spring
/// and stretches along its motion, height giving back what width gains.
struct KnobGlassMotion {
    static let followOmega: CGFloat = 17.3
    static let followDamping: CGFloat = 0.93
    static let stretchOmega: CGFloat = 8.6
    static let stretchDamping: CGFloat = 0.58
    static let stretchGain: CGFloat = 0.0031
    static let maximumStretch: CGFloat = 0.08

    /// Release swing per point of flight: the gap between two springs that set
    /// off `releaseDelay` after the flight, cut at `releaseDuration`.
    static let releaseDelay: TimeInterval = 0.06
    static let releaseFastOmega: CGFloat = 16.23
    static let releaseFastDamping: CGFloat = 0.30
    static let releaseSlowOmega: CGFloat = 7.71
    static let releaseSlowDamping: CGFloat = 0.274
    static let releaseGain: CGFloat = 0.00168
    static let releaseDuration: TimeInterval = 0.72

    var position: CGFloat
    var velocity: CGFloat = 0
    var target: CGFloat
    var omega = KnobGlassMotion.followOmega
    var damping = KnobGlassMotion.followDamping
    var drivesStretch = true
    private(set) var stretch: CGFloat = 0
    private var stretchVelocity: CGFloat = 0

    init(at value: CGFloat = 0) {
        position = value
        target = value
    }

    mutating func step(by interval: TimeInterval) {
        var remaining = CGFloat(min(max(interval, 0), 0.05))
        while remaining > 1e-6 {
            let dt = min(remaining, 1.0 / 240.0)
            let acceleration = omega * omega * (target - position) - 2 * damping * omega * velocity
            velocity += acceleration * dt
            position += velocity * dt
            advanceStretch(acceleration: acceleration, by: dt)
            remaining -= dt
        }
        stretch = min(max(stretch, -Self.maximumStretch), Self.maximumStretch)
    }

    /// Places the glass at `value` directly and drives the stretch from its
    /// velocity, smoothed over 30 ms.
    mutating func track(_ value: CGFloat, by interval: TimeInterval) {
        let span = CGFloat(min(max(interval, 1.0 / 240.0), 0.05))
        let measured = (value - position) / span
        let smoothed = velocity + (measured - velocity) * min(span / 0.03, 1)
        let acceleration = (smoothed - velocity) / span
        position = value
        target = value
        velocity = smoothed
        var remaining = span
        while remaining > 1e-6 {
            let dt = min(remaining, 1.0 / 240.0)
            advanceStretch(acceleration: acceleration, by: dt)
            remaining -= dt
        }
        stretch = min(max(stretch, -Self.maximumStretch), Self.maximumStretch)
    }

    private mutating func advanceStretch(acceleration: CGFloat, by dt: CGFloat) {
        let along = drivesStretch ? (velocity < 0 ? -acceleration : acceleration) : 0
        let stretchOmega = Self.stretchOmega
        let pull = Self.stretchGain * along
            - stretchOmega * stretchOmega * stretch
            - 2 * Self.stretchDamping * stretchOmega * stretchVelocity
        stretchVelocity += pull * dt
        stretch += stretchVelocity * dt
    }

    var isSettled: Bool {
        abs(target - position) < 0.01 && abs(velocity) < 0.05 && abs(stretch) < 0.0005 && abs(stretchVelocity) < 0.005
    }

    var scale: CGPoint {
        CGPoint(x: 1 + stretch, y: 1 - stretch)
    }

    /// Width stretch `time` seconds into a flight of `distance` points; 0 once the swing is over.
    static func releaseStretch(at time: TimeInterval, distance: CGFloat) -> CGFloat {
        let t = time - releaseDelay
        guard t > 0, time < releaseDuration else { return 0 }
        let fast = LensMorph.underdamped(
            t,
            stiffness: releaseFastOmega * releaseFastOmega,
            damping: 2 * releaseFastDamping * releaseFastOmega
        )
        let slow = LensMorph.underdamped(
            t,
            stiffness: releaseSlowOmega * releaseSlowOmega,
            damping: 2 * releaseSlowDamping * releaseSlowOmega
        )
        let swing = releaseGain * abs(distance) * (fast - slow)
        return min(max(swing, -maximumStretch), maximumStretch)
    }

    /// Stretches a layer `width` points wide by `stretch` about its centre and
    /// holds its leading edge (`direction` +1 right, -1 left) in place.
    static func anchoredStretch(_ stretch: CGFloat, width: CGFloat, direction: CGFloat) -> CATransform3D {
        let scale = CATransform3DMakeScale(1 + stretch, 1 - stretch, 1)
        let shift = -direction * stretch * width / 2
        return CATransform3DConcat(scale, CATransform3DMakeTranslation(shift, 0, 0))
    }
}
