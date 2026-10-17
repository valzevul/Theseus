import UIKit
import QuartzCore

/// A Liquid Glass-styled slider with spring-based morphing animations.
public final class TheseusSlider: UIControl {

    /// Layout and animation parameters for the slider.
    public struct Layout {
        public var trackHeight: CGFloat = 6.0
        @available(*, deprecated, message: "Unused; the slider derives its horizontal margins from knobSize.")
        public var trackMargin: CGFloat = 14.0
        @available(*, deprecated, message: "Unused; the slider derives its horizontal margins from knobSize.")
        public var internalMargin: CGFloat = 6.0
        public var dotSize: CGFloat = 3.5
        public var knobSize: CGSize = CGSize(width: 37.0, height: 24.0)
        public var edgeFactor: CGFloat { knobSize.width / 4.0 }

        /// Size of the pressed glass as drawn, rim included, in points. Fixed while dragged.
        public var glassSize = CGSize(width: 58.683, height: 38.333)
        public var glassCenterOffset = CGPoint.zero
        /// Rubber band past either end of the track: a knob driven `d` points past it moves
        /// the glass `glassOverrun * r * d / (r * d + glassOverrun)`, `r` the resistance.
        public var glassOverrun: CGFloat = 13.4
        public var glassOverrunResistance: CGFloat = 0.70
        @available(*, deprecated, message: "No effect; the pressed glass has the fixed glassSize.")
        public var expandScale: CGFloat = 1.4
        /// Duration of the knob and track-fill animation used by `setValue(_:animated:)`.
        public var transitionDuration: TimeInterval = 0.18
        @available(*, deprecated, message: "Unused; the lens padding is fixed by the slider's glass configuration.")
        public var glassPadding: CGPoint = CGPoint(x: 0.0, y: 0.0)

        public var viscosityForward: CGFloat = 0.6
        public var viscosityBackward: CGFloat { 1.0 - viscosityForward }
        public var snapThreshold: CGFloat = 0.6

        public init() {}
    }

    public var layout = Layout()

