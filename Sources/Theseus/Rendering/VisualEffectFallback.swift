import UIKit

/// Glass built from UIVisualEffectView, used when Metal refraction is unavailable or turned off.
public final class VisualEffectFallbackView: UIView {

    // MARK: - Public Properties

    public var cornerRadius: CGFloat = 16 {
        didSet {
            layer.cornerRadius = cornerRadius
            blurView.layer.cornerRadius = cornerRadius
            bodyOverlay.layer.cornerRadius = cornerRadius
            tintOverlay.layer.cornerRadius = cornerRadius
            liftOverlay.layer.cornerRadius = cornerRadius
            rimLayer.cornerRadius = cornerRadius
            shadingLayer.cornerRadius = cornerRadius
            updateRimPath()
        }
    }

    public var glassTintColor: UIColor = UIColor(white: 1.0, alpha: 0.1) {
        didSet {
            applyTintColor()
        }
    }

    public var shadowOpacity: Float = 0.15 {
        didSet {
            layer.shadowOpacity = shadowOpacity
        }
    }

    public var shadowRadius: CGFloat = 12 {
        didSet {
            layer.shadowRadius = shadowRadius
        }
    }

    /// Range 0...1.
    public var rimIntensity: CGFloat = 0.6 {
        didSet {
            updateRimGradient()
        }
    }

    /// Range 0...1.
    public var innerShadowIntensity: CGFloat = 0.3 {
        didSet {
            updateInnerShadow()
        }
    }

    // MARK: - Private Views

    private let blurView: UIVisualEffectView
    private let bodyOverlay = UIView()
    private let tintOverlay = UIView()
    private let liftOverlay = UIView()
    private let shadingLayer = CAGradientLayer()
    private let rimLayer = CAGradientLayer()
    private let rimMaskLayer = CAShapeLayer()
    private let innerShadowLayer = CALayer()
    private let innerShadowMaskLayer = CAShapeLayer()

    // MARK: - Initialization

    private static func thinBlurStyle(isDark: Bool = false) -> UIBlurEffect.Style {
        isDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight
    }

    public init() {
        let blurEffect = UIBlurEffect(style: Self.thinBlurStyle())
        blurView = UIVisualEffectView(effect: blurEffect)

        super.init(frame: .zero)
        setupLayers()
    }

    public required init?(coder: NSCoder) {
        let blurEffect = UIBlurEffect(style: Self.thinBlurStyle())
        blurView = UIVisualEffectView(effect: blurEffect)

        super.init(coder: coder)
        setupLayers()
    }

    // MARK: - Setup

    private func setupLayers() {
        clipsToBounds = false
        layer.masksToBounds = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: 4)

        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = cornerRadius
        blurView.alpha = 0.7
        addSubview(blurView)

        bodyOverlay.backgroundColor = .white
        bodyOverlay.clipsToBounds = true
        bodyOverlay.layer.cornerRadius = cornerRadius
        bodyOverlay.alpha = 0
        addSubview(bodyOverlay)

        liftOverlay.backgroundColor = .white
        liftOverlay.clipsToBounds = true
        liftOverlay.layer.cornerRadius = cornerRadius
        liftOverlay.layer.compositingFilter = "linearDodgeBlendMode"
        liftOverlay.alpha = 0
        addSubview(liftOverlay)

        tintOverlay.backgroundColor = glassTintColor
        tintOverlay.clipsToBounds = true
        tintOverlay.layer.cornerRadius = cornerRadius
        addSubview(tintOverlay)

        // compositingFilter is public CALayer API, not the private CAFilter class.
        shadingLayer.colors = [
            UIColor.white.cgColor,
            UIColor(white: 0.86, alpha: 1.0).cgColor
        ]
        shadingLayer.startPoint = CGPoint(x: 0.5, y: 0)
        shadingLayer.endPoint = CGPoint(x: 0.5, y: 1)
        shadingLayer.compositingFilter = "multiplyBlendMode"
        shadingLayer.cornerRadius = cornerRadius
        shadingLayer.masksToBounds = true
        layer.addSublayer(shadingLayer)

        rimLayer.type = .conic
        rimLayer.startPoint = CGPoint(x: 0.5, y: 0)
        rimLayer.endPoint = CGPoint(x: 0.5, y: 1)
        rimLayer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        rimMaskLayer.fillColor = nil
        rimMaskLayer.lineWidth = 1.5
        rimLayer.mask = rimMaskLayer
        layer.addSublayer(rimLayer)

        innerShadowLayer.shadowColor = UIColor.black.cgColor
        innerShadowLayer.shadowOpacity = Float(innerShadowIntensity)
        innerShadowLayer.shadowRadius = 6
        innerShadowLayer.shadowOffset = CGSize(width: 0, height: 2)
        innerShadowMaskLayer.fillRule = .evenOdd
        innerShadowLayer.mask = innerShadowMaskLayer
        layer.addSublayer(innerShadowLayer)

        updateRimGradient()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()

        blurView.frame = bounds
        bodyOverlay.frame = bounds
        tintOverlay.frame = bounds
        liftOverlay.frame = bounds
        shadingLayer.frame = bounds
        rimLayer.frame = bounds
        innerShadowLayer.frame = bounds

        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath

