import UIKit
import simd

struct FlexGlow: Equatable {
    var amount: CGFloat = 0
    var spotAmount: CGFloat = 0
    var spotCenter: CGPoint = .zero
    var spotRadius: CGFloat = FlexGlow.spotRadius

    static let alpha: CGFloat = 0.845
    static let spotAlpha: CGFloat = 0.284
    static let spotRadius: CGFloat = 46.5
    static let spotTravel: CGFloat = 50
    static let spotReleaseScale: CGFloat = 4
    static let spotPeak: CGFloat = 0.3942
    static let spotWidth: CGFloat = 1.1296

    static let matrix: [SIMD4<Float>] = {
        let luma = SIMD3<Float>(0.2126, 0.7152, 0.0722)
        let saturation: Float = 1.2
        return (0..<3).map { channel in
            var row = luma * (1 - saturation)
            row[channel] += saturation
            return SIMD4(row.x, row.y, row.z, 0.05)
        }
    }()

    func spotCoverage(at point: CGPoint) -> CGFloat {
        let width = Self.spotWidth * spotRadius
        guard spotAmount > 0, width > 0 else { return 0 }
        let dx = point.x - spotCenter.x, dy = point.y - spotCenter.y
        return spotAmount * Self.spotPeak * exp(-0.5 * (dx * dx + dy * dy) / (width * width))
    }

    func applied(to color: SIMD3<Float>, spot coverage: CGFloat) -> SIMD3<Float> {
        var c = color
        if amount > 0 {
            let rows = Self.matrix
            let m = SIMD3<Float>(
                (rows[0] * SIMD4(c, 1)).sum(),
                (rows[1] * SIMD4(c, 1)).sum(),
                (rows[2] * SIMD4(c, 1)).sum()
            )
            c += Float(amount) * (m - c)
        }
        c += Float(coverage) * (1 - c)
        return c
    }

    func applied(to color: UIColor, at point: CGPoint) -> UIColor {
        applied(to: color, spot: spotCoverage(at: point))
    }

    func applied(to color: UIColor, spot coverage: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let c = applied(to: SIMD3(Float(red), Float(green), Float(blue)), spot: coverage)
        let clamped = simd_clamp(c, SIMD3(repeating: 0), SIMD3(repeating: 1))
        return UIColor(red: CGFloat(clamped.x), green: CGFloat(clamped.y), blue: CGFloat(clamped.z), alpha: alpha)
    }
}
