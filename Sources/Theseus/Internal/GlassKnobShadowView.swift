import UIKit

/// The shadow under a pressed knob glass: a blurred ring the width of the rim zone,
/// shifted down as native's is.
final class GlassKnobShadowView: UIView {
    static let opacityLight: Float = 0.09
    static let opacityDark: Float = 0.22
    static let radius: CGFloat = 1.7
    static let offset = CGSize(width: 0, height: 9.0)
    static let ringWidth: CGFloat = 6.7

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = Self.radius
        layer.shadowOffset = Self.offset
        layer.shadowOpacity = Self.opacityLight
    }

    required init?(coder: NSCoder) {
        nil
    }

    func place(in frame: CGRect) {
        bounds = CGRect(origin: .zero, size: frame.size)
        center = CGPoint(x: frame.midX, y: frame.midY)
        layer.shadowPath = Self.ringPath(size: frame.size, ringWidth: Self.ringWidth)
    }

    func setAppearance(isDark: Bool, iOS26: Bool = false) {
        layer.shadowOpacity = iOS26 ? 0 : (isDark ? Self.opacityDark : Self.opacityLight)
        layer.shadowRadius = Self.radius
        layer.shadowOffset = Self.offset
    }

    static func ringPath(size: CGSize, ringWidth: CGFloat) -> CGPath {
        let outer = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(roundedRect: outer, cornerRadius: size.height / 2.0)
        let inner = outer.insetBy(dx: ringWidth, dy: ringWidth)
        if inner.width > 0, inner.height > 0 {
            path.append(UIBezierPath(roundedRect: inner, cornerRadius: inner.height / 2.0).reversing())
        }
        return path.cgPath
    }
}