    public var minimumValue: CGFloat = 0.0 {
        didSet {
            if minimumValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var maximumValue: CGFloat = 1.0 {
        didSet {
            if maximumValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var startValue: CGFloat = 0.0 {
        didSet {
            if startValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var lowerBoundValue: CGFloat = 0.0 {
        didSet {
            if lowerBoundValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public private(set) var value: CGFloat = 0.0

    public var positionsCount: Int = 0 {
        didSet {
            if positionsCount != oldValue {
                updatePositionDots()
                setNeedsLayout()
            }
        }
    }

    public var disableSnapToPositions: Bool = false

    public var markPositions: Bool = true {
        didSet {
            if markPositions != oldValue {
                updatePositionDots()
                setNeedsLayout()
            }
        }
    }

    public var dotSize: CGFloat {
        get { layout.dotSize }
        set {
            if layout.dotSize != newValue {
                layout.dotSize = newValue
                updatePositionDots()
                setNeedsLayout()
            }
        }
    }

    /// Unfilled track colour; defaults to the iOS 27 `UISlider` track in both appearances.
    public var backColor: UIColor = TheseusSlider.defaultTrackColor {
        didSet {
            updateColors()
        }
    }

    public var trackColor: UIColor = UIColor(white: 0.4, alpha: 1.0) {
        didSet {
            updateColors()
        }
    }

    public var lowerBoundTrackColor: UIColor? {
        didSet {
            updateColors()
        }
    }

    public var lineSize: CGFloat {
        get { layout.trackHeight }
        set {
            if layout.trackHeight != newValue {
                layout.trackHeight = newValue
                setNeedsLayout()
            }
        }
    }

    public var trackCornerRadius: CGFloat = 3.0 {
        didSet {
            if trackCornerRadius != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var knobSize: CGSize {
        get { layout.knobSize }
        set {
            if layout.knobSize != newValue {
                layout.knobSize = newValue
                updateKnobImage()
                cachedMetrics = nil
                setNeedsLayout()
            }
        }
    }

    public var knobColor: UIColor = .white {
        didSet {
            if knobColor != oldValue {
                updateKnobImage()
            }
        }
    }

    public var limitValueChangedToLatestState: Bool = false

    public private(set) var knobStartedDragging: Bool = false

    public var onInteractionBegan: (() -> Void)?

    public var onInteractionEnded: (() -> Void)?

    private let trackClipLayer = SimpleLayer()
    private let trackBackgroundLayer = SimpleLayer()
    private let trackForegroundLayer = SimpleLayer()
    static let defaultTrackColor = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.10)
            : UIColor(white: 0.0, alpha: 0.10)
    }

    /// Optics of the pressed glass. Changes apply live.
    public var glassMaterial: TheseusLensMaterial = .sliderKnobGlass {
        didSet {
            guard glassMaterial != oldValue else { return }
            applyGlassMaterial()
        }
    }

    private static let glassPadding = CGPoint(x: 12.0, y: 12.0)
    private static let knobShadowPadding: CGFloat = 14.0
    static let knobVerticalOffset: CGFloat = 0.5

    private let knobContainerView = UIView()
    private let knobImageView = UIImageView()
    private var positionDotLayers: [SimpleLayer] = []

    private var knobTouchStart: CGFloat = 0
    private var knobTouchCenterStart: CGFloat = 0
    private var _isTracking: Bool = false

    private var discreteCurrentPosition: Int = 0

    private enum AnimationState {
        case idle
        case tracking
    }

    private var animationState: AnimationState = .idle

    private var theseusCenterX: CGFloat = 0
    private var releaseGeneration: Int = 0

    /// Native iOS 27 press and release values, read from the lens layers.
    static let shadowAppearFade: TimeInterval = 0.04
    static let revealTimeout: TimeInterval = 0.1
    static let frameInterval: TimeInterval = 1.0 / 60.0
    static let unrevealedKnobOpacity: CGFloat = 0.15
    static let knobWarp: CGFloat = 50
    static let knobBlurSigma: CGFloat = 6
    static let blurSigmaPerRadius: CGFloat = 0.3
    static let releaseMoveOmega: CGFloat = 18.9
    static let releaseMoveDamping: CGFloat = 0.97
    static let morphDuration: TimeInterval = 0.467
    static let pressDelay: TimeInterval = 0.02
    static let minimumLensTime: TimeInterval = 0.18
    static let releaseLatency: TimeInterval = 0.015
    static let fillColor = UIColor(white: 240.0 / 255.0, alpha: 1)

    private var displayLink: DisplayLinkDriver.Link?

    private var needsFrameUpdate: Bool = false

    private var glassMorph = KnobGlassMorph(springs: KnobGlassMorph.sliderSprings)
    private var glassMotion = KnobGlassMotion()
    private var glassLink: DisplayLinkDriver.Link?
    private var glassTime: CFTimeInterval = 0
    private var glassStart: CFTimeInterval = 0
    private var glassRevealed = false
    private var glassRevealTime: CFTimeInterval?
    private var glassVisible = false
    private var pressBeginsAt: CFTimeInterval?
    private var pressStartTime: CFTimeInterval = 0
    private var releaseAt: CFTimeInterval?
    private var flightStart: CFTimeInterval?
    private var releaseFlight: CGFloat = 0
    private var releaseDirection: CGFloat = 1
    private var releaseTargetX: CGFloat = 0
    private var pendingFlight = false
    private var flightAt: CFTimeInterval?
    private var glassOverrunOffset: CGFloat = 0

    private struct LayoutMetrics {
        let edgeMargin: CGFloat
        let totalLength: CGFloat
        let trackPadding: CGFloat
        let sideLength: CGFloat
        let knobImageSize: CGSize

        var isValid: Bool { totalLength > 0 && knobImageSize.width > 0 }
    }
    private var cachedMetrics: LayoutMetrics?

    private let hapticManager = HapticManager()

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = self
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    private var theseusView: TheseusView?
    private var glassShadowView: GlassKnobShadowView?

    private var isDarkAppearance: Bool {
        traitCollection.userInterfaceStyle == .dark
    }

    private var usesIOS26Look: Bool {
        TheseusSettings.shared.effectiveGlassStyle == .iOS26
    }

    private var usesIOS26Glass: Bool {
        usesIOS26Look && layout.glassSize == Layout().glassSize && layout.glassCenterOffset == .zero
    }

    private var glassSize: CGSize {
        usesIOS26Glass ? Self.iOS26GlassSize : layout.glassSize
    }

    private var nativeLens: NativeLens26? {
        guard usesIOS26Look else { return nil }
        return .knob(height: glassSize.height, tint: trackColor, traits: traitCollection)
    }

    static let iOS26GlassSize = CGSize(width: 57.333, height: 37)
    static let iOS26GlassOffset: CGFloat = -0.1

    private var displayScale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : UIScreen.main.scale
    }


    public override var isTracking: Bool {
        _isTracking
    }

    private var prefersReducedMotion: Bool {
        !TheseusSettings.shared.areMorphAnimationsEnabled
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false

        setupLayers()
        setupGestureRecognizers()
        updateKnobImage()
        setupAccessibility()
    }

    deinit {
        if Thread.isMainThread {
            teardownTheseus()
        } else {
            let glass = theseusView
            let shadow = glassShadowView
            DispatchQueue.main.async {
                glass?.pauseRendering()
                glass?.removeFromSuperview()
                shadow?.removeFromSuperview()
            }
        }
        stopDisplayLink()
    }

    private func setupLayers() {
        trackClipLayer.masksToBounds = true
        trackClipLayer.cornerCurve = .continuous
        trackClipLayer.allowsEdgeAntialiasing = true
        trackBackgroundLayer.allowsEdgeAntialiasing = true
        trackForegroundLayer.allowsEdgeAntialiasing = true
        trackForegroundLayer.cornerCurve = .continuous
        layer.addSublayer(trackClipLayer)
        trackClipLayer.addSublayer(trackBackgroundLayer)
        trackClipLayer.addSublayer(trackForegroundLayer)

        knobContainerView.isUserInteractionEnabled = false
        knobContainerView.addSubview(knobImageView)
        addSubview(knobContainerView)

        updateColors()
    }

    private func setupGestureRecognizers() {
        addGestureRecognizer(panGestureRecognizer)
    }

    private func updateKnobImage() {
        let image = generateDefaultKnobImage(size: layout.knobSize, color: knobColor)
        knobImageView.image = image
        knobImageView.frame = CGRect(origin: .zero, size: image.size)
        cachedMetrics = nil
    }

    private func generateDefaultKnobImage(size: CGSize, color: UIColor) -> UIImage {
        let shadowPadding = Self.knobShadowPadding
        let imageSize = CGSize(
            width: size.width + shadowPadding * 2,
            height: size.height + shadowPadding * 2
        )
        let cornerRadius = size.height / 2.0

        return UIGraphicsImageRenderer(size: imageSize).image { ctx in
            let context = ctx.cgContext

            context.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 10.5,
                color: UIColor(white: 0, alpha: 0.13).cgColor
            )
            context.setFillColor(color.cgColor)

            let knobRect = CGRect(
                x: shadowPadding,
                y: shadowPadding,
                width: size.width,
                height: size.height
            )
            let path = UIBezierPath(roundedRect: knobRect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    private func updateColors() {
        trackBackgroundLayer.backgroundColor = backColor.resolvedColor(with: traitCollection).cgColor
        trackForegroundLayer.backgroundColor = trackColor.cgColor
        applyNativeLens()
    }

    private func applyNativeLens() {
        guard let glass = theseusView else { return }
        let lens = nativeLens
        guard glass.configuration.nativeLens != lens else { return }
        glass.configuration.nativeLens = lens
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
            applyGlassMaterial()
            setNeedsLayout()
        }
    }

    private func updatePositionDots() {
        for dotLayer in positionDotLayers {
            dotLayer.removeFromSuperlayer()
        }
        positionDotLayers.removeAll()

        guard positionsCount > 1 else { return }

        for i in 0..<positionsCount {
            if !markPositions && i != 0 && i != positionsCount - 1 {
                continue
            }

            let outerDot = SimpleLayer()
            let innerDot = SimpleLayer()
            outerDot.addSublayer(innerDot)

            layer.insertSublayer(outerDot, below: knobContainerView.layer)
            positionDotLayers.append(outerDot)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }

        if cachedMetrics == nil || cachedMetrics!.sideLength != bounds.height {
            updateLayoutMetrics()
        }

        guard animationState == .idle else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        layoutTrack()
        layoutKnob()
        layoutPositionDots()

        CATransaction.commit()
    }

    private func updateLayoutMetrics() {
        let knobImageSize = knobImageView.image?.size ?? layout.knobSize
        let edgeMargin = layout.knobSize.width / 2.0
        let totalLength = bounds.width - edgeMargin * 2

        cachedMetrics = LayoutMetrics(
            edgeMargin: edgeMargin,
            totalLength: totalLength,
            trackPadding: 0.0,
            sideLength: bounds.height,
            knobImageSize: knobImageSize
        )
    }

    private func layoutTrack() {
        if cachedMetrics == nil || !(cachedMetrics?.isValid ?? false) {
            updateLayoutMetrics()
        }

        guard let metrics = cachedMetrics, metrics.isValid else { return }

        let trackPadding = metrics.trackPadding
        let sideLength = metrics.sideLength

        let backFrame = CGRect(
            x: trackPadding,
            y: (sideLength - layout.trackHeight) / 2,
            width: bounds.width - trackPadding * 2,
            height: layout.trackHeight
        )

        let knobCenterPosition = metrics.edgeMargin + centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: layout.knobSize.width)

        let track = computeTrackFillExtent(
            handlePosition: knobCenterPosition,
            containerWidth: bounds.width,
            marginInset: metrics.edgeMargin,
            innerPadding: trackPadding
        )

        let trackFrame = CGRect(
            x: trackPadding,
            y: (sideLength - layout.trackHeight) / 2,
            width: track,
            height: layout.trackHeight
        )

        applyTrackFrames(back: backFrame, fill: trackFrame, cornerRadius: trackCornerRadius)
    }

    private func applyTrackFrames(back: CGRect, fill: CGRect, cornerRadius: CGFloat) {
        trackClipLayer.frame = back
        trackClipLayer.cornerRadius = cornerRadius
        trackBackgroundLayer.frame = trackClipLayer.bounds
        trackForegroundLayer.frame = fill.offsetBy(dx: -back.minX, dy: -back.minY)
        trackForegroundLayer.cornerRadius = cornerRadius
    }

    private func layoutKnob() {
        if cachedMetrics == nil || !(cachedMetrics?.isValid ?? false) {
            updateLayoutMetrics()
        }

        guard let metrics = cachedMetrics, metrics.isValid else { return }

        let knobCenterPosition = metrics.edgeMargin + centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: layout.knobSize.width)
        let knobFrame = knobFrame(centerX: knobCenterPosition, height: metrics.sideLength, metrics: metrics)

        knobContainerView.frame = knobFrame
        knobImageView.center = CGPoint(x: knobFrame.width / 2, y: knobFrame.height / 2)
    }

    /// The knob sits on whole points along the track and whole pixels vertically, as native's does.
    private func knobFrame(centerX: CGFloat, height: CGFloat, metrics: LayoutMetrics) -> CGRect {
        let scale = displayScale
        let x = (centerX - metrics.knobImageSize.width / 2).rounded(.toNearestOrAwayFromZero)
        let y = (((height - metrics.knobImageSize.height) / 2 + Self.knobVerticalOffset) * scale).rounded(.up) / scale
        return CGRect(x: x, y: y, width: metrics.knobImageSize.width, height: metrics.knobImageSize.height)
    }

    private func layoutPositionDots() {
        guard positionsCount > 1 else { return }

        if cachedMetrics == nil || !(cachedMetrics?.isValid ?? false) {
            updateLayoutMetrics()
        }

        guard let metrics = cachedMetrics, metrics.isValid else { return }

        let dotOffset: CGFloat = 4.0
        let trackCenterY = metrics.sideLength / 2
        let trackBottom = trackCenterY + layout.trackHeight / 2

        var dotIndex = 0
        for i in 0..<positionsCount {
            if !markPositions && i != 0 && i != positionsCount - 1 {
                continue
            }

            guard dotIndex < positionDotLayers.count else { break }
            let outerDot = positionDotLayers[dotIndex]
            dotIndex += 1

            let inset: CGFloat = 1.5
            let outerSize = layout.dotSize + inset * 2

            let dotCenterPosition = metrics.edgeMargin + metrics.totalLength / CGFloat(positionsCount - 1) * CGFloat(i)

            let dotY = trackBottom + dotOffset

            let dotRect = CGRect(
                x: dotCenterPosition - outerSize / 2,
                y: dotY,
                width: outerSize,
                height: outerSize
            )

            outerDot.frame = dotRect
            outerDot.cornerRadius = outerSize / 2
            outerDot.backgroundColor = UIColor.clear.cgColor

            if let innerDot = outerDot.sublayers?.first as? SimpleLayer {
                let innerRect = CGRect(x: inset, y: inset, width: layout.dotSize, height: layout.dotSize)
                innerDot.frame = innerRect
                innerDot.cornerRadius = layout.dotSize / 2
                innerDot.backgroundColor = backColor.resolvedColor(with: traitCollection).cgColor
            }
        }
    }

    private func hermiteInterpolation(_ input: CGFloat) -> CGFloat {
        let clamped = min(max(input, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func biasedQuinticEase(_ normalizedInput: CGFloat, inflectionPoint: CGFloat) -> CGFloat {
        if normalizedInput <= 0 { return 0 }
        if normalizedInput >= 1 { return 1 }

        if normalizedInput < inflectionPoint {
            let scaledProgress = normalizedInput / inflectionPoint
            let quinticValue = scaledProgress * scaledProgress * scaledProgress * scaledProgress * scaledProgress
            return quinticValue * 0.5
        }

        let remainingProgress = (normalizedInput - inflectionPoint) / (1.0 - inflectionPoint)
        let inverseQuintic = 1.0 - pow(1.0 - remainingProgress, 5)
        return 0.5 + inverseQuintic * 0.5
    }

    private func computeTrackFillExtent(
        handlePosition: CGFloat,
        containerWidth: CGFloat,
        marginInset: CGFloat,
        innerPadding: CGFloat
    ) -> CGFloat {
        let transitionZone = layout.edgeFactor
        let leadingBoundary = marginInset + transitionZone
        let trailingBoundary = containerWidth - marginInset - transitionZone

        let fillTerminus: CGFloat = {
            if handlePosition <= marginInset {
                return innerPadding
            }
            if handlePosition >= containerWidth - marginInset {
                return containerWidth - innerPadding
            }
            if handlePosition < leadingBoundary {
                let ratio = (handlePosition - marginInset) / transitionZone
                let blendedExtent = leadingBoundary - innerPadding
                return innerPadding + hermiteInterpolation(ratio) * blendedExtent
            }
            if handlePosition > trailingBoundary {
                let ratio = (handlePosition - trailingBoundary) / transitionZone
                let remainingExtent = containerWidth - innerPadding - trailingBoundary
                return trailingBoundary + hermiteInterpolation(ratio) * remainingExtent
            }
            return handlePosition
        }()

        return max(0, fillTerminus - innerPadding)
    }

    // A range crossing zero puts zero at the centre; each half scales to its own edge value.
    private func centerPositionForValue(_ value: CGFloat, totalLength: CGFloat, knobSize: CGFloat) -> CGFloat {
        if minimumValue < 0 {
            let knob = knobSize

            if abs(minimumValue) > 1.0 && Int(value) == 0 {
                return totalLength / 2
            } else if abs(value) < 0.01 {
                return totalLength / 2
            } else {
                let edgeValue = value > 0 ? maximumValue : minimumValue
                if value > 0 {
                    return ((totalLength + knob) / 2) + ((totalLength - knob) / 2) * abs(value / edgeValue)
                } else {
                    return ((totalLength - knob) / 2) * abs((edgeValue - self.value) / edgeValue)
                }
            }
        }

        let position = totalLength / (maximumValue - minimumValue) * (abs(minimumValue) + value)
        return position
    }

    private func valueForCenterPosition(_ position: CGFloat, totalLength: CGFloat, knobSize: CGFloat) -> CGFloat {
        var value: CGFloat = 0

        if minimumValue < 0 {
            let knob = knobSize

            if position < (totalLength - knob) / 2 {
                let edgeValue = minimumValue
                value = edgeValue + position / ((totalLength - knob) / 2) * abs(edgeValue)
            } else if position >= (totalLength - knob) / 2 && position <= (totalLength + knob) / 2 {
                value = 0
            } else if position > (totalLength + knob) / 2 {
                value = (position - ((totalLength + knob) / 2)) / ((totalLength - knob) / 2) * maximumValue
            }
        } else {
            value = minimumValue + position / totalLength * (maximumValue - minimumValue)
        }

        return min(max(value, minimumValue), maximumValue)
    }

    /// Sets the value, clamped to the range and lower bound; `animated` glides the knob
    /// unless Reduce Motion is on or the user is dragging.
    public func setValue(_ newValue: CGFloat, animated: Bool = false) {
        var clampedValue = max(minimumValue, min(maximumValue, newValue))
        if lowerBoundValue > .ulpOfOne {
            clampedValue = max(lowerBoundValue, clampedValue)
        }

        value = clampedValue
        guard !_isTracking else { return }

        if animated, animationState == .idle, !prefersReducedMotion,
           let metrics = cachedMetrics, metrics.isValid {
            animateLayout(to: value, metrics: metrics)
        } else {
            setNeedsLayout()
        }
    }

    private func animateLayout(to value: CGFloat, metrics: LayoutMetrics) {
        let knobCenterX = metrics.edgeMargin + centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: layout.knobSize.width)
        let knobFrame = knobFrame(centerX: knobCenterX, height: metrics.sideLength, metrics: metrics)
        let fillWidth = computeTrackFillExtent(
            handlePosition: knobCenterX,
            containerWidth: bounds.width,
            marginInset: metrics.edgeMargin,
            innerPadding: metrics.trackPadding
        )
        let fillFrame = CGRect(
            x: metrics.trackPadding,
            y: (metrics.sideLength - layout.trackHeight) / 2,
            width: fillWidth,
            height: layout.trackHeight
        )

        let transition = LayoutTransition.animated(duration: layout.transitionDuration, curve: .easeInOut)
        transition.updateFrame(view: knobContainerView, frame: knobFrame)
        transition.updateFrame(layer: trackForegroundLayer, frame: fillFrame.offsetBy(dx: -trackClipLayer.frame.minX, dy: -trackClipLayer.frame.minY))
    }

    public func increase() {
        setValue(min(maximumValue, value + 1))
        sendActions(for: .valueChanged)
    }

    public func increaseBy(_ delta: CGFloat) {
        setValue(min(maximumValue, value + delta))
        sendActions(for: .valueChanged)
    }

    public func decrease() {
        setValue(max(minimumValue, value - 1))
        sendActions(for: .valueChanged)
    }

    public func decreaseBy(_ delta: CGFloat) {
        setValue(max(minimumValue, value - delta))
        sendActions(for: .valueChanged)
    }

    private func setupAccessibility() {
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
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

    /// The value when discrete (`positionsCount > 1`), else the percentage of
    /// the range; a host-assigned value wins.
    public override var accessibilityValue: String? {
        get {
            if let hostValue = super.accessibilityValue {
                return hostValue
            }
            let formatter = NumberFormatter()
            if positionsCount > 1 {
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 2
                return formatter.string(from: NSNumber(value: Double(value)))
            }
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 0
            let range = maximumValue - minimumValue
            let fraction = range > 0 ? (value - minimumValue) / range : 0
            return formatter.string(from: NSNumber(value: Double(fraction)))
        }
        set { super.accessibilityValue = newValue }
    }

    public override func accessibilityIncrement() {
        adjustValueForAccessibility(by: accessibilityStep)
    }

    public override func accessibilityDecrement() {
        adjustValueForAccessibility(by: -accessibilityStep)
    }

    private var accessibilityStep: CGFloat {
        let range = maximumValue - minimumValue
        if positionsCount > 1 {
            return range / CGFloat(positionsCount - 1)
        }
        return range * 0.1
    }

    private func adjustValueForAccessibility(by delta: CGFloat) {
        guard isEnabled, !_isTracking else { return }
        let previousValue = value
        setValue(value + delta, animated: true)
        guard value != previousValue else { return }
        sendActions(for: .valueChanged)
    }

    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        let knobHitArea = knobContainerView.frame.insetBy(dx: -10, dy: -10)
        guard knobHitArea.contains(location) else {
            return false
        }

        handleBeginTracking(location)
        return true
    }

    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        return handleContinueTracking(location)
    }

    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        handleEndTracking()
    }

    public override func cancelTracking(with event: UIEvent?) {
        handleCancelTracking()
    }

    @_spi(Scripting) public func scriptedTouchBegan(at location: CGPoint) {
        handleBeginTracking(location)
    }

    @_spi(Scripting) public func scriptedTouchMoved(to location: CGPoint) {
        _ = handleContinueTracking(location)
    }

    @_spi(Scripting) public func scriptedTouchEnded() {
        handleEndTracking()
    }

    private func handleBeginTracking(_ location: CGPoint) {
        _isTracking = true
        knobStartedDragging = false

        knobTouchCenterStart = knobContainerView.center.x
        knobTouchStart = location.x

        if positionsCount > 1 {
            let normalizedValue = (value - minimumValue) / (maximumValue - minimumValue)
            discreteCurrentPosition = Int(round(normalizedValue * CGFloat(positionsCount - 1)))
        }

        maybeCancelParentScrollView(superview, depth: 0)

        showTheseus()
    }

    private func handleContinueTracking(_ location: CGPoint) -> Bool {
        guard let metrics = cachedMetrics, metrics.isValid else { return true }

        let edgeMargin = metrics.edgeMargin
        let totalLength = metrics.totalLength

        let fingerDelta = location.x - knobTouchStart
        if !knobStartedDragging {
            guard abs(fingerDelta) > Self.dragSlop else { return true }
            knobStartedDragging = true
            onInteractionBegan?()
        }

        var newCenterX = knobTouchCenterStart + Self.knobOffset(
            forFingerDelta: fingerDelta,
            travel: totalLength,
            width: bounds.width
        )

        let minX = edgeMargin
        let maxX = edgeMargin + totalLength
        if newCenterX > maxX {
            glassOverrunOffset = Self.overrun(newCenterX - maxX, limit: layout.glassOverrun, resistance: layout.glassOverrunResistance)
        } else if newCenterX < minX {
            glassOverrunOffset = -Self.overrun(minX - newCenterX, limit: layout.glassOverrun, resistance: layout.glassOverrunResistance)
        } else {
            glassOverrunOffset = 0
        }

        newCenterX = max(edgeMargin, min(newCenterX, edgeMargin + totalLength))

        let normalizedPosition = newCenterX - edgeMargin

        let previousValue = value

        if positionsCount > 1 && !disableSnapToPositions {
            let segmentLength = totalLength / CGFloat(positionsCount - 1)
            let snapOrigin = CGFloat(discreteCurrentPosition) * segmentLength

            let touchOffset = normalizedPosition - snapOrigin
            let moveSign: CGFloat = touchOffset >= 0 ? 1.0 : -1.0
            let dragRatio = min(abs(touchOffset) / segmentLength, 1.0)

            let easeBias = moveSign > 0 ? layout.viscosityForward : layout.viscosityBackward
            let easedDragRatio = biasedQuinticEase(dragRatio, inflectionPoint: easeBias)

            let dampedPosition = snapOrigin + moveSign * easedDragRatio * segmentLength
            theseusCenterX = edgeMargin + dampedPosition

            if easedDragRatio >= layout.snapThreshold {
                let candidateIndex = discreteCurrentPosition + Int(moveSign)
                let minAllowedIndex = lowerBoundValue > 0 ? Int(lowerBoundValue) : 0
                let clampedIndex = max(minAllowedIndex, min(positionsCount - 1, candidateIndex))

                if clampedIndex != discreteCurrentPosition {
                    discreteCurrentPosition = clampedIndex
                    let computedValue = minimumValue + (maximumValue - minimumValue) * CGFloat(clampedIndex) / CGFloat(positionsCount - 1)
                    setValue(computedValue)
                    triggerHapticFeedback()
                }
            }
        } else {
            if lowerBoundValue > 0 {
                let lowerBoundNormalized = lowerBoundValue * totalLength
                let clampedNormalized = max(normalizedPosition, lowerBoundNormalized)
                theseusCenterX = edgeMargin + clampedNormalized
            } else {
                theseusCenterX = newCenterX
            }

            let normalizedPos = theseusCenterX - edgeMargin
            setValue(valueForCenterPosition(normalizedPos, totalLength: totalLength, knobSize: layout.knobSize.width))

            if previousValue != value && !disableSnapToPositions {
                let shouldTriggerHaptic = value == minimumValue ||
                    value == maximumValue ||
                    (minimumValue != startValue && value == startValue)

                if shouldTriggerHaptic {
                    triggerHapticFeedback()
                }
            }
        }

        needsFrameUpdate = true

        if !limitValueChangedToLatestState {
            sendActions(for: .valueChanged)
        }

        return true
    }

    /// Native `UISlider` ignores the first `dragSlop` points of a drag, then scales
    /// finger travel by knob travel over track width.
    static let dragSlop: CGFloat = 10.0

    static func knobOffset(forFingerDelta delta: CGFloat, travel: CGFloat, width: CGFloat) -> CGFloat {
        guard abs(delta) > dragSlop else { return 0 }
        let gain = width > 0 ? travel / width : 1
        return (abs(delta) - dragSlop) * (delta < 0 ? -1 : 1) * gain
    }

    static func overrun(_ distance: CGFloat, limit: CGFloat, resistance: CGFloat) -> CGFloat {
        guard distance > 0, limit > 0, resistance > 0 else { return 0 }
        return limit * distance * resistance / (distance * resistance + limit)
    }

    private func handleEndTracking() {
        var finalKnobFrame = knobContainerView.frame

        if positionsCount > 1 && !disableSnapToPositions {
            guard let metrics = cachedMetrics, metrics.isValid else { return }
            let finalKnobCenterX = metrics.edgeMargin + CGFloat(discreteCurrentPosition) * metrics.totalLength / CGFloat(positionsCount - 1)
            finalKnobFrame = knobFrame(centerX: finalKnobCenterX, height: bounds.height, metrics: metrics)
        }

        _isTracking = false

        sendActions(for: .valueChanged)
        setNeedsLayout()

        onInteractionEnded?()

        hideTheseus(animated: true, targetKnobFrame: finalKnobFrame)
    }

    private func handleCancelTracking() {
        _isTracking = false
        setNeedsLayout()
        onInteractionEnded?()

        hideTheseus(animated: true)
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] _ in
            self?.displayLinkTick()
        }
        displayLink?.isPaused = false
    }

    private func stopDisplayLink() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
    }

    private func displayLinkTick() {
        guard let metrics = cachedMetrics, metrics.isValid else { return }

        switch animationState {
        case .idle:
            stopDisplayLink()

        case .tracking:
            guard needsFrameUpdate else { return }
            updateAllFramesFromTheseus(metrics: metrics)
            needsFrameUpdate = false

        }
    }

    private func updateKnobFrameDirect(knobCenterX: CGFloat, metrics: LayoutMetrics) {
        let sideLength = metrics.sideLength
        let knobImageSize = metrics.knobImageSize

        let knobFrame = CGRect(
            x: knobCenterX - knobImageSize.width / 2,
            y: (sideLength - knobImageSize.height) / 2 + Self.knobVerticalOffset,
            width: knobImageSize.width,
            height: knobImageSize.height
        )

        knobContainerView.frame = knobFrame
        knobImageView.center = CGPoint(x: knobFrame.width / 2, y: knobFrame.height / 2)
    }

    private func updateTrackFramesDirect(knobCenterX: CGFloat, metrics: LayoutMetrics) {
        let edgeMargin = metrics.edgeMargin
        let trackPadding = metrics.trackPadding
        let sideLength = metrics.sideLength

        let track = computeTrackFillExtent(
            handlePosition: knobCenterX,
            containerWidth: bounds.width,
            marginInset: edgeMargin,
            innerPadding: trackPadding
        )

        let currentSize = layout.trackHeight

        let backFrame = CGRect(
            x: trackPadding,
            y: (sideLength - currentSize) / 2,
            width: bounds.width - trackPadding * 2,
            height: currentSize
        )
        let trackFrame = CGRect(
            x: trackPadding,
            y: (sideLength - currentSize) / 2,
            width: track,
            height: currentSize
        )
        applyTrackFrames(back: backFrame, fill: trackFrame, cornerRadius: currentSize / 2)
    }

    private func updateAllFramesFromTheseus(metrics: LayoutMetrics) {
        let knobCenterX = max(metrics.edgeMargin, min(theseusCenterX, metrics.edgeMargin + metrics.totalLength))

        updateKnobFrameDirect(knobCenterX: knobCenterX, metrics: metrics)
        updateTrackFramesDirect(knobCenterX: knobCenterX, metrics: metrics)
    }

    private func teardownTheseus() {
        if animationState != .idle || glassLink != nil {
            finalizeHideAnimation()
        }
        theseusView?.pauseRendering()
        theseusView?.removeFromSuperview()
        theseusView = nil
        glassShadowView?.removeFromSuperview()
        glassShadowView = nil
        knobImageView.alpha = 1.0
    }

    private func triggerHapticFeedback() {
        hapticManager.impact(.light)
    }

    private func maybeCancelParentScrollView(_ view: UIView?, depth: Int) {
        guard depth <= 5, let view = view else { return }

        if let scrollView = view as? UIScrollView {
            scrollView.isScrollEnabled = false
            scrollView.isScrollEnabled = true
        } else {
            maybeCancelParentScrollView(view.superview, depth: depth + 1)
        }
    }

    private var theseusContainer: UIView? {
        theseusSourceView?.superview
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

    private func setupTheseusIfNeeded() {
        guard theseusView == nil else { return }
        guard let container = theseusContainer,
              let sourceView = theseusSourceView else { return }

        var config = TheseusConfiguration.lens
        config.shape.padding = Self.glassPadding
        config.shape.cornerRadius = -glassSize.height / 2.0
        config.lensChain = usesIOS26Look ? .sliderKnob26 : .sliderKnob
        config.nativeLens = nativeLens
        config.edgeFeather = TheseusSwitch.glassFeather
        config.captureMethod = TheseusCapability.isDeviceSupported ? .layerRendering : .surfaceBased
        config.refraction.magnification = 1.0
        config.refraction.magnificationCenterY = 0
        config.refraction.intensity = 1.1
        config.refraction.interiorSharpness = 1.0
        config.edgeEffects.rimGlow = 0
        config.edgeEffects.glareIntensity = 0
        config.blur.radius = 0
        config.lensFillColor = Self.fillColor
        glassMaterial.apply(to: &config, isDark: isDarkAppearance, activity: 0)

        let shadow = GlassKnobShadowView()
        shadow.setAppearance(isDark: isDarkAppearance, iOS26: usesIOS26Look)
        shadow.isHidden = true
        container.addSubview(shadow)
        glassShadowView = shadow

        let glass = TheseusView(configuration: config)
        glass.sourceView = sourceView
        glass.isHidden = true
        glass.isUserInteractionEnabled = false
        glass.setCaptureExcludedViews([shadow])
        container.addSubview(glass)
        theseusView = glass
    }

    private func applyGlassMaterial() {
        glassShadowView?.setAppearance(isDark: isDarkAppearance, iOS26: usesIOS26Look)
        guard let glass = theseusView else { return }
        var config = glass.configuration
        glassMaterial.apply(to: &config, isDark: isDarkAppearance, activity: 0)
        config.lensFillColor = Self.fillColor
        config.nativeLens = nativeLens
        glass.configuration = config
    }

    private func glassFrame(centerX: CGFloat) -> CGRect {
        let size = glassSize
        let centerY = (cachedMetrics?.sideLength ?? bounds.height) / 2 + (usesIOS26Glass ? Self.iOS26GlassOffset : layout.glassCenterOffset.y)
        return CGRect(
            x: centerX + layout.glassCenterOffset.x - size.width / 2,
            y: centerY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// `lens` runs from the knob (0) to the held glass (1) and may overshoot;
    /// `fill` is the knob's white.
    private func setLensState(fill: CGFloat, lens: CGFloat) {
        guard let glass = theseusView else { return }
        var config = glass.configuration
        var chain = config.lensChain ?? .sliderKnob
        let clampedFill = min(max(fill, 0), 1)
        let releasing = glassMorph.phase == .releasing
        let warp = usesIOS26Look || releasing ? 0 : Self.knobWarp * (1 - lens)
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

    private func showTheseus() {
        releaseGeneration += 1
        knobImageView.layer.removeAllAnimations()
        releaseAt = nil
        flightAt = nil
        flightStart = nil
        pendingFlight = false
        glassMotion.drivesStretch = true
        if usesIOS26Look, let metrics = cachedMetrics, metrics.isValid {
            theseusCenterX = metrics.edgeMargin + centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: layout.knobSize.width)
        } else {
            theseusCenterX = knobContainerView.center.x
        }
        glassOverrunOffset = 0
        animationState = .tracking
        startDisplayLink()
        if glassVisible || prefersReducedMotion {
            pressBeginsAt = nil
            beginGlassPress()
        } else {
            pressBeginsAt = CACurrentMediaTime() + Self.pressDelay
            setupTheseusIfNeeded()
            startGlassLink()
        }
    }

    private func beginGlassPress() {
        setupTheseusIfNeeded()
        guard let glass = theseusView else { return }

        let wasVisible = glassVisible
        glassVisible = true
        pressStartTime = CACurrentMediaTime()
        let springs = usesIOS26Look ? KnobGlassMorph.sliderSprings26 : KnobGlassMorph.sliderSprings
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
        glass.shape.cornerRadius = -glassSize.height / 2.0
        glassMotion.omega = KnobGlassMotion.followOmega
        glassMotion.damping = KnobGlassMotion.followDamping

        if !wasVisible {
            glassMotion = KnobGlassMotion(at: theseusCenterX + glassOverrunOffset)
            glassRevealed = prefersReducedMotion
            let glassLayers = [glass.layer, glassShadowView?.layer].compactMap { $0 }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for layer in glassLayers {
                LensMorph.reset(layer)
                layer.opacity = prefersReducedMotion ? 1 : 0
            }
            glass.isHidden = false
            glassShadowView?.isHidden = false
            glassShadowView?.layer.opacity = 0
            if prefersReducedMotion {
                knobImageView.alpha = 0
            }
            CATransaction.commit()
            glass.onPresent = { [weak self] in
                self?.revealGlass()
            }
            glassStart = CACurrentMediaTime()
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
        guard let glass = theseusView, !glassRevealed, glassVisible else { return }
        glassRevealed = true
        glass.onPresent = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glass.layer.opacity = 1
        knobImageView.layer.transform = CATransform3DIdentity
        knobImageView.alpha = 0
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

    private func flightSwing(at time: CFTimeInterval) -> CGFloat {
        guard let start = flightStart else { return 0 }
        return KnobGlassMotion.releaseStretch(at: time - start, distance: releaseFlight)
    }

    private func startFlight() {
        releaseFlight = releaseTargetX - glassMotion.position
        releaseDirection = releaseFlight < 0 ? -1 : 1
        glassMotion.velocity = 0
        glassMotion.omega = Self.releaseMoveOmega
        glassMotion.damping = Self.releaseMoveDamping
        glassMotion.target = releaseTargetX
        glassMotion.drivesStretch = false
        flightStart = CACurrentMediaTime()
    }

    private func stepGlass(by interval: TimeInterval) {
        let now = CACurrentMediaTime()
        if let begins = pressBeginsAt, now >= begins {
            pressBeginsAt = nil
            beginGlassPress()
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
            if pressBeginsAt == nil, releaseAt == nil, flightAt == nil, !_isTracking {
                stopGlassLink()
            }
            return
        }
        glassMorph.step(by: interval)
        if flightStart == nil {
            glassMotion.track(theseusCenterX + glassOverrunOffset, by: interval)
        } else {
            glassMotion.step(by: interval)
        }
        if !glassRevealed, glassMorph.phase == .pressing, now - glassStart >= Self.revealTimeout {
            revealGlass()
        }
        let lens = glassMorph.lens
        let fill = glassMorph.fill

        if glassMorph.phase == .releasing, glassMorph.releasedFor >= Self.morphDuration {
            if glassVisible {
                landGlass()
            }
            let swing = flightSwing(at: now)
            let settled = glassMorph.releasedFor >= KnobGlassMotion.releaseDuration
                && flightStart.map { now - $0 >= KnobGlassMotion.releaseDuration } ?? true
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            knobImageView.layer.transform = settled
                ? CATransform3DIdentity
                : KnobGlassMotion.anchoredStretch(swing, width: layout.knobSize.width, direction: releaseDirection)
            CATransaction.commit()
            if settled {
                glassMorph.settle()
                stopGlassLink()
            }
            return
        }

        guard let glass = theseusView, let container = theseusContainer else { return }
        let glassLocal = glassFrame(centerX: glassMotion.position)
        let exactFrame = convert(glassLocal, to: container)
        let frame = exactFrame.pixelAligned(scale: displayScale)
        let shapeOffset = usesIOS26Look ? CGPoint(x: exactFrame.midX - frame.midX, y: exactFrame.midY - frame.midY) : .zero
        if glass.configuration.shapeOffset != shapeOffset {
            glass.configuration.shapeOffset = shapeOffset
        }
        let knobScale = CGPoint(x: layout.knobSize.width / frame.width, y: layout.knobSize.height / frame.height)
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
            shadowOpacity = Float((1 - fill) * min(CGFloat(now - revealed) / CGFloat(Self.shadowAppearFade), 1))
        } else {
            shadowOpacity = 0
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glass.bounds = CGRect(origin: .zero, size: frame.size)
        glass.center = CGPoint(x: frame.midX, y: frame.midY)
        glassShadowView?.place(in: frame)
        glass.layer.transform = transform
        glassShadowView?.layer.transform = transform
        glassShadowView?.layer.opacity = glassRevealed ? shadowOpacity : 0
        if !glassRevealed {
            let knobRect = knobContainerView.frame.insetBy(dx: Self.knobShadowPadding, dy: Self.knobShadowPadding)
            let grow = LensMorph.transform(mapping: knobRect, onto: glassLocal)
            knobImageView.layer.transform = LensMorph.lerp(CATransform3DIdentity, grow, lens)
            knobImageView.alpha = max(fill, Self.unrevealedKnobOpacity)
        }
        CATransaction.commit()
        setLensState(fill: fill, lens: lens)
    }

    private func landGlass() {
        glassVisible = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        knobImageView.layer.transform = CATransform3DIdentity
        knobImageView.alpha = 1
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

    private func hideTheseus(animated: Bool, targetKnobFrame: CGRect? = nil) {
        let knobFrame = targetKnobFrame ?? knobContainerView.frame
        theseusCenterX = knobFrame.midX
        glassOverrunOffset = 0
        if let metrics = cachedMetrics, metrics.isValid {
            updateAllFramesFromTheseus(metrics: metrics)
        }
        animationState = .idle
        stopDisplayLink()

        guard animated, !prefersReducedMotion, theseusView != nil, glassVisible || pressBeginsAt != nil else {
            finalizeHideAnimation()
            return
        }

        releaseTargetX = knobFrame.midX
        let now = CACurrentMediaTime()
        if let pressedAt = pressBeginsAt {
            pendingFlight = true
            releaseAt = pressedAt + Self.minimumLensTime
        } else {
            flightAt = now + Self.releaseLatency
            releaseAt = max(now + Self.releaseLatency, pressStartTime + Self.minimumLensTime)
        }
        startGlassLink()
    }

    private func finalizeHideAnimation() {
        stopGlassLink()
        glassMorph.settle()
        pressBeginsAt = nil
        releaseAt = nil
        flightAt = nil
        pendingFlight = false
        flightStart = nil
        glassVisible = false
        glassRevealTime = nil
        theseusView?.layer.removeAllAnimations()
        glassShadowView?.layer.removeAllAnimations()
        if let glass = theseusView {
            glass.onPresent = nil
            glass.layer.transform = CATransform3DIdentity
            glass.pauseRendering()
            glass.isHidden = true
            glass.continuousUpdate = false
        }
        glassShadowView?.layer.transform = CATransform3DIdentity
        glassShadowView?.isHidden = true
        setLensState(fill: 0, lens: 1)
        knobImageView.layer.transform = CATransform3DIdentity
        knobImageView.alpha = 1.0
        animationState = .idle
        stopDisplayLink()
        setNeedsLayout()
    }

    public override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview == nil {
            teardownTheseus()
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            teardownTheseus()
        } else {
            MetalContext.prewarm()
        }
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 31.0)
    }
}

extension TheseusSlider: UIGestureRecognizerDelegate {
    /// Refuses ancestor pan recognizers whose touch starts on the knob, so a
    /// knob drag keeps `UIControl` tracking, as `UISlider` does.
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        let location = panGesture.location(in: self)
        let knobHitArea = knobContainerView.frame.insetBy(dx: -10, dy: -10)

        guard panGesture === panGestureRecognizer else {
            if isEnabled,
               panGesture.view !== self,
               knobHitArea.contains(location) {
                return false
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        guard knobHitArea.contains(location) else {
            return false
        }

        let velocity = panGesture.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else {
            return false
        }
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return false
    }
}
