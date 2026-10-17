import Foundation

/// The knob turning into its glass and back. `lens` runs from the knob (0) to the held
/// glass (1) and may overshoot; `fill` is the knob's white. Retargeting keeps the velocity.
struct KnobGlassMorph {
    struct Springs: Equatable {
        var pressOmega: CGFloat
        var pressDamping: CGFloat
        var pressVelocity: CGFloat
        var releaseOmega: CGFloat
        var releaseDamping: CGFloat
        var releaseVelocity: CGFloat
        var fillOmega: CGFloat
        var fillFollowsLens = false
    }

    enum Phase {
        case idle
        case pressing
        case releasing
    }

    let springs: Springs
    private(set) var phase: Phase = .idle
    private(set) var lens: CGFloat = 0
    private(set) var lensVelocity: CGFloat = 0
    private(set) var fill: CGFloat = 1
    private var fillVelocity: CGFloat = 0
    private(set) var releasedFor: TimeInterval = 0

    init(springs: Springs) {
        self.springs = springs
    }

    mutating func press() {
        if phase == .idle {
            lens = 0
            lensVelocity = 0
        }
        lensVelocity = max(lensVelocity, springs.pressVelocity * (1 - lens))
        phase = .pressing
        fill = min(max(1 - lens, 0), 1)
        releasedFor = 0
    }

    mutating func release() {
        guard phase == .pressing else { return }
        fillVelocity = (fill > 0 && fill < 1) ? -lensVelocity : 0
        lensVelocity -= springs.releaseVelocity * lens
        phase = .releasing
        releasedFor = 0
    }

    mutating func settle() {
        phase = .idle
        lens = 0
        lensVelocity = 0
        fill = 1
        fillVelocity = 0
        releasedFor = 0
    }

    mutating func step(by interval: TimeInterval) {
        var remaining = CGFloat(min(max(interval, 0), 0.05))
        guard phase != .idle else { return }
        if phase == .releasing { releasedFor += TimeInterval(remaining) }
        while remaining > 1e-6 {
            let dt = min(remaining, 1.0 / 240.0)
            switch phase {
            case .pressing:
                let omega = springs.pressOmega
                let acceleration = omega * omega * (1 - lens) - 2 * springs.pressDamping * omega * lensVelocity
                lensVelocity += acceleration * dt
                lens += lensVelocity * dt
                fill = min(max(1 - lens, 0), 1)
            case .releasing:
                let omega = springs.releaseOmega
                let acceleration = -omega * omega * lens - 2 * springs.releaseDamping * omega * lensVelocity
                lensVelocity += acceleration * dt
                lens += lensVelocity * dt
                if springs.fillFollowsLens {
                    fill = 1 - lens
                } else {
                    let fillOmega = springs.fillOmega
                    let fillAcceleration = fillOmega * fillOmega * (1 - fill) - 2 * fillOmega * fillVelocity
                    fillVelocity += fillAcceleration * dt
                    fill += fillVelocity * dt
                }
            case .idle:
                break
            }
            remaining -= dt
        }
    }

    /// Native iOS 27 knob springs: omega in rad/s, damping ratio, and launch
    /// velocity in lengths per second.
    static let sliderSprings = Springs(
        pressOmega: 23.7,
        pressDamping: 0.707,
        pressVelocity: 25.7,
        releaseOmega: 12.53,
        releaseDamping: 0.70,
        releaseVelocity: 2.56,
        fillOmega: 15.6
    )

    static let switchSprings = Springs(
        pressOmega: 23.24,
        pressDamping: 0.627,
        pressVelocity: 17.55,
        releaseOmega: 12.56,
        releaseDamping: 0.701,
        releaseVelocity: 2.55,
        fillOmega: 15.6
    )

    static let switchSprings26: Springs = {
        var springs = switchSprings
        springs.fillFollowsLens = true
        return springs
    }()

    static let sliderSprings26: Springs = {
        var springs = sliderSprings
        springs.fillFollowsLens = true
        return springs
    }()
}