        updateRimPath()
        updateInnerShadow()
    }

    // MARK: - Updates

    private func updateRimGradient() {
        let highlightColor = UIColor(white: 1.0, alpha: rimIntensity)
        let shadowColor = UIColor(white: 0.0, alpha: rimIntensity * 0.5)
        let transparent = UIColor.clear

        rimLayer.colors = [
            highlightColor.cgColor,
            transparent.cgColor,
            shadowColor.cgColor,
            transparent.cgColor,
            highlightColor.cgColor
        ]
    }

    private func updateRimPath() {
        let inset: CGFloat = 0.75 // half of stroke width
        let rect = bounds.insetBy(dx: inset, dy: inset)
        rimMaskLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius - inset).cgPath
    }

    private func updateInnerShadow() {
        let outerRect = bounds.insetBy(dx: -20, dy: -20)
        let outerPath = UIBezierPath(rect: outerRect)
        let innerPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        outerPath.append(innerPath.reversing())

        innerShadowMaskLayer.path = outerPath.cgPath
        innerShadowLayer.shadowPath = innerPath.cgPath
        innerShadowLayer.shadowOpacity = Float(innerShadowIntensity)
    }

    // MARK: - Public Methods

    public func updateForTraitCollection(_ traitCollection: UITraitCollection) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        blurView.effect = UIBlurEffect(style: Self.thinBlurStyle(isDark: isDark))
    }

    private var lastConfiguration: TheseusConfiguration?

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else { return }
        updateForTraitCollection(traitCollection)
        if let config = lastConfiguration {
            configure(with: config)
        }
    }

    /// Fallback analogue of the Metal backend's surface tint factor.
    private static let fallbackTintFactor: CGFloat = 0.5

    private static let shadingFactor: CGFloat = 0.6

    /// The blur already gives this backend some body, so the overlay stays subtle.
    private static let fallbackNeutralBodyScale: CGFloat = 0.34

    public func configure(with config: TheseusConfiguration) {
        lastConfiguration = config
        cornerRadius = config.shape.cornerRadius

        let spectrum = min(max(TheseusSettings.shared.tintSpectrum, 0.0), 1.0)
        let opacity = config.opacity

        var tintAlpha: CGFloat = 0
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        config.theme.tintColor.getRed(&r, green: &g, blue: &b, alpha: &tintAlpha)

        // Branch on colour alpha x intensity, as the Metal backend does: zero
        // intensity falls back to the neutral body, not to a third state.
        tintAlpha *= min(max(config.theme.tintOpacity, 0.0), 1.0)

        let isDark = traitCollection.userInterfaceStyle == .dark
        let veil = TheseusMaterialModel.veilColor(
            configuration: config,
            isDark: isDark,
            spectrum: spectrum,
            backdropLuminance: isDark ? 0.2 : 0.85
        )
        var veilWhite: CGFloat = 0, veilAlpha: CGFloat = 0
        veil.getWhite(&veilWhite, alpha: &veilAlpha)
        bodyOverlay.backgroundColor = UIColor(white: veilWhite, alpha: 1)
        bodyOverlay.alpha = min(opacity * veilAlpha * Self.fallbackNeutralBodyScale, 1.0)
        liftOverlay.alpha = 0

        if tintAlpha <= 0.001 {
            glassTintColor = .clear
            tintOverlay.alpha = 0
        } else {
            let intensity = min(max(config.theme.tintOpacity, 0.0), 1.0)
            let body = TheseusMaterialModel.bodyValue(isDark ? 0.2 : 0.85, configuration: config, isDark: isDark, spectrum: spectrum)
            let target = TheseusMaterialModel.tinted([r, g, b], alpha: 1, body: [body, body, body], model: TheseusMaterialModel.tintModel(isDark: isDark))
            glassTintColor = UIColor(red: target[0], green: target[1], blue: target[2], alpha: 1)
            tintOverlay.alpha = opacity * intensity * Self.fallbackTintFactor
        }

        shadingLayer.opacity = Float(opacity * Self.shadingFactor)
        rimLayer.opacity = Float(opacity * 0.8)
        innerShadowLayer.opacity = Float(opacity * 0.3)
    }

    // MARK: - Tint Dimming

    /// Desaturates the tint while a sheet dims the presenting hierarchy.
    public override func tintColorDidChange() {
        super.tintColorDidChange()
        applyTintColor()
    }

    private func applyTintColor() {
        if tintAdjustmentMode == .dimmed {
            tintOverlay.backgroundColor = glassTintColor.theseusDesaturated()
        } else {
            tintOverlay.backgroundColor = glassTintColor
        }
    }
}

private extension UIColor {
    /// Rec. 601 luminance, matching UIKit's dimmed tint colours.
    func theseusDesaturated() -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let gray = 0.299 * r + 0.587 * g + 0.114 * b
        return UIColor(white: gray, alpha: a)
    }
}

// MARK: - Integration with TheseusSettings

extension VisualEffectFallbackView {

    public static var shouldUseFallback: Bool {
        let settings = TheseusSettings.shared

        if settings.effectiveRefractionPolicy != .trueRefraction {
            return true
        }

        if !TheseusCapability.isMetalAvailable {
            return true
        }

        if settings.effectiveTier == .tier0 {
            return true
        }

        return false
    }
}
