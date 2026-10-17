import CoreGraphics

/// Inset of a native capsule's edge inside its cap, as a share of the radius, sampled every
/// 0.05 radii from 0.6 before the cap to 0.65 into it. The shader's `CAPSULE_END_DEPTH` matches.
enum CapsuleEnds {
    static let depth: [CGFloat] = [
        0, 0, 0.00006, 0.00063, 0.00155, 0.00258, 0.00354, 0.00459, 0.00578,
        0.00724, 0.00882, 0.01080, 0.01355, 0.01611, 0.01684, 0.01655, 0.01552,
        0.01320, 0.01024, 0.00752, 0.00500, 0.00285, 0.00103, 0.00031, 0, 0
    ]

    /// Points inside the circle at `along` points past the cap's start (negative on the straight side).
    static func inset(along: CGFloat, radius: CGFloat) -> CGFloat {
        guard radius > 0 else { return 0 }
        let x = (along / radius + 0.6) / 0.05
        guard x > 0, x < 25 else { return 0 }
        let index = Int(x)
        let fraction = x - CGFloat(index)
        return radius * (depth[index] + (depth[index + 1] - depth[index]) * fraction)
    }
}
