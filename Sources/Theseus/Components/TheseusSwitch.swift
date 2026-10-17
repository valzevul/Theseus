import UIKit
import QuartzCore

/// A Liquid Glass-styled toggle switch with smooth thumb animations.
public class TheseusSwitch: UIControl {

    /// Layout dimensions and animation timing for the switch.
    public struct Layout {
        public var trackSize = CGSize(width: 63.0, height: 28.0)
        public var thumbSize = CGSize(width: 37.0, height: 24.0)
        public var thumbInset: CGFloat = 2.0
        public var trackCornerRadius: CGFloat = 14.0
        public var thumbCornerRadius: CGFloat = 12.0
        public var transitionDuration: TimeInterval = 0.22

        /// Size of the pressed glass as drawn, rim included, in points. Fixed while dragged.
        public var glassSize = CGSize(width: 59.333, height: 39.667)
        public var glassCenterOffset = CGPoint.zero
        public var glassCornerRadius: CGFloat { glassSize.height / 2.0 }
        public var glassTransitionDuration: TimeInterval = 0.18
        /// Rubber band past either end of the track: a finger `d` points past it moves
        /// the glass `glassOverrun * r * d / (r * d + glassOverrun)`, `r` the resistance.
        public var glassOverrun: CGFloat = 12.0
        public var glassOverrunResistance: CGFloat = 0.55

        @available(*, deprecated, message: "No effect; the pressed glass keeps one width along the track.")
        public var glassStretchFactor: CGFloat = 1.0
        @available(*, deprecated, message: "No effect; the glass refracts the switch's own track.")
        public var glassPadding = CGPoint(x: 6.0, y: 6.0)
        @available(*, deprecated, message: "No effect; the glass refracts the switch's own track.")
        public var glassTrackHeight: CGFloat { trackSize.height }
        @available(*, deprecated, message: "No effect; the glass refracts the switch's own track.")
        public var glassTrackCornerRadius: CGFloat { trackSize.height / 2.0 }

        public init() {}
    }

    public var layout = Layout()

    /// Optics of the pressed glass. Changes apply live.
    public var glassMaterial: TheseusLensMaterial = .knobGlass {
        didSet {
            guard glassMaterial != oldValue else { return }
            applyGlassMaterial()
        }
    }

    public var isOn: Bool {
        get { _isOn }
        set {
            guard _isOn != newValue else { return }
            _isOn = newValue
            visuallyOn = newValue
            updateThumbPosition(animated: false)
            updateTrackColor(animated: false)
        }
    }
    private var _isOn: Bool = false

    public var onValueChanged: ((Bool) -> Void)?

    public var onTintColor: UIColor = UIColor(red: 0.259, green: 0.831, blue: 0.318, alpha: 1.0) {
        didSet {
            if onTintColor != oldValue {
                fillLayer.backgroundColor = resolvedCGColor(onTintColor)
                applyNativeLens()
            }
        }
    }

    /// Track colour in the off state; defaults to the iOS 27 `UISwitch` off track.
    public var offTintColor: UIColor = TheseusSwitch.defaultOffTintColor {
        didSet {
            if offTintColor != oldValue {
                trackLayer.backgroundColor = resolvedCGColor(offTintColor)
                applyNativeLens()
            }
        }
    }

