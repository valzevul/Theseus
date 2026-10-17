import UIKit

struct NativeLens26: Equatable {
    struct Highlight: Equatable {
        var angle: CGFloat
        var spread: CGFloat
        var amount: CGFloat
        var curvature: CGFloat
        var height: CGFloat = 1
        var matrix: [SIMD4<Float>]

        var key: SIMD2<Float> {
            SIMD2(Float(-cos(angle)), Float(sin(angle)))
        }

        var remap: Float {
            Float(1 / max(amount, 1e-3) - 2)
        }
    }

    var blurRadius: CGFloat = 2
    var blurDistances: SIMD4<Float> = SIMD4(-10, 0, 0, 0)
    var blurOpacities: SIMD4<Float> = SIMD4(0, 0.25, 0.6, 0.8)
    var faceBlack: CGFloat = 0.1
    var faceWhite: CGFloat = 1
    var faceSaturation: CGFloat = 1
    var holdingWhite: CGFloat = 0.97
    var holdingStart: CGFloat = -2.0 / 3.0
    var holdingEnd: CGFloat = -1.0 / 3.0
    var innerShadowOpacity: CGFloat = 0.12
    var innerShadowRadius: CGFloat = 3
    var innerShadowOffset: CGFloat = 7
    var aberration: CGFloat
    var aberrationAngle: CGFloat = -.pi / 12
    var aberrationOffset: CGFloat
    var edgeStart: CGFloat
    var edgeEnd: CGFloat = 0
    var highlights: [Highlight]
    var shadowFill: SIMD3<Float>
    var shadowOpacity: CGFloat = 0.18
    var shadowRadius: CGFloat = 8
    var shadowOffset: CGFloat = 7
    var shadowFaceOpacity: CGFloat = 1.08
    var baseHeight: CGFloat = 0

    var shadowReach: CGPoint {
        CGPoint(x: 2 * shadowRadius, y: shadowOffset + 2 * shadowRadius)
    }

    static func knob(height: CGFloat, tint: UIColor, traits: UITraitCollection) -> NativeLens26 {
        let isDark = traits.userInterfaceStyle == .dark
        let rgba = components(of: tint, traits: traits)
        return NativeLens26(
            aberration: height / 19,
            aberrationOffset: 5 * height / 9,
            edgeStart: -height / 5,
            highlights: [
                Highlight(angle: -.pi / 4, spread: .pi / 2, amount: 0.5, curvature: 1, matrix: tintMatrix(rgba)),
                Highlight(angle: 3 * .pi / 4, spread: 200 * .pi / 180, amount: 0.25, curvature: 1, matrix: isDark ? fillMatrixDark : fillMatrixLight)
            ],
            shadowFill: shadowFill(rgba)
        )
    }

    static func tabLens(height: CGFloat, traits: UITraitCollection) -> NativeLens26 {
        let isDark = traits.userInterfaceStyle == .dark
        let matrix = isDark ? fillMatrixDark : fillMatrixLight
        return NativeLens26(
            blurRadius: 0,
            blurOpacities: .zero,
            faceBlack: 0,
            aberration: height / 19,
            aberrationOffset: 5 * height / 9,
            edgeStart: -height / 5,
            highlights: [
                Highlight(angle: -.pi / 4, spread: .pi / 2, amount: 0.5, curvature: 0.8, matrix: matrix),
                Highlight(angle: 3 * .pi / 4, spread: .pi / 2, amount: 0.5, curvature: 0.8, matrix: matrix)
            ],
            shadowFill: .zero,
            shadowOpacity: 0.1,
            shadowFaceOpacity: 1.1114286,
            baseHeight: height
        )
    }

    static let fillMatrixLight: [SIMD4<Float>] = [
        SIMD4(1.2741, -0.7600, -0.0766, 1.1250),
        SIMD4(-0.2259, 0.7401, -0.0767, 1.1250),
        SIMD4(-0.2260, -0.7598, 1.4233, 1.1250)
    ]

    static let fillMatrixDark: [SIMD4<Float>] = [
        SIMD4(1.2874, -0.7153, -0.0721, 0.75),
        SIMD4(-0.2126, 0.7848, -0.0722, 0.75),
        SIMD4(-0.2127, -0.7151, 1.4278, 0.75)
    ]

    static func tintMatrix(_ rgba: SIMD4<Float>) -> [SIMD4<Float>] {
        let luma = SIMD3<Float>(0.2126, 0.7152, 0.0722)
        let saturation: Float = 4
        let reach = 2 - min(max(rgba.w, 0), 1)
        return (0..<3).map { channel in
            let tint = 1 - (1 - rgba[channel]) * reach
            let gain = 0.6 / (1 + tint)
            var row = luma * (1 - saturation)
            row[channel] += saturation
            row *= gain
            return SIMD4(row.x, row.y, row.z, (tint - 0.6) / (1 + tint))
        }
    }

    static func shadowFill(_ rgba: SIMD4<Float>) -> SIMD3<Float> {
        let r = rgba.x, g = rgba.y, b = rgba.z
        let high = max(r, g, b), low = min(r, g, b)
        let chroma = high - low
        let lightness = (high + low) / 2
        let saturation = chroma > 1e-6 ? chroma / (1 - abs(2 * lightness - 1)) : 0
        var hue: Float = 0
        if chroma > 1e-6 {
            if high == r {
                hue = (g - b) / chroma
            } else if high == g {
                hue = (b - r) / chroma + 2
            } else {
                hue = (r - g) / chroma + 4
            }
        }
        return hslColor(hue: hue, saturation: 0.25 * min(saturation, 1), lightness: 0.45)
    }

    private static func hslColor(hue: Float, saturation: Float, lightness: Float) -> SIMD3<Float> {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = (hue.truncatingRemainder(dividingBy: 6) + 6).truncatingRemainder(dividingBy: 6)
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let m = lightness - chroma / 2
        let rgb: SIMD3<Float>
        switch sector {
        case ..<1: rgb = SIMD3(chroma, x, 0)
        case ..<2: rgb = SIMD3(x, chroma, 0)
        case ..<3: rgb = SIMD3(0, chroma, x)
        case ..<4: rgb = SIMD3(0, x, chroma)
        case ..<5: rgb = SIMD3(x, 0, chroma)
        default: rgb = SIMD3(chroma, 0, x)
        }
        return rgb + m
    }

    static func components(of color: UIColor, traits: UITraitCollection) -> SIMD4<Float> {
        let resolved = color.resolvedColor(with: traits)
        let srgb = resolved.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) ?? resolved.cgColor
        let c = srgb.components ?? [0, 0, 0, 1]
        if c.count >= 4 {
            return SIMD4(Float(c[0]), Float(c[1]), Float(c[2]), Float(c[3]))
        }
        if c.count == 2 {
            return SIMD4(Float(c[0]), Float(c[0]), Float(c[0]), Float(c[1]))
        }
        return SIMD4(0, 0, 0, 1)
    }
}