    static let defaultOffTintColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 235.0 / 255.0, green: 235.0 / 255.0, blue: 245.0 / 255.0, alpha: 0.298)
            : UIColor(red: 60.0 / 255.0, green: 60.0 / 255.0, blue: 67.0 / 255.0, alpha: 0.298)
    }

    public var thumbTintColor: UIColor = .white {
        didSet {
            thumbLayer.backgroundColor = resolvedCGColor(thumbTintColor)
        }
    }


    private let contentView = UIView()
    private let trackLayer = SimpleLayer()
    /// Its own layer over the off track, so both capsule edges anti-alias together as native's do.
    private let fillLayer = SimpleLayer()
    private let thumbLayer = SimpleLayer()

    private var visuallyOn: Bool = false

    private var theseusView: TheseusView?
    private var glassShadowView: GlassKnobShadowView?

    private let hapticFeedback = HapticManager()

    private var pressStartX: CGFloat = 0
    private var pressStartThumbX: CGFloat = 0
    private var isPressing: Bool = false
    private var latchedDuringPress: Bool = false
    private var isLensVisible: Bool = false
    private var releaseGeneration: Int = 0
    private var trackColorLink: DisplayLinkDriver.Link?
    private var glassMotion = KnobGlassMotion()
    private var glassMorph = KnobGlassMorph(springs: KnobGlassMorph.switchSprings)
    private var glassLink: DisplayLinkDriver.Link?
    private var glassTime: CFTimeInterval = 0
    private var glassStart: CFTimeInterval = 0
    private var glassRevealed = false
    private var glassRevealTime: CFTimeInterval?
    private var releaseDirection: CGFloat = 1
    private var releaseTargetX: CGFloat = 0
    private var pressBeginsAt: CFTimeInterval?
    private var pressStartTime: CFTimeInterval = 0
    private var releaseAt: CFTimeInterval?
    private var pendingFlight = false
    private var flightAt: CFTimeInterval?
    private var flightStart: CFTimeInterval?
    private var pendingThumbX: CGFloat?
    private var pressTargetX: CGFloat = 0

    private static let glassPadding = CGPoint(x: 12.0, y: 12.0)

    /// Native iOS 27 press and release values, read from the lens layers.
    static let knobWarp: CGFloat = 50
    static let heldWarp: CGFloat = TheseusConfiguration.LensChain.knob.backdropWarp
    static let knobBlurSigma: CGFloat = 6
    static let blurSigmaPerRadius: CGFloat = 0.3
    static let shadowAppearFade: TimeInterval = 0.08
    static let revealTimeout: TimeInterval = 0.1
    static let frameInterval: TimeInterval = 1.0 / 60.0
    static let unrevealedKnobOpacity: CGFloat = 0.15
    static let releaseMoveOmega: CGFloat = 18.9
    static let releaseMoveDamping: CGFloat = 0.97
    /// Native timing of the glass around touch-down and lift.
    static let pressDelay: TimeInterval = 0.02
    static let minimumLensTime: TimeInterval = 0.18
    static let releaseLatency: TimeInterval = 0.042
    static let releaseLatency26: TimeInterval = 0.018
    /// How far the rim draws outside the frame the glass is built on, in points.
    static let glassRimOutset: CGFloat = 2.0 / 3.0
    static let glassFeather: CGFloat = 1.0 / 3.0
    private var releaseFlight: CGFloat = 0
    static let morphDuration: TimeInterval = 0.467
    /// Native's track colour ease-out after the finger lifts.
    static let trackColorDuration: TimeInterval = 0.38
    static let trackColorDelay: TimeInterval = 0.03

    private var thumbMinX: CGFloat { layout.thumbInset }
    private var thumbMaxX: CGFloat { bounds.width - layout.thumbSize.width - layout.thumbInset }
    private var thumbOffX: CGFloat { thumbMinX }
    private var thumbOnX: CGFloat { thumbMaxX }

    private var prefersReducedMotion: Bool {
        !TheseusSettings.shared.areMorphAnimationsEnabled
    }

    private var isDarkAppearance: Bool {
        traitCollection.userInterfaceStyle == .dark
    }

    private var usesIOS26Look: Bool {
        TheseusSettings.shared.effectiveGlassStyle == .iOS26
    }

    private var nativeLens: NativeLens26? {
        guard usesIOS26Look else { return nil }
        let height = usesIOS26Glass ? Self.iOS26GlassSize.height : layout.glassSize.height
        return .knob(height: height, tint: visuallyOn ? onTintColor : offTintColor, traits: traitCollection)
    }

    private var usesIOS26Glass: Bool {
        usesIOS26Look && layout.glassSize == Layout().glassSize && layout.glassCenterOffset == .zero
    }


    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupGestures()
        setupAccessibility()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        setupGestures()
        setupAccessibility()
    }

    private func setupLayers() {
        contentView.isUserInteractionEnabled = false
        addSubview(contentView)

        trackLayer.backgroundColor = resolvedCGColor(offTintColor)
        trackLayer.cornerRadius = layout.trackCornerRadius
        contentView.layer.addSublayer(trackLayer)
        fillLayer.backgroundColor = resolvedCGColor(onTintColor)
        fillLayer.cornerRadius = layout.trackCornerRadius
        fillLayer.opacity = _isOn ? 1 : 0
        contentView.layer.addSublayer(fillLayer)

        thumbLayer.backgroundColor = resolvedCGColor(thumbTintColor)
        thumbLayer.cornerRadius = layout.thumbCornerRadius
        thumbLayer.shadowColor = UIColor.black.cgColor
        thumbLayer.shadowOffset = CGSize(width: 0, height: 1)
        thumbLayer.shadowOpacity = 0.0
        thumbLayer.shadowRadius = 1.5
        contentView.layer.addSublayer(thumbLayer)
    }

    private func setupGestures() {
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        press.minimumPressDuration = 0
        press.allowableMovement = .greatestFiniteMagnitude
        addGestureRecognizer(press)
    }

    private func setupAccessibility() {
        isAccessibilityElement = true
        var traits: UIAccessibilityTraits = [.button]
        if #available(iOS 17.0, *) {
            traits.insert(.toggleButton)
        }
        accessibilityTraits = traits
    }

    /// Refuses ancestor pan recognizers whose touch starts on the switch, so a
    /// thumb drag wins, as `UISwitch` does.
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if isEnabled,
           gestureRecognizer is UIPanGestureRecognizer,
           gestureRecognizer.view !== self,
           bounds.contains(gestureRecognizer.location(in: self)) {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    public override var accessibilityTraits: UIAccessibilityTraits {
        get {
            var traits = super.accessibilityTraits
            if !isEnabled {
                traits.insert(.notEnabled)
            }
            return traits
        }
        set { super.accessibilityTraits = newValue }
    }

    /// "On" or "Off", localised through the package bundle; a host-assigned value wins.
    public override var accessibilityValue: String? {
        get { super.accessibilityValue ?? Self.localizedStateValue(isOn: _isOn) }
        set { super.accessibilityValue = newValue }
    }

    public override func accessibilityActivate() -> Bool {
        guard isEnabled else { return false }
        toggleFromUserInteraction()
        return true
    }

    private static func localizedStateValue(isOn: Bool) -> String {
        if isOn {
            return NSLocalizedString("On", tableName: nil, bundle: .module, value: "On", comment: "Spoken value of a switch that is on")
        }
        return NSLocalizedString("Off", tableName: nil, bundle: .module, value: "Off", comment: "Spoken value of a switch that is off")
    }

    private func resolvedCGColor(_ color: UIColor) -> CGColor {
        color.resolvedColor(with: traitCollection).cgColor
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        trackLayer.backgroundColor = resolvedCGColor(offTintColor)
        fillLayer.backgroundColor = resolvedCGColor(onTintColor)
        thumbLayer.backgroundColor = resolvedCGColor(thumbTintColor)
        applyGlassMaterial()
    }


    public override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width > 0 && bounds.height > 0 else { return }

        contentView.frame = bounds
        trackLayer.frame = bounds
        fillLayer.frame = bounds
        placeThumb(in: thumbFrame(x: _isOn ? thumbOnX : thumbOffX))
    }

    private func placeThumb(in frame: CGRect) {
        thumbLayer.bounds = CGRect(origin: .zero, size: frame.size)
        thumbLayer.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    public override var intrinsicContentSize: CGSize {
        layout.trackSize
    }


    public func setOn(_ on: Bool, animated: Bool) {
        guard _isOn != on else { return }
        _isOn = on
        visuallyOn = on
        updateThumbPosition(animated: animated)
        updateTrackColor(animated: animated)
    }


    private func thumbFrame(x: CGFloat) -> CGRect {
        CGRect(
            x: x,
            y: (bounds.height - layout.thumbSize.height) / 2.0,
            width: layout.thumbSize.width,
            height: layout.thumbSize.height
        )
    }

    private func updateThumbPosition(animated: Bool) {
        guard bounds.width > 0 && bounds.height > 0 else { return }
        setThumbX(_isOn ? thumbOnX : thumbOffX, animated: animated)
    }

    private func updateTrackColor(animated: Bool, duration: TimeInterval? = nil) {
        applyNativeLens()
        let target: Float = visuallyOn ? 1 : 0
        let current = fillLayer.presentation()?.opacity ?? fillLayer.opacity
        trackColorLink?.invalidate()
        trackColorLink = nil
        fillLayer.removeAnimation(forKey: "opacity")

        guard animated else {
            fillLayer.opacity = target
            return
        }
        let lensUp = theseusView.map { !$0.isHidden } ?? false
        if lensUp {
            crossfadeTrackFill(from: current, to: target, duration: duration ?? layout.transitionDuration)
            return
        }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = current
        animation.toValue = target
        animation.duration = duration ?? layout.transitionDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .backwards
        fillLayer.add(animation, forKey: "opacity")
        fillLayer.opacity = target
    }

    /// The capture behind the glass renders model values, so the fill is stepped
    /// through the model every frame.
    private func crossfadeTrackFill(from: Float, to: Float, duration: TimeInterval) {
        let start = CACurrentMediaTime()
        trackColorLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] _ in
            guard let self = self else { return }
            let progress = min(1.0, (CACurrentMediaTime() - start) / max(duration, 0.001))
            let eased = Float(LensMorph.easeOut(CGFloat(progress)))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.fillLayer.opacity = from + (to - from) * eased
            CATransaction.commit()
            if progress >= 1.0 {
                self.trackColorLink?.invalidate()
                self.trackColorLink = nil
            }
        }
    }


    private func setThumbX(_ x: CGFloat, animated: Bool = false) {
        guard bounds.width > 0 && bounds.height > 0 else { return }

        let newFrame = thumbFrame(x: max(thumbMinX, min(thumbMaxX, x)))

        if animated && !prefersReducedMotion {
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = thumbLayer.position
            animation.toValue = CGPoint(x: newFrame.midX, y: newFrame.midY)
            animation.duration = layout.transitionDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .backwards
            thumbLayer.add(animation, forKey: "position")
        }

        placeThumb(in: newFrame)
    }


    private var theseusSourceView: UIView? {
        if let rootView = window?.rootViewController?.view {
            return rootView
        }
        let currentSize = frame.size
        var current = superview
        var depth = 0
        let maxDepth = 5
        while let view = current, depth < maxDepth {
            let viewSize = view.frame.size
            if viewSize.width > currentSize.width && viewSize.height > currentSize.height {
                return view
            }
            current = view.superview
            depth += 1
        }
        return superview
    }

    private var theseusContainer: UIView? {
        theseusSourceView?.superview
    }

    private func convertToTheseusContainer(_ frame: CGRect) -> CGRect {
        guard let container = theseusContainer else { return frame }
        return convert(frame, to: container).pixelAligned(scale: displayScale)
    }

    private func convertToTheseusContainerExact(_ frame: CGRect) -> CGRect {
        guard let container = theseusContainer else { return frame }
        return convert(frame, to: container)
    }

    private func setupGlassIfNeeded() {
        guard theseusView == nil else { return }
        guard let container = theseusContainer,
              let sourceView = theseusSourceView else { return }

        var config = TheseusConfiguration.lens
        config.shape.padding = Self.glassPadding
        config.shape.cornerRadius = -layout.glassCornerRadius
        config.lensChain = usesIOS26Look ? .knob26 : .knob
        config.nativeLens = nativeLens
        config.edgeFeather = Self.glassFeather
        config.captureMethod = TheseusCapability.isDeviceSupported ? .layerRendering : .surfaceBased
        config.refraction.magnification = 1.0
        config.refraction.magnificationCenterY = 0
        config.refraction.intensity = 1.1
        config.refraction.interiorSharpness = 1.0
        config.edgeEffects.rimGlow = 0
        config.edgeEffects.glareIntensity = 0
        config.blur.radius = 0
        glassMaterial.apply(to: &config, isDark: isDarkAppearance, activity: 0)

        let shadow = GlassKnobShadowView()
        shadow.setAppearance(isDark: isDarkAppearance, iOS26: usesIOS26Look)
        shadow.isHidden = true
        shadow.alpha = 0
        container.addSubview(shadow)
        glassShadowView = shadow

        let glass = TheseusView(configuration: config)
        glass.sourceView = sourceView
        glass.isHidden = true
        glass.alpha = 0
        glass.isUserInteractionEnabled = false
        glass.setCaptureExcludedViews([shadow])
        container.addSubview(glass)
        theseusView = glass
    }

    private func applyGlassMaterial() {
        glassShadowView?.setAppearance(isDark: isDarkAppearance, iOS26: usesIOS26Look)
        guard let glass = theseusView else { return }
        var config = glass.configuration
        config.lensChain = usesIOS26Look ? .knob26 : .knob
        config.nativeLens = nativeLens
        glassMaterial.apply(to: &config, isDark: isDarkAppearance, activity: 0)
        glass.configuration = config
    }

    private func applyNativeLens() {
        guard let glass = theseusView else { return }
        let lens = nativeLens
        guard glass.configuration.nativeLens != lens else { return }
        glass.configuration.nativeLens = lens
    }

    private func glassFrame(forThumbX thumbX: CGFloat) -> CGRect {
        if usesIOS26Glass {
            let center = CGPoint(x: thumbX + layout.thumbSize.width / 2.0, y: bounds.midY)
            return Self.glassFrame(centeredAt: center, size: Self.iOS26GlassSize, scale: displayScale, rim: 0)
        }
        let center = CGPoint(
            x: thumbX + layout.thumbSize.width / 2.0 + layout.glassCenterOffset.x,
            y: bounds.midY + layout.glassCenterOffset.y
        )
        return Self.glassFrame(centeredAt: center, size: layout.glassSize, scale: displayScale)
    }

    static let iOS26GlassSize = CGSize(width: 58, height: 38.333)

    static func glassFrame(centeredAt center: CGPoint, size: CGSize, scale: CGFloat, rim: CGFloat = glassRimOutset) -> CGRect {
        let step = scale > 0 ? scale : 1
        let frameSize = CGSize(
            width: ((size.width - 2 * rim) * step).rounded() / step,
            height: ((size.height - 2 * rim) * step).rounded() / step
        )
        let origin = CGPoint(
            x: ((center.x - frameSize.width / 2.0) * step).rounded() / step,
            y: ((center.y - frameSize.height / 2.0) * step).rounded() / step
        )
        return CGRect(origin: origin, size: frameSize).insetBy(dx: -rim, dy: -rim)
    }

    private var displayScale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : UIScreen.main.scale
    }

    private func glassThumbX(forUnclampedThumbX x: CGFloat) -> CGFloat {
        if x > thumbMaxX {
            return thumbMaxX + Self.overrun(x - thumbMaxX, limit: layout.glassOverrun, resistance: layout.glassOverrunResistance)
        }
        if x < thumbMinX {
            return thumbMinX - Self.overrun(thumbMinX - x, limit: layout.glassOverrun, resistance: layout.glassOverrunResistance)
        }
        return x
    }

    static func overrun(_ distance: CGFloat, limit: CGFloat, resistance: CGFloat) -> CGFloat {
        guard distance > 0, limit > 0, resistance > 0 else { return 0 }
        return limit * distance * resistance / (distance * resistance + limit)
    }

    static func committedValue(isOn: Bool, visuallyOn: Bool, latched: Bool) -> Bool {
        latched ? visuallyOn : !isOn
    }

    private func setGlassFrame(_ frame: CGRect, animated: Bool, duration: TimeInterval) {
        guard let glass = theseusView else { return }
        let shadow = glassShadowView
        let apply = {
            glass.bounds = CGRect(origin: .zero, size: frame.size)
            glass.center = CGPoint(x: frame.midX, y: frame.midY)
            shadow?.place(in: frame)
        }
        if animated {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
    }

    private func setGlassScale(_ scale: CGPoint, transition: LayoutTransition, completion: ((Bool) -> Void)? = nil) {
        guard let glass = theseusView else {
            completion?(true)
            return
        }
        if let shadow = glassShadowView {
            transition.updateTransformScale(layer: shadow.layer, scale: scale)
        }
        transition.updateTransformScale(layer: glass.layer, scale: scale, completion: completion)
    }

    private func setGlassAlpha(_ alpha: CGFloat, transition: LayoutTransition) {
        guard let glass = theseusView else { return }
        if let shadow = glassShadowView {
            transition.updateAlpha(layer: shadow.layer, alpha: alpha)
        }
        transition.updateAlpha(layer: glass.layer, alpha: alpha)
    }

    /// `lens` runs from the knob (0) to the held glass (1) and may overshoot;
    /// `fill` is the knob's white.
    private func setLensState(fill: CGFloat, lens: CGFloat) {
        guard let glass = theseusView else { return }
        var config = glass.configuration
        var chain = config.lensChain ?? .knob
        let clampedFill = min(max(fill, 0), 1)
        let releasing = glassMorph.phase == .releasing
        let warp = usesIOS26Look ? (releasing ? Self.knobWarp : Self.heldWarp) : Self.knobWarp + (Self.heldWarp - Self.knobWarp) * lens
        let sigma = usesIOS26Look ? (releasing ? Self.knobBlurSigma : 0) : Self.knobBlurSigma * min(max(1 - lens, 0), 1)
        let frost: CGFloat = sigma > 0.05 ? 1 : 0
        let radius = sigma / Self.blurSigmaPerRadius
        guard config.lensFill != clampedFill || config.lensRimScale != -1 || chain.backdropWarp != warp
            || chain.frost != frost || config.blur.radius != radius else { return }
        config.lensFill = clampedFill
        config.lensRimScale = -1
        chain.backdropWarp = warp
        chain.frost = frost
        config.lensChain = chain
        config.blur.radius = radius
        glass.configuration = config
    }

    private func beginPress() {
        releaseAt = nil
        flightAt = nil
        flightStart = nil
        glassMotion.drivesStretch = true
        if isLensVisible || prefersReducedMotion {
            pressBeginsAt = nil
            showGlass()
        } else {
            pressBeginsAt = CACurrentMediaTime() + Self.pressDelay
            setupGlassIfNeeded()
            startGlassLink()
        }
    }

    private func showGlass() {
        setupGlassIfNeeded()
        guard let glass = theseusView else { return }

        let wasVisible = isLensVisible
        isLensVisible = true
        pressStartTime = CACurrentMediaTime()
        let springs = usesIOS26Look ? KnobGlassMorph.switchSprings26 : KnobGlassMorph.switchSprings
        if glassMorph.phase == .idle, glassMorph.springs != springs {
            glassMorph = KnobGlassMorph(springs: springs)
        }
        glassMorph.press()

        if let sourceView = theseusSourceView, sourceView.bounds.width > 0 {
            glass.sourceView = sourceView
        }
        glass.resumeRendering()
        glass.continuousUpdate = true
        glass.invalidateBackground()
        glass.shape.cornerRadius = -layout.glassCornerRadius
        glassMotion.omega = KnobGlassMotion.followOmega
        glassMotion.damping = KnobGlassMotion.followDamping

        if !wasVisible {
            glassMotion = KnobGlassMotion(at: pressStartThumbX)
            glassMotion.target = pressTargetX
            glassRevealed = prefersReducedMotion
            let glassLayers = [glass.layer, glassShadowView?.layer].compactMap { $0 }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for layer in glassLayers {
                LensMorph.reset(layer)
                layer.opacity = 0
            }
            glass.isHidden = false
            glassShadowView?.isHidden = false
            glassShadowView?.layer.opacity = 0
            CATransaction.commit()
            glass.onPresent = { [weak self] in
                self?.revealGlass()
            }
            glassStart = CACurrentMediaTime()
        }
        if let thumbX = pendingThumbX {
            pendingThumbX = nil
            setThumbX(thumbX)
        }
        if pendingFlight {
            pendingFlight = false
            startFlight()
        }
        if !wasVisible {
            stepGlass(by: Self.frameInterval)
            glass.layoutIfNeeded()
            glass.renderNow()
            glassTime = CACurrentMediaTime()
        }
        startGlassLink()
    }

    private func revealGlass() {
        guard let glass = theseusView, !glassRevealed, isLensVisible else { return }
        glassRevealed = true
        glass.onPresent = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glass.layer.opacity = 1
        thumbLayer.transform = CATransform3DIdentity
        thumbLayer.opacity = 0
        CATransaction.commit()
        glassRevealTime = CACurrentMediaTime()
    }

    private func startGlassLink() {
        guard glassLink == nil else { return }
        glassTime = CACurrentMediaTime()
        glassLink = DisplayLinkDriver.shared.add { [weak self] _ in
            guard let self = self else { return }
            let now = CACurrentMediaTime()
            let interval = now - self.glassTime
            self.glassTime = now
            self.stepGlass(by: interval)
        }
    }

    private func stopGlassLink() {
        glassLink?.invalidate()
        glassLink = nil
    }

    private func stepGlass(by interval: TimeInterval) {
        let now = CACurrentMediaTime()
        if let begins = pressBeginsAt, now >= begins {
            pressBeginsAt = nil
            showGlass()
            return
        }
        if let at = flightAt, now >= at {
            flightAt = nil
            startFlight()
        }
        if let at = releaseAt, now >= at, glassMorph.phase == .pressing {
            releaseAt = nil
            glassMorph.release()
        }
        guard glassMorph.phase != .idle else {
            if pressBeginsAt == nil, releaseAt == nil, flightAt == nil, !isPressing {
                stopGlassLink()
            }
            return
        }
        glassMorph.step(by: interval)
        glassMotion.step(by: interval)
        if !glassRevealed, glassMorph.phase == .pressing, CACurrentMediaTime() - glassStart >= Self.revealTimeout {
            revealGlass()
        }
        let lens = glassMorph.lens
        let fill = glassMorph.fill

        if glassMorph.phase == .releasing, glassMorph.releasedFor >= Self.morphDuration {
            if isLensVisible {
                landGlass()
            }
            let swing = flightSwing(at: now)
            let settled = glassMorph.releasedFor >= KnobGlassMotion.releaseDuration
                && flightStart.map { now - $0 >= KnobGlassMotion.releaseDuration } ?? true
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            thumbLayer.transform = settled
                ? CATransform3DIdentity
                : KnobGlassMotion.anchoredStretch(swing, width: layout.thumbSize.width, direction: releaseDirection)
            CATransaction.commit()
            if settled {
                glassMorph.settle()
                stopGlassLink()
            }
            return
        }

        guard let glass = theseusView else { return }
        let glassLocal = glassFrame(forThumbX: glassMotion.position)
        let frame = convertToTheseusContainerExact(glassLocal)
        let knobScale = CGPoint(x: layout.thumbSize.width / frame.width, y: layout.thumbSize.height / frame.height)
        let scale = CGPoint(x: knobScale.x + (1 - knobScale.x) * lens, y: knobScale.y + (1 - knobScale.y) * lens)
        let swing = flightSwing(at: now)
        let stretch = glassMotion.stretch + swing
        let shift = -releaseDirection * swing * frame.width * scale.x / 2
        let transform = CATransform3DConcat(
            CATransform3DMakeScale(scale.x * (1 + stretch), scale.y * (1 - stretch), 1),
            CATransform3DMakeTranslation(shift, 0, 0)
        )
        let shadowOpacity: Float
        if let revealed = glassRevealTime {
            shadowOpacity = Float((1 - fill) * min(CGFloat(CACurrentMediaTime() - revealed) / CGFloat(Self.shadowAppearFade), 1))
        } else {
            shadowOpacity = 0
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setGlassFrame(frame, animated: false, duration: 0)
        glass.layer.transform = transform
        glassShadowView?.layer.transform = transform
        glassShadowView?.layer.opacity = glassRevealed ? shadowOpacity : 0
        if !glassRevealed {
            let grow = LensMorph.transform(mapping: thumbLayer.frame, onto: glassLocal)
            thumbLayer.transform = LensMorph.lerp(CATransform3DIdentity, grow, lens)
            thumbLayer.opacity = Float(max(fill, Self.unrevealedKnobOpacity))
        }
        CATransaction.commit()
        setLensState(fill: fill, lens: lens)
    }

    private func flightSwing(at time: CFTimeInterval) -> CGFloat {
        guard let start = flightStart else { return 0 }
        return KnobGlassMotion.releaseStretch(at: time - start, distance: releaseFlight)
    }

    private func startFlight() {
        releaseFlight = releaseTargetX - glassMotion.position
        releaseDirection = releaseFlight < 0 ? -1 : 1
        glassMotion.omega = Self.releaseMoveOmega
        glassMotion.damping = Self.releaseMoveDamping
        glassMotion.target = releaseTargetX
        glassMotion.drivesStretch = false
        flightStart = CACurrentMediaTime()
    }

    private func landGlass() {
        isLensVisible = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        thumbLayer.transform = CATransform3DIdentity
        thumbLayer.opacity = 1
        if let glass = theseusView {
            glass.onPresent = nil
            LensMorph.reset(glass.layer)
            glass.continuousUpdate = false
            glass.pauseRendering()
            glass.isHidden = true
        }
        if let shadow = glassShadowView {
            LensMorph.reset(shadow.layer)
            shadow.layer.opacity = 0
            shadow.isHidden = true
        }
        CATransaction.commit()
        glassRevealTime = nil
        setLensState(fill: 0, lens: 1)
    }

    private func hideGlass(
        toThumbFrame targetThumbFrameLocal: CGRect,
        animated: Bool,
        duration: TimeInterval? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let glass = theseusView, isLensVisible else {
            completion?()
            return
        }

        isLensVisible = false
        glass.continuousUpdate = false

        let animated = animated && !prefersReducedMotion
        let effectiveDuration = duration ?? layout.glassTransitionDuration
        let transition: LayoutTransition = animated
            ? .animated(duration: effectiveDuration, curve: .easeInOut)
            : .immediate

        let finalFrameLocal = glassFrame(forThumbX: targetThumbFrameLocal.origin.x)
        setGlassFrame(convertToTheseusContainer(finalFrameLocal), animated: animated, duration: effectiveDuration)
        setGlassAlpha(0.0, transition: transition)
        transition.updateAlpha(layer: thumbLayer, alpha: 1.0)

        let scale = CGPoint(
            x: targetThumbFrameLocal.width / finalFrameLocal.width,
            y: targetThumbFrameLocal.height / finalFrameLocal.height
        )
        setGlassScale(scale, transition: transition) { [weak self] _ in
            guard let self = self else { return }
            guard !self.isLensVisible else {
                completion?()
                return
            }
            glass.layer.transform = CATransform3DIdentity
            self.glassShadowView?.layer.transform = CATransform3DIdentity
            glass.pauseRendering()
            glass.isHidden = true
            self.glassShadowView?.isHidden = true
            completion?()
        }
    }

    private func teardownGlass() {
        stopGlassLink()
        glassMorph.settle()
        glassRevealTime = nil
        pressBeginsAt = nil
        releaseAt = nil
        flightAt = nil
        pendingFlight = false
        flightStart = nil
        if let thumbX = pendingThumbX {
            pendingThumbX = nil
            setThumbX(thumbX)
        }
        theseusView?.pauseRendering()
        theseusView?.removeFromSuperview()
        theseusView = nil
        glassShadowView?.removeFromSuperview()
        glassShadowView = nil
        trackColorLink?.invalidate()
        trackColorLink = nil
        thumbLayer.transform = CATransform3DIdentity
        thumbLayer.opacity = 1.0
        isLensVisible = false
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            teardownGlass()
        } else {
            MetalContext.prewarm()
        }
    }

    private func toggleFromUserInteraction() {
        let newValue = !_isOn
        _isOn = newValue
        visuallyOn = newValue
        updateTrackColor(animated: true)
        hapticFeedback.impact(.light)
        onValueChanged?(newValue)
        sendActions(for: .valueChanged)

        let finalThumbFrame = thumbFrame(x: newValue ? thumbOnX : thumbOffX)
        setThumbX(finalThumbFrame.origin.x, animated: !prefersReducedMotion)
    }

    private func latch(on: Bool) {
        visuallyOn = on
        latchedDuringPress = true
        updateTrackColor(animated: true)
        hapticFeedback.impact(.light)
    }

    @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)

        switch gesture.state {
        case .began:
            pressBegan(at: location)
        case .changed:
            pressMoved(to: location)
        case .ended:
            finishPress(cancelled: false)
        case .cancelled, .failed:
            finishPress(cancelled: true)
        default:
            break
        }
    }

    private func pressBegan(at location: CGPoint) {
        guard isEnabled else { return }
        isPressing = true
        latchedDuringPress = false
        releaseGeneration += 1
        thumbLayer.removeAllAnimations()
        pressStartX = location.x
        pressStartThumbX = thumbLayer.frame.origin.x
        pressTargetX = pressStartThumbX
        beginPress()
    }

    private func pressMoved(to location: CGPoint) {
        guard isPressing else { return }
        let unclampedX = pressStartThumbX + (location.x - pressStartX)
        let clampedX = min(max(unclampedX, thumbMinX), thumbMaxX)
        setThumbX(clampedX)
        if clampedX >= thumbMaxX, !visuallyOn {
            latch(on: true)
        } else if clampedX <= thumbMinX, visuallyOn {
            latch(on: false)
        }
        pressTargetX = glassThumbX(forUnclampedThumbX: unclampedX)
        glassMotion.target = pressTargetX
    }

    @_spi(Scripting) public func scriptedTouchBegan(at location: CGPoint) {
        pressBegan(at: location)
    }

    @_spi(Scripting) public func scriptedTouchMoved(to location: CGPoint) {
        pressMoved(to: location)
    }

    @_spi(Scripting) public func scriptedTouchEnded() {
        finishPress(cancelled: false)
    }

    private func finishPress(cancelled: Bool) {
        guard isPressing else { return }
        isPressing = false

        let newValue = cancelled
            ? _isOn
            : Self.committedValue(isOn: _isOn, visuallyOn: visuallyOn, latched: latchedDuringPress)
        let changed = newValue != _isOn
        _isOn = newValue
        visuallyOn = newValue

        if changed {
            hapticFeedback.impact(.light)
            onValueChanged?(newValue)
            sendActions(for: .valueChanged)
        }

        let finalThumbFrame = thumbFrame(x: newValue ? thumbOnX : thumbOffX)

        if cancelled || prefersReducedMotion {
            stopGlassLink()
            glassMorph.settle()
            glassRevealTime = nil
            pressBeginsAt = nil
            releaseAt = nil
            flightAt = nil
            pendingFlight = false
            pendingThumbX = nil
            flightStart = nil
            updateTrackColor(animated: true)
            setThumbX(finalThumbFrame.origin.x, animated: true)
            hideGlass(toThumbFrame: finalThumbFrame, animated: true, duration: layout.transitionDuration)
            return
        }

        releaseGeneration += 1
        let generation = releaseGeneration
        let now = CACurrentMediaTime()
        releaseTargetX = finalThumbFrame.origin.x
        if let pressedAt = pressBeginsAt {
            pendingThumbX = finalThumbFrame.origin.x
            pendingFlight = true
            releaseAt = pressedAt + Self.minimumLensTime
        } else {
            setThumbX(finalThumbFrame.origin.x, animated: false)
            let latency = usesIOS26Look ? Self.releaseLatency26 : Self.releaseLatency
            flightAt = now + latency
            releaseAt = max(now + latency, pressStartTime + Self.minimumLensTime)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.trackColorDelay) { [weak self] in
            guard let self = self, generation == self.releaseGeneration else { return }
            self.updateTrackColor(animated: true, duration: Self.trackColorDuration)
        }
    }
}
