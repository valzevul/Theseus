import UIKit
import UIKit.UIGestureRecognizerSubclass
import QuartzCore
import Accelerate

public struct TheseusTabBarItem {
    public var icon: UIImage?
    public var selectedIcon: UIImage?
    public var title: String?
    @available(*, deprecated, message: "Badges are not rendered.")
    public var badge: String?

    public init(icon: UIImage? = nil, selectedIcon: UIImage? = nil, title: String? = nil) {
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.title = title
    }

    @available(*, deprecated, message: "Badges are not rendered.")
    public init(icon: UIImage? = nil, selectedIcon: UIImage? = nil, title: String? = nil, badge: String?) {
        self.init(icon: icon, selectedIcon: selectedIcon, title: title)
        self.badge = badge
    }
}

/// A Liquid Glass-styled tab bar with animated selection indicator.
public class TheseusTabBar: UIView {

    public var items: [TheseusTabBarItem] = [] {
        didSet {
            rebuildItemViews()
            setNeedsLayout()
        }
    }

    public var selectedIndex: Int = 0 {
        didSet {
            if selectedIndex != oldValue, !isCommittingDrag {
                updateSelection(animated: true)
            }
        }
    }

    private var isCommittingDrag = false

    public var onItemSelected: ((Int) -> Void)?

    public var selectedTintColor: UIColor = .systemBlue {
        didSet { updateItemColors() }
    }

    /// Left at `nativeUnselectedTint`, unselected items take their colour from the glass behind them, as native's do.
    public var unselectedTintColor: UIColor = TheseusTabBar.nativeUnselectedTint {
        didSet { updateItemColors() }
    }

    public static let nativeUnselectedTint = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
    private var appliedUnselectedTint: UIColor?

    /// Points; the default is the native iOS 27 bar height.
    public var barHeight: CGFloat = 63 {
        didSet { invalidateIntrinsicContentSize() }
    }

    /// Width of one item slot in points; the capsule hugs its content and centres itself in a wider frame.
    public var preferredItemWidth: CGFloat = 66 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private var contentBarFrame: CGRect {
        guard !items.isEmpty else { return bounds }
        let contentWidth = min(bounds.width, CGFloat(items.count) * preferredItemWidth * (usesIOS26Look ? Self.iOS26WidthScale : 1))
        return CGRect(
            x: (bounds.width - contentWidth) / 2,
            y: 0,
            width: contentWidth,
            height: bounds.height
        )
    }

    public var glassTint: UIColor = .clear {
        didSet {
            theseusView?.theme.tintColor = glassTint
        }
    }

    /// Strength of `glassTint`, 0...1; `TheseusSettings.tintSpectrum` leaves it alone.
    public var glassTintIntensity: CGFloat = 1.0 {
        didSet {
            theseusView?.theme.tintOpacity = glassTintIntensity
        }
    }

    /// Blurs only the lens's rim and dispersion; the magnified interior stays sharp.
    public var glassBlurRadius: CGFloat = 0.0 {
        didSet {
            theseusView?.blur.radius = lensBlurRadius
        }
    }

    private var lensBlurRadius: CGFloat {
        max(glassBlurRadius, lensMaterial.blurRadius)
    }

    private var systemIsDark: Bool {
        if #available(iOS 13.0, *) {
            return traitCollection.userInterfaceStyle == .dark
        }
        return false
    }

    private var isDarkAppearance: Bool {
        adaptiveDark ?? systemIsDark
    }

    private var adaptiveDark: Bool?

    private var usesIOS26Look: Bool {
        TheseusSettings.shared.effectiveGlassStyle == .iOS26
    }

    static let iOS26DarkBelow: CGFloat = 53.0 / 255.0
    static let iOS26LightAbove: CGFloat = 221.0 / 255.0
    static let iOS26LightReturnAbove: CGFloat = 125.0 / 255.0
    static let iOS26DarkReturnBelow: CGFloat = 148.0 / 255.0

    public func invalidateBackground() {
        backgroundGlassView.invalidateBackground()
        selectionView.invalidateBackground()
        theseusView?.invalidateBackground()
    }

    static let iOS26AdaptOmega: CGFloat = 13
    static let iOS26AdaptDelay: TimeInterval = 0.08
    static let iOS26LocalSlopeLight: CGFloat = 0.27
    static let iOS26LocalSlopeDark: CGFloat = 0.32

    private var adaptLevel: CGFloat?
    private var adaptDarkWeight: CGFloat = 0
    private var adaptLevelTarget: CGFloat = 0.5
    private var adaptDarkTarget: CGFloat = 0
    private var adaptLevelVelocity: CGFloat = 0
    private var adaptDarkVelocity: CGFloat = 0
    private var adaptLink: CADisplayLink?
    private var adaptLastTime: CFTimeInterval = 0
    private var adaptPending: DispatchWorkItem?

    private func updateAdaptiveAppearance() {
        guard usesIOS26Look, let luminance = backgroundGlassView.backdropLuminance else {
            if adaptLevel != nil || adaptiveDark != nil {
                resetAdaptation()
                applyAdaptiveOverride()
                updateAppearanceForCurrentMode()
            }
            return
        }
        let wasDark = adaptLevel == nil ? systemIsDark : adaptDarkTarget > 0.5
        let isDark: Bool
        if systemIsDark {
            isDark = wasDark ? luminance <= Self.iOS26LightAbove : luminance < Self.iOS26DarkReturnBelow
        } else {
            isDark = wasDark ? luminance <= Self.iOS26LightReturnAbove : luminance < Self.iOS26DarkBelow
        }
        let dark: CGFloat = isDark ? 1 : 0
        guard adaptLevel != nil else {
            adaptLevel = luminance
            adaptLevelTarget = luminance
            adaptDarkWeight = dark
            adaptDarkTarget = dark
            applyAdaptationStep()
            return
        }
        guard abs(luminance - adaptLevelTarget) > 0.002 || dark != adaptDarkTarget else { return }
        adaptPending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.adaptLevelTarget = luminance
            self.adaptDarkTarget = dark
            self.startAdaptation()
        }
        adaptPending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.iOS26AdaptDelay, execute: work)
    }

    private func resetAdaptation() {
        adaptPending?.cancel()
        adaptPending = nil
        if adaptLink != nil {
            backgroundGlassView.continuousUpdate = false
            selectionView.continuousUpdate = false
        }
        adaptLink?.invalidate()
        adaptLink = nil
        adaptLevel = nil
        adaptiveDark = nil
        adaptLevelVelocity = 0
        adaptDarkVelocity = 0
    }

    private func startAdaptation() {
        guard adaptLink == nil else { return }
        adaptLastTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(stepAdaptation))
        link.add(to: .main, forMode: .common)
        adaptLink = link
        backgroundGlassView.continuousUpdate = true
        selectionView.continuousUpdate = true
    }

    @objc private func stepAdaptation() {
        let now = CACurrentMediaTime()
        let dt = min(max(now - adaptLastTime, 0), 0.05)
        adaptLastTime = now
        func spring(_ value: inout CGFloat, _ velocity: inout CGFloat, toward target: CGFloat) {
            let omega = Self.iOS26AdaptOmega
            let offset = value - target
            let decay = exp(-omega * dt)
            let next = (offset + (velocity + omega * offset) * dt) * decay
            velocity = (velocity - (velocity + omega * offset) * omega * dt) * decay
            value = target + next
        }
        var level = adaptLevel ?? adaptLevelTarget
        spring(&level, &adaptLevelVelocity, toward: adaptLevelTarget)
        adaptLevel = level
        spring(&adaptDarkWeight, &adaptDarkVelocity, toward: adaptDarkTarget)
        let settled = abs(level - adaptLevelTarget) < 0.0005 && abs(adaptDarkWeight - adaptDarkTarget) < 0.0005
            && abs(adaptLevelVelocity) < 0.005 && abs(adaptDarkVelocity) < 0.005
        if settled {
            adaptLevel = adaptLevelTarget
            adaptDarkWeight = adaptDarkTarget
            adaptLink?.invalidate()
            adaptLink = nil
            backgroundGlassView.continuousUpdate = false
            selectionView.continuousUpdate = false
        }
        applyAdaptationStep()
    }

    private func applyAdaptationStep() {
        let dark = adaptDarkWeight > 0.5
        if adaptLink == nil, dark != adaptiveDark {
            adaptiveDark = dark
            applyAdaptiveOverride()
        }
        updateAppearanceForCurrentMode()
        if !isDragging {
            updateItemColors()
        }
    }

    private func iOS26ChromeState() -> ChromeCurve {
        let spectrum = TheseusSettings.shared.tintSpectrum
        let level = adaptLevel ?? 0.5
        func line(_ curve: ChromeCurve, slope: CGFloat) -> ChromeCurve {
            let center = TheseusMaterialModel.curveValue(curve.knots, at: level)
            return ChromeCurve(knots: (0..<16).map { center + slope * (CGFloat($0) / 15 - level) }, chroma: curve.chroma, chromaSlope: curve.chromaSlope)
        }
        let light = line(Self.iOS26ClearLight, slope: Self.iOS26LocalSlopeLight).blended(toward: Self.iOS26TintedLight, by: spectrum)
        let dark = line(Self.iOS26ClearDark, slope: Self.iOS26LocalSlopeDark).blended(toward: Self.iOS26TintedDark, by: spectrum)
        return light.blended(toward: dark, by: adaptDarkWeight)
    }

    private func iOS26PillState() -> PillMaterial {
        let w = min(max(adaptDarkWeight, 0), 1)
        let light = Self.iOS26PillLight, dark = Self.iOS26PillDark
        return PillMaterial(gain: light.gain + (dark.gain - light.gain) * w, lift: light.lift + (dark.lift - light.lift) * w, saturation: light.saturation + (dark.saturation - light.saturation) * w)
    }

    private func applyAdaptiveOverride() {
        guard #available(iOS 13.0, *) else { return }
        let style: UIUserInterfaceStyle = adaptiveDark.map { $0 ? .dark : .light } ?? .unspecified
        contentView.overrideUserInterfaceStyle = style
        theseusView?.overrideUserInterfaceStyle = style
    }

    private func apply(_ material: TheseusLensMaterial, activity: CGFloat, to config: inout TheseusConfiguration) {
        material.apply(to: &config, isDark: isDarkAppearance, activity: activity)
        config.lensChain = usesIOS26Look ? .tabLens26 : (config.lensChain == .tabLens26 ? TheseusConfiguration.LensChain() : config.lensChain)
        config.nativeLens = usesIOS26Look
            ? .tabLens(height: Self.iOS26LensSize.height, traits: UITraitCollection(userInterfaceStyle: isDarkAppearance ? .dark : .light))
            : nil
    }

    private func applyLensMaterial() {
        guard let glassView = theseusView else { return }
        var config = glassView.configuration
        apply(lensMaterial, activity: lensActivity, to: &config)
        config.theme.luminanceLift *= barBodyLift
        config.blur.radius = lensBlurRadius
        glassView.configuration = config
        setLensItemProgress(lensItemProgress)
    }

    private func startLensActivity() {
        lensActivity = 0
        lensActivityTimestamp = nil
        guard lensActivityLink == nil else { return }
        lensActivityLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] timestamp in
            self?.tickLensActivity(timestamp)
        }
        lensActivityLink?.isPaused = false
    }

    private func stopLensActivity() {
        lensActivityLink?.isPaused = true
        lensActivityLink?.invalidate()
        lensActivityLink = nil
        lensActivity = 0
        lensActivityTimestamp = nil
        applyLensDepth()
    }

    private func tickLensActivity(_ timestamp: CFTimeInterval) {
        let dt = lensActivityTimestamp.map { max(timestamp - $0, 0) } ?? 0
        lensActivityTimestamp = timestamp
        let speed = hypot(currentDragVelocity.x, currentDragVelocity.y)
        let target = min(speed / max(lensMaterial.motionSpeed, 1), 1)
        if target >= lensActivity {
            lensActivity = target
        } else {
            let decay = exp(-dt / max(lensMaterial.motionDecay, 0.01))
            lensActivity = target + (lensActivity - target) * decay
        }
        applyLensDepth()
    }

    private func applyLensDepth() {
        guard let glassView = theseusView else { return }
        let thickness = lensMaterial.depth * lensMaterial.depthScale(activity: lensActivity)
        guard abs(glassView.configuration.refraction.thickness - thickness) > 0.001 else { return }
        glassView.refraction.thickness = thickness
    }

    @available(*, deprecated, message: "The drag lens no longer reads a refractive index; kept for source compatibility.")
    public var glassRefractionFactor: CGFloat = 1.2


    /// Drag-lens optics and motion response. Changes apply live.
    public var lensMaterial: TheseusLensMaterial = .default {
        didSet {
            guard lensMaterial != oldValue else { return }
            applyLensMaterial()
        }
    }

    private var lensActivity: CGFloat = 0
    private var lensItemProgress: CGFloat = 0
    private var lensActivityLink: DisplayLinkDriver.Link?
    private var lensActivityTimestamp: CFTimeInterval?

    private var itemViews: [TabItemView] = []
    private var theseusView: TheseusView?
    /// Laid out through bounds and center: the lift is a transform on it,
    /// and a frame write under a transform would cancel it.
    private let contentView = UIView()
    private let backgroundView = UIView()
    private let backgroundGlassView: TheseusView = {
        var config = TheseusConfiguration()
        config.blur.radius = 18
        config.captureMethod = TheseusCapability.isDeviceSupported ? .layerRendering : .surfaceBased
        // Zero edge width: the native chrome is flat frosted glass with no refraction ring.
        config.refraction.edgeWidth = 0
        config.refraction.interiorSharpness = TheseusTabBar.chromeDetailLight
        config.refraction.interiorAverage = TheseusTabBar.chromeAverage
        config.refraction.dispersion = 0
        config.theme.neutralBodyScale = 1.0
        config.outerGlow = 0
        config.edgeFeather = TheseusTabBar.chromeFeather
        return TheseusView(configuration: config)
    }()

    /// One device pixel at 3x.
    static let chromeFeather: CGFloat = 1.0 / 3.0
    static let pillFeather: CGFloat = 1.0 / 3.0

    static let chromeDetailLight: CGFloat = 0.48
    static let chromeDetailDark: CGFloat = 0.42
    static let chromeAverage: CGFloat = 80
    static let pillDetail: CGFloat = 0.5

    private let selectionView: TheseusView = {
        var config = TheseusConfiguration()
        config.blur.radius = 18
        config.captureMethod = TheseusCapability.isDeviceSupported ? .layerRendering : .surfaceBased
        config.refraction.edgeWidth = 0
        config.refraction.interiorSharpness = TheseusTabBar.pillDetail
        config.refraction.interiorAverage = TheseusTabBar.chromeAverage
        config.refraction.dispersion = 0
        config.edgeEffects.rimGlow = 0
        config.edgeEffects.glareIntensity = 0
        config.theme.neutralBodyScale = 0
        config.outerGlow = 0
        config.edgeFeather = TheseusTabBar.pillFeather
        return TheseusView(configuration: config)
    }()

    /// Native iOS 27 pill and lens sizes in points, read from its layers.
    static let pillSize = CGSize(width: 80, height: 53.5)
    static let lensSize = CGSize(width: 96, height: 70)
    static let iOS26LensSize = CGSize(width: 90, height: 70)

    /// The native platter's shade over the pill's top third.
    private let pillShadeLayer = CAGradientLayer()

    /// Scale of the whole bar while the lens is up; native's platter transform.
    public static let liftScale: CGFloat = 1.0431
    private var isDragging: Bool = false
    private var slotFrames: [CGRect] = []

    private var currentDragVelocity: CGPoint = .zero

    private var selectionAnimator: SelectionAnimator?

    private var itemsContainerView: UIView?
    // -1 while not dragging.
    private var hoveredIndex: Int = -1

    private var lensMorphAnimator: LensMorphAnimator?
    private var isCollapsingLens = false
    private let liftDriver = LensMorph.Driver()
    private let bodyGainDriver = LensMorph.Driver()
    private let pillFadeDriver = LensMorph.Driver()
    private var barBodyLift: CGFloat = 0
    private let flexSpreadDriver = LensMorph.Driver()
    private let lensStretchDriver = LensMorph.Driver()
    private var lensStretch: CGFloat = 1
    private var flexSpread: CGFloat = 0
    private var flexSpreadStarted = false
    private var flexReleaseScale: CGFloat?
    private var flexTouchStartX: CGFloat?
    private var flexSpotCenter: CGPoint?
    private var flexTouchY: CGFloat?
    private var restGlassColor: UIColor?
    private var tintedSelection: Int = 0
    private var isPillFading = false
    private var pillRestFrame: CGRect = .zero
    private var barLift: CGFloat = 1
    private var barFollow: CGFloat = 0
    private var touchDownX: CGFloat = 0
    private var fingerAnchorOffset: CGFloat = 0
    /// Native leaves the bar unlifted when the touch lands beside another finger.
    private var liftsBar = true

    private let barEdgeShadeLayer = CALayer()
    private let barEdgeGlowLayer = CALayer()
    private var barEdgeKey: [CGFloat]?

    private var bodyInset: CGFloat {
        usesIOS26Look ? 0 : Self.bodyInset
    }

    private var chromeSideInset: CGFloat {
        usesIOS26Look ? 0 : Self.chromeSideInset
    }

    private var chromeOutset: CGFloat {
        usesIOS26Look ? (Self.iOS26PlatterHeight - barHeight) / 2 : Self.chromeOutset
    }
    private let barShadowLayer = CALayer()
    private var lastWindowBarFrame: CGRect = .null
    private var barShadowSize: BarShadow?
    private var barShadowCache: [(spec: BarShadow, image: CGImage)] = []
    private let captureTwinRow = UIView()
    private var itemsHiddenForCapture = false
    private var appliedRestingTint: UIColor?


    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isAccessibilityElement = false
        accessibilityTraits.insert(.tabBar)

        contentView.isUserInteractionEnabled = false
        addSubview(contentView)
        captureTwinRow.isHidden = true
        captureTwinRow.isUserInteractionEnabled = false
        barShadowLayer.actions = ["bounds": NSNull(), "position": NSNull(), "contents": NSNull()]
        contentView.layer.addSublayer(barShadowLayer)
        backgroundView.isUserInteractionEnabled = false
        contentView.addSubview(backgroundView)

        backgroundGlassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundGlassView.continuousUpdate = false
        backgroundGlassView.providesCaptureSnapshot = true
        selectionView.providesCaptureSnapshot = true
        backgroundGlassView.snapshotDidUpdate = { [weak self] in
            guard let self else { return }
            self.updateAdaptiveAppearance()
            self.updateBarShadow()
            if self.adaptLink == nil {
                self.updateEdgeLayers()
            }
            self.refreshVibrantTints()
            self.rebuildChromeCapture()
        }
        selectionView.snapshotDidUpdate = { [weak self] in self?.refreshVibrantTints() }
        backgroundGlassView.setCaptureExcludedViews([self])
        backgroundView.addSubview(backgroundGlassView)
        for edgeLayer in [barEdgeShadeLayer, barEdgeGlowLayer] {
            edgeLayer.actions = ["bounds": NSNull(), "position": NSNull(), "contents": NSNull()]
            backgroundView.layer.addSublayer(edgeLayer)
        }
        barEdgeGlowLayer.compositingFilter = "plusL"

        selectionView.continuousUpdate = false
        selectionView.setCaptureExcludedViews([self])
        selectionView.isUserInteractionEnabled = false
        contentView.addSubview(selectionView)
        pillShadeLayer.actions = ["bounds": NSNull(), "position": NSNull(), "colors": NSNull(), "cornerRadius": NSNull(), "locations": NSNull()]
        pillShadeLayer.masksToBounds = true
        selectionView.layer.addSublayer(pillShadeLayer)

        updateAppearanceForCurrentMode()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(theseusSettingsDidChange),
            name: TheseusSettings.settingsDidChangeNotification,
            object: nil
        )

        let pressGesture = TouchTimestampingPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        pressGesture.minimumPressDuration = 0
        pressGesture.allowableMovement = .greatestFiniteMagnitude
        pressGesture.delegate = self
        addGestureRecognizer(pressGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }

    deinit {
        selectionAnimator?.cancel()
        lensMorphAnimator?.cancel()
        lensActivityLink?.invalidate()
        adaptLink?.invalidate()
        adaptPending?.cancel()
        NotificationCenter.default.removeObserver(self)
    }


    public override var intrinsicContentSize: CGSize {
        CGSize(
            width: items.isEmpty ? UIView.noIntrinsicMetric : CGFloat(items.count) * preferredItemWidth * (usesIOS26Look ? Self.iOS26WidthScale : 1),
            height: barHeight
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        contentView.bounds = bounds
        let barFrame = contentBarFrame
        contentView.center = CGPoint(x: bounds.midX, y: bounds.midY).applying(pixelSnap(for: barFrame))
        backgroundView.frame = barFrame.insetBy(dx: chromeSideInset, dy: -chromeOutset)
        backgroundView.clipsToBounds = false
        let bodyFrame = backgroundView.bounds.insetBy(dx: bodyInset, dy: bodyInset)
        backgroundGlassView.frame = bodyFrame
        if backgroundGlassView.shape.cornerRadius != bodyFrame.height / 2 {
            backgroundGlassView.shape.cornerRadius = bodyFrame.height / 2
        }
        if backgroundGlassView.sourceView == nil, let source = theseusSourceView {
            backgroundGlassView.sourceView = source
            selectionView.sourceView = source
        }
        let windowBarFrame = convert(barFrame, to: nil)
        if windowBarFrame != lastWindowBarFrame {
            lastWindowBarFrame = windowBarFrame
            backgroundGlassView.invalidateBackground()
            selectionView.invalidateBackground()
        }
        updateEdgeLayers()
        updateBarShadow()

        itemsContainerView?.frame = bounds

        guard !bounds.isEmpty, !items.isEmpty else { return }

        layoutItemViews()
        updateSelectionViewFrame(animated: false)

        if !isDragging {
            updateTheseusFrame()
        }
    }

    /// Moves the body onto whole device pixels so the compositor never resamples the glass.
    private func pixelSnap(for barFrame: CGRect) -> CGAffineTransform {
        guard window != nil else { return .identity }
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
        let inset = chromeSideInset + bodyInset
        let bodyOrigin = convert(CGPoint(x: barFrame.minX + inset, y: barFrame.minY - chromeOutset + bodyInset), to: nil)
        let dx = (bodyOrigin.x * scale).rounded() / scale - bodyOrigin.x
        let dy = (bodyOrigin.y * scale).rounded() / scale - bodyOrigin.y
        return CGAffineTransform(translationX: dx, y: dy)
    }

    /// Points between the capsule's ends and the item strip; native's end glyph centres sit ~40 pt in.
    private var barContentInset: CGFloat {
        usesIOS26Look ? 10.25 : 15
    }

    static let iOS26WidthScale: CGFloat = 328.0 / 330.0
    static let iOS26PillSize = CGSize(width: 74, height: 53.5)

    private var pillSize: CGSize {
        usesIOS26Look ? Self.iOS26PillSize : Self.pillSize
    }

    private func layoutItemViews() {
        let itemCount = CGFloat(itemViews.count)
        guard itemCount > 0 else { return }

        let barFrame = contentBarFrame.insetBy(dx: barContentInset, dy: 0)
        let itemWidth = barFrame.width / itemCount
        let itemHeight = barFrame.height

        slotFrames = (0..<itemViews.count).map { index in
            CGRect(x: barFrame.minX + CGFloat(index) * itemWidth, y: 0, width: itemWidth, height: itemHeight)
        }
        let snap = CGPoint(x: contentView.center.x - bounds.midX, y: contentView.center.y - bounds.midY)
        let base = window == nil ? CGPoint.zero : convert(CGPoint(x: snap.x + (itemsContainerView?.frame.minX ?? 0), y: snap.y + (itemsContainerView?.frame.minY ?? 0)), to: nil)
        for (index, itemView) in itemViews.enumerated() {
            itemView.bounds = CGRect(origin: .zero, size: slotFrames[index].size)
            itemView.center = CGPoint(x: slotFrames[index].midX, y: slotFrames[index].midY)
            itemView.pixelOrigin = CGPoint(x: base.x + slotFrames[index].minX, y: base.y + slotFrames[index].minY)
        }
    }

    private func slotFrame(at index: Int) -> CGRect {
        guard index >= 0, index < slotFrames.count else { return .zero }
        return slotFrames[index]
    }

    /// Native's frosted body stops 2 px inside its outline at 3x.
    static let chromeSideInset: CGFloat = 1.0 / 3.0
    static let chromeOutset: CGFloat = 1.0 / 6.0
    static let iOS26PlatterHeight: CGFloat = 62
    static let bodyInset: CGFloat = 2.0 / 3.0

    /// Rim glow per device pixel into the body, read from the native capsule.
    static let darkEdgeGlow: [CGFloat] = [53, 38, 25, 10, 8, 7, 6, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1]
    static let lightEdgeGlow: [CGFloat] = [43, 30, 17, 6, 4, 3, 2, 2, 1, 1]

    private func updateEdgeLayers() {
        let rect = backgroundView.bounds
        guard !rect.isEmpty else { return }
        let margin: CGFloat = 1
        let frame = rect.insetBy(dx: -margin, dy: -margin)
        barEdgeShadeLayer.frame = frame
        barEdgeGlowLayer.frame = frame
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
        let amplitude = usesIOS26Look ? iOS26RimAmplitude() : nil
        let key = [rect.width, rect.height, isDarkAppearance ? 1 : 0] + (amplitude ?? [])
        guard key != barEdgeKey else { return }
        barEdgeKey = key
        let images: (shade: CGImage?, glow: CGImage?)
        if let amplitude {
            images = (nil, Self.iOS26RimImage(size: frame.size, outline: rect.offsetBy(dx: margin, dy: margin), scale: scale, isDark: isDarkAppearance, amplitude: amplitude))
        } else {
            let body = rect.insetBy(dx: Self.bodyInset, dy: Self.bodyInset).offsetBy(dx: margin, dy: margin)
            images = Self.edgeImages(size: frame.size, body: body, scale: scale, isDark: isDarkAppearance)
        }
        barEdgeShadeLayer.contentsScale = scale
        barEdgeGlowLayer.contentsScale = scale
        barEdgeShadeLayer.contents = images.shade
        barEdgeGlowLayer.contents = images.glow
        rebuildChromeCapture()
    }

    /// One composite of chrome, shade and glow for the lens capture, instead of
    /// drawing the edge layers into every capture.
    private func rebuildChromeCapture() {
        let shade = barEdgeShadeLayer.contents.flatMap { CFGetTypeID($0 as CFTypeRef) == CGImage.typeID ? ($0 as! CGImage) : nil }
        guard let snapshot = backgroundGlassView.captureSnapshot,
              let glow = barEdgeGlowLayer.contents,
              CFGetTypeID(glow as CFTypeRef) == CGImage.typeID else {
            backgroundGlassView.captureSnapshotOverride = nil
            return
        }
        let snapshotFrame = backgroundGlassView.captureSnapshotFrame
        let edgeFrame = backgroundView.convert(barEdgeShadeLayer.frame, to: backgroundGlassView)
        let frame = snapshotFrame.union(edgeFrame)
        guard frame.width > 0, frame.height > 0 else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = barEdgeShadeLayer.contentsScale
        format.opaque = false
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: frame.size, format: format).image { context in
            let cg = context.cgContext
            func draw(_ image: CGImage, in rect: CGRect) {
                cg.saveGState()
                cg.translateBy(x: rect.minX - frame.minX, y: rect.maxY - frame.minY)
                cg.scaleBy(x: 1, y: -1)
                cg.draw(image, in: CGRect(origin: .zero, size: rect.size))
                cg.restoreGState()
            }
            draw(snapshot, in: snapshotFrame)
            if let shade {
                draw(shade, in: edgeFrame)
            }
            cg.setBlendMode(.plusLighter)
            draw(glow as! CGImage, in: edgeFrame)
        }
        backgroundGlassView.captureSnapshotOverride = image.cgImage.map { ($0, frame) }
    }

    static let iOS26RimLight: [[CGFloat]] = [
        [1.012, 1.019, 0.435, 0], [1.113, 0.987, 0.385, 0], [1.252, 0.937, 0.334, 0], [1.176, 0.841, 0.308, 0],
        [0.966, 0.748, 0.249, 0], [0.898, 0.600, 0.087, 0], [0.513, 0.389, 0.019, 0]
    ]
    static let iOS26RimDark: [[CGFloat]] = [
        [0.893, 0.687, 0.372, 0], [0.825, 0.636, 0.320, 0], [0.774, 0.575, 0.324, 0.006], [0.648, 0.467, 0.292, 0],
        [0.465, 0.331, 0.184, 0.003], [0.246, 0.171, 0.086, 0], [0.069, 0.021, 0.009, 0]
    ]

    private func iOS26RimAmplitude() -> [CGFloat] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        (backgroundGlassView.renderedCenterColor ?? backgroundGlassView.captureVeilColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        func vibrant(_ value: CGFloat) -> CGFloat {
            let target = isDarkAppearance ? 1.35 * (luma + 2.2222 * (value - luma)) + 0.15 : 0.1 * (luma + 15 * (value - luma)) + 0.9
            return ((min(max(target, 0), 1) - value) * 64).rounded() / 64
        }
        return [vibrant(red), vibrant(green), vibrant(blue)]
    }

    static func iOS26RimImage(size: CGSize, outline: CGRect, scale: CGFloat, isDark: Bool, amplitude: [CGFloat]) -> CGImage? {
        let width = Int((size.width * scale).rounded()), height = Int((size.height * scale).rounded())
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let table = isDark ? iOS26RimDark : iOS26RimLight
        func sample(_ values: [CGFloat], _ position: CGFloat) -> CGFloat {
            guard position < CGFloat(values.count - 1) else { return values[values.count - 1] }
            let index = Int(max(position, 0))
            let fraction = max(position, 0) - CGFloat(index)
            return values[index] + (values[index + 1] - values[index]) * fraction
        }
        let radius = outline.height * scale / 2
        let centerX = outline.midX * scale, centerY = outline.midY * scale
        let straight = outline.width * scale / 2 - radius
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let dx = CGFloat(x) + 0.5 - centerX, dy = CGFloat(y) + 0.5 - centerY
                let qx = abs(dx) - straight, qy = abs(dy)
                var normalX: CGFloat = 0, normalY: CGFloat = dy < 0 ? -1 : 1
                var depth: CGFloat
                if qx > 0 {
                    let length = max((qx * qx + qy * qy).squareRoot(), 0.0001)
                    depth = radius - length
                    normalX = (dx < 0 ? -1 : 1) * qx / length
                    normalY = (dy < 0 ? -1 : 1) * qy / length
                } else {
                    depth = radius - qy
                }
                depth -= CapsuleEnds.inset(along: qx, radius: radius)
                guard depth > 0, depth < CGFloat(table[0].count) else { continue }
                let facing = max(-normalX - normalY, normalX + normalY) / 2.0.squareRoot()
                let spread = acos(min(max(facing, -1), 1)) * 180 / .pi
                let row = min(max(spread / 15, 0), CGFloat(table.count - 1))
                let lower = Int(row), upper = min(Int(row) + 1, table.count - 1)
                let below = sample(table[lower], depth - 0.5), above = sample(table[upper], depth - 0.5)
                let strength = below + (above - below) * (row - CGFloat(lower))
                let offset = (y * width + x) * 4
                for channel in 0..<3 {
                    bytes[offset + 2 - channel] = UInt8(min(max(amplitude[channel] * strength, 0), 1) * 255 + 0.5)
                }
                bytes[offset + 3] = max(bytes[offset], bytes[offset + 1], bytes[offset + 2])
            }
        }
        return bytes.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: space, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)?.makeImage()
        }
    }

    private static func edgeImages(size: CGSize, body: CGRect, scale: CGFloat, isDark: Bool) -> (shade: CGImage?, glow: CGImage?) {
        let width = Int((size.width * scale).rounded()), height = Int((size.height * scale).rounded())
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return (nil, nil) }
        var shade = [UInt8](repeating: 0, count: width * height * 4)
        var glow = [UInt8](repeating: 0, count: width * height * 4)
        let glowProfile = isDark ? darkEdgeGlow : lightEdgeGlow
        let radius = body.height * scale / 2
        let centerX = body.midX * scale, centerY = body.midY * scale
        let straight = body.width * scale / 2 - radius
        func profile(_ values: [CGFloat], at depth: CGFloat) -> CGFloat {
            let position = depth - 0.5
            guard position < CGFloat(values.count - 1) else { return 0 }
            if position <= 0 { return values[0] }
            let index = Int(position)
            let fraction = position - CGFloat(index)
            return values[index] + (values[index + 1] - values[index]) * fraction
        }
        for y in 0..<height {
            for x in 0..<width {
                let dx = CGFloat(x) + 0.5 - centerX, dy = CGFloat(y) + 0.5 - centerY
                let qx = abs(dx) - straight, qy = abs(dy)
                var normalX: CGFloat = 0, normalY: CGFloat = dy < 0 ? -1 : 1
                var distance: CGFloat
                if qx > 0 {
                    let length = max((qx * qx + qy * qy).squareRoot(), 0.0001)
                    distance = length - radius
                    normalX = qx / length
                    normalY = (dy < 0 ? -1 : 1) * qy / length
                } else {
                    distance = qy - radius
                }
                distance += CapsuleEnds.inset(along: qx, radius: radius)
                let side = pow(normalX * normalX, 3)
                let vertical = pow(normalY * normalY, 0.8)
                var shadeAlpha: CGFloat = 0
                var glowLevel: CGFloat = 0
                if distance >= 0 {
                    if distance < 1 {
                        shadeAlpha = isDark ? 0.70 * side : 0.12 + 0.23 * side
                    } else if distance < 2 {
                        shadeAlpha = isDark ? 0.34 * side : 0.06 + 0.11 * side
                    }
                } else {
                    let depth = -distance
                    glowLevel = profile(glowProfile, at: depth) * vertical
                    if normalY < 0 {
                        shadeAlpha = 0.016 * exp(-pow((depth - 33) / 18, 2)) * normalY * normalY
                    }
                    shadeAlpha += 0.021 * exp(-pow(depth / 35, 2)) * normalX * normalX
                }
                let offset = (y * width + x) * 4
                let shadeByte = UInt8(min(max(shadeAlpha, 0), 1) * 255)
                shade[offset + 3] = shadeByte
                let glowByte = UInt8(min(max(glowLevel, 0), 255))
                glow[offset] = glowByte
                glow[offset + 1] = glowByte
                glow[offset + 2] = glowByte
                glow[offset + 3] = glowByte
            }
        }
        func image(_ bytes: inout [UInt8]) -> CGImage? {
            bytes.withUnsafeMutableBytes { buffer -> CGImage? in
                CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                          space: space, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)?.makeImage()
            }
        }
        return (image(&shade), image(&glow))
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                resetAdaptation()
                applyAdaptiveOverride()
                updateAdaptiveAppearance()
                updateAppearanceForCurrentMode()
                if !isDragging {
                    updateItemColors()
                }
            }
        }
    }

    private func updateAppearanceForCurrentMode() {
        let isDark = isDarkAppearance

        applyBarBodyGain(progress: barBodyLift)

        var pillTheme = selectionView.configuration.theme
        let chrome = usesIOS26Look
            ? iOS26ChromeState()
            : Self.iOS27Chrome(isDark: isDark, spectrum: TheseusSettings.shared.tintSpectrum)
        let pill = usesIOS26Look ? iOS26PillState() : (isDark ? Self.iOS27PillDark : Self.iOS27PillLight)
        pillTheme.neutralBodyScale = 0
        pillTheme.bodyPoleMix = 0
        pillTheme.bodyCurve = chrome.knots
        pillTheme.bodyCurveChromaSlope = chrome.chromaSlope
        pillTheme.bodyCurveSaturation = pill.saturation
        pillTheme.backdropSaturation = chrome.chroma
        pillTheme.backdropGain = pill.gain
        pillTheme.luminanceLift = pill.lift
        selectionView.configuration.theme = pillTheme
        selectionView.invalidateBackground()
        updatePillShade(size: selectionView.bounds.size)

        updateBarShadow()
        if adaptLink == nil {
            updateEdgeLayers()
        }
        applyLensMaterial()
    }

    struct BarShadow: Equatable {
        var size: CGSize
        var sigma: CGFloat
        var offset: CGFloat
        var opacity: CGFloat
    }

    private func barShadowSpec(for size: CGSize) -> BarShadow? {
        guard usesIOS26Look else {
            return BarShadow(size: size, sigma: 2.8, offset: 8.03, opacity: 0.012)
        }
        guard !isDarkAppearance else {
            return BarShadow(size: size, sigma: 13, offset: 13, opacity: 0.03)
        }
        let luminance = backgroundGlassView.backdropLuminance ?? 0.5
        let clear = luminance > 237.0 / 255.0 ? 0.069 : 0.18 - 0.05 * min(max((luminance - 0.44) / 0.47, 0), 1)
        let spectrum = min(max(TheseusSettings.shared.tintSpectrum, 0), 1)
        let opacity = clear + (0.099 - clear) * spectrum
        return BarShadow(size: size, sigma: 16.8, offset: 8.8, opacity: (opacity * 200).rounded() / 200)
    }

    private func updateBarShadow() {
        let barFrame = contentBarFrame
        let spec = barShadowSpec(for: barFrame.size)
        let margin = ((spec?.sigma ?? 0) * 3 + (spec?.offset ?? 0)).rounded(.up)
        if contentView.layer.sublayers?.first !== barShadowLayer {
            contentView.layer.insertSublayer(barShadowLayer, at: 0)
        }
        barShadowLayer.frame = barFrame.insetBy(dx: -margin, dy: -margin)
        guard spec != barShadowSize else { return }
        barShadowSize = spec
        guard let spec, spec.size.width > 0, spec.size.height > 0 else {
            barShadowLayer.contents = nil
            return
        }
        let scale: CGFloat = spec.sigma >= 8 ? 1 : 2
        barShadowLayer.contentsScale = scale
        if let cached = barShadowCache.first(where: { $0.spec == spec }) {
            barShadowLayer.contents = cached.image
            return
        }
        let image = Self.shadowImage(bar: spec.size, margin: margin, sigma: spec.sigma, offset: spec.offset, opacity: spec.opacity, scale: scale)
        barShadowLayer.contents = image
        if let image {
            barShadowCache = Array(([(spec, image)] + barShadowCache).prefix(4))
        }
    }

    static func shadowImage(bar: CGSize, margin: CGFloat, sigma: CGFloat, offset: CGFloat, opacity: CGFloat, scale: CGFloat) -> CGImage? {
        let width = Int(((bar.width + 2 * margin) * scale).rounded())
        let height = Int(((bar.height + 2 * margin) * scale).rounded())
        let rows = max(Int((bar.height * scale).rounded()), 1)
        guard width > 0, height > 0 else { return nil }
        let spread = max(sigma * scale, 0.5) * 2.0.squareRoot()
        let radius = bar.height * scale / 2
        let left = margin * scale
        var horizontal = [Float](repeating: 0, count: rows * width)
        for row in 0..<rows {
            let y = CGFloat(row) + 0.5 - radius
            let half = max(radius * radius - y * y, 0).squareRoot()
            let start = left + radius - half
            let end = left + bar.width * scale - radius + half
            for column in 0..<width {
                let x = CGFloat(column) + 0.5
                horizontal[row * width + column] = Float(0.5 * (erfc((x - end) / spread) - erfc((x - start) / spread)))
            }
        }
        let top = (margin + offset) * scale
        let norm = 1 / (max(sigma * scale, 0.5) * (2 * CGFloat.pi).squareRoot())
        var vertical = [Float](repeating: 0, count: height * rows)
        for pixel in 0..<height {
            for row in 0..<rows {
                let distance = (CGFloat(pixel) - CGFloat(row) - top) / max(sigma * scale, 0.5)
                vertical[pixel * rows + row] = Float(norm * exp(-0.5 * distance * distance))
            }
        }
        var coverage = [Float](repeating: 0, count: height * width)
        vDSP_mmul(vertical, 1, horizontal, 1, &coverage, 1, vDSP_Length(height), vDSP_Length(width), vDSP_Length(rows))
        var bytes = [UInt8](repeating: 0, count: height * width * 4)
        for index in 0..<(height * width) {
            bytes[index * 4 + 3] = UInt8(min(max(CGFloat(coverage[index]) * opacity, 0), 1) * 255 + 0.5)
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return bytes.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }

    struct ChromeCurve {
        var knots: [CGFloat]
        var chroma: CGFloat
        var chromaSlope: CGFloat

        func blended(toward other: ChromeCurve, by amount: CGFloat) -> ChromeCurve {
            let t = min(max(amount, 0), 1)
            return ChromeCurve(
                knots: zip(knots, other.knots).map { $0 + ($1 - $0) * t },
                chroma: chroma + (other.chroma - chroma) * t,
                chromaSlope: chromaSlope + (other.chromaSlope - chromaSlope) * t
            )
        }
    }

    static let iOS26ClearLight = ChromeCurve(knots: [0.5602, 0.5937, 0.6272, 0.6607, 0.6902, 0.7211, 0.7490, 0.7858, 0.8275, 0.8645, 0.8931, 0.9181, 0.9422, 0.9634, 0.9812, 0.9945], chroma: 0.239, chromaSlope: 0.495)
    static let iOS26ClearDark = ChromeCurve(knots: [0.0627, 0.0877, 0.1127, 0.1392, 0.1794, 0.2395, 0.2921, 0.3353, 0.3569, 0.3730, 0.3824, 0.3990, 0.4147, 0.4235, 0.4235, 0.4235], chroma: 0.712, chromaSlope: -0.307)
    static let iOS26TintedLight = ChromeCurve(knots: [0.7484, 0.7819, 0.8155, 0.8490, 0.8647, 0.8743, 0.8853, 0.8936, 0.9059, 0.9145, 0.9265, 0.9355, 0.9471, 0.9562, 0.9655, 0.9788], chroma: 0.377, chromaSlope: 0.019)
    static let iOS26TintedDark = ChromeCurve(knots: [0.0823, 0.0948, 0.1074, 0.1196, 0.1333, 0.1488, 0.1627, 0.1760, 0.1922, 0.2049, 0.2211, 0.2336, 0.2471, 0.2647, 0.2983, 0.3318], chroma: 0.767, chromaSlope: 0.029)

    static let iOS27ChromeLight = ChromeCurve(knots: [0.5529, 0.5549, 0.5882, 0.6208, 0.6510, 0.6843, 0.7176, 0.7493, 0.7804, 0.8115, 0.8431, 0.8738, 0.9029, 0.9353, 0.9652, 0.9922], chroma: 0.967, chromaSlope: -0.053)
    static let iOS27ChromeDark = ChromeCurve(knots: [0.1843, 0.1880, 0.2500, 0.3076, 0.3618, 0.4135, 0.4593, 0.5034, 0.5431, 0.5806, 0.6132, 0.6424, 0.6686, 0.6904, 0.7113, 0.7255], chroma: 1.326, chromaSlope: -0.452)
    static let iOS27PillLight = PillMaterial(gain: 1.1338, lift: -0.2057, saturation: 1.0565)
    static let iOS27PillDark = PillMaterial(gain: 0.8665, lift: -0.0676, saturation: 1.3785)

    static func iOS27Chrome(isDark: Bool, spectrum: CGFloat) -> ChromeCurve {
        var config = TheseusConfiguration()
        config.theme.neutralBodyScale = 1
        config.theme.backdropSaturation = isDark ? chromeChromaDark : 1
        config.theme.backdropGain = isDark ? 1.01 : 1
        func model(_ amount: CGFloat) -> (knots: [CGFloat], chroma: CGFloat) {
            let knots = (0..<16).map { TheseusMaterialModel.bodyValue(CGFloat($0) / 15, configuration: config, isDark: isDark, spectrum: amount, style: .iOS27) }
            return (knots, TheseusMaterialModel.chromaScale(configuration: config, isDark: isDark, spectrum: amount) * config.theme.backdropGain)
        }
        let measured = isDark ? iOS27ChromeDark : iOS27ChromeLight
        let here = model(min(max(spectrum, 0), 1)), base = model(0.5)
        return ChromeCurve(
            knots: zip(measured.knots, zip(here.knots, base.knots)).map { $0 + $1.0 - $1.1 },
            chroma: measured.chroma + here.chroma - base.chroma,
            chromaSlope: measured.chromaSlope
        )
    }

    static func iOS26Chrome(isDark: Bool, spectrum: CGFloat) -> ChromeCurve {
        isDark ? iOS26ClearDark.blended(toward: iOS26TintedDark, by: spectrum) : iOS26ClearLight.blended(toward: iOS26TintedLight, by: spectrum)
    }

    struct PillMaterial {
        var gain: CGFloat
        var lift: CGFloat
        var saturation: CGFloat
    }

    static let iOS26PillLight = PillMaterial(gain: 1.1264, lift: -0.1974, saturation: 1.0645)
    static let iOS26PillDark = PillMaterial(gain: 0.956, lift: 0.1358, saturation: 1.1692)

    /// Native dark chrome chroma relative to regular glass.
    static let chromeChromaDark: CGFloat = 1.12

    private func updateSelectionViewFrame(animated: Bool) {
        guard selectedIndex >= 0, selectedIndex < slotFrames.count else { return }

        let frame = selectionFrame(for: slotFrame(at: selectedIndex))
        if selectionView.shape.cornerRadius != frame.height / 2 {
            selectionView.shape.cornerRadius = frame.height / 2
        }

        let bounds = CGRect(origin: .zero, size: frame.size)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        updatePillShade(size: frame.size)
        guard selectionView.bounds != bounds || selectionView.center != center else { return }
        if animated && TheseusSettings.shared.areMorphAnimationsEnabled {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0.75) {
                self.selectionView.bounds = bounds
                self.selectionView.center = center
            }
        } else {
            selectionView.bounds = bounds
            selectionView.center = center
        }
        selectionView.invalidateBackground()
    }

    private func updatePillShade(size: CGSize) {
        let frame = CGRect(origin: .zero, size: size)
        if pillShadeLayer.frame != frame {
            pillShadeLayer.frame = frame
            pillShadeLayer.cornerRadius = size.height / 2
        }
        let colors: [CGColor]
        let locations: [NSNumber]
        if usesIOS26Look {
            colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            locations = [0, 1]
        } else if isDarkAppearance {
            colors = [UIColor(white: 1, alpha: 0.008).cgColor, UIColor(white: 1, alpha: 0).cgColor]
            locations = [0, 0.5]
        } else {
            colors = [UIColor(white: 0, alpha: 0.025).cgColor, UIColor(white: 0, alpha: 0.025).cgColor, UIColor(white: 0, alpha: 0).cgColor]
            locations = [0, 0.19, 0.3]
        }
        if pillShadeLayer.locations != locations { pillShadeLayer.locations = locations }
        if (pillShadeLayer.colors as? [CGColor]) != colors { pillShadeLayer.colors = colors }
    }

    private func selectionFrame(for itemFrame: CGRect) -> CGRect {
        let size = pillSize
        return CGRect(x: itemFrame.midX - size.width / 2, y: itemFrame.midY - size.height / 2, width: size.width, height: size.height)
    }


    private func rebuildItemViews() {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()
        captureTwinRow.subviews.forEach { $0.removeFromSuperview() }

        if itemsContainerView == nil {
            let container = UIView()
            container.backgroundColor = .clear
            container.isUserInteractionEnabled = false
            contentView.addSubview(container)
            itemsContainerView = container
        }

        guard let container = itemsContainerView else { return }

        for (index, item) in items.enumerated() {
            let itemView = TabItemView()
            itemView.configure(with: item, isSelected: index == selectedIndex)
            itemView.tintColor = index == selectedIndex ? selectedTintColor : unselectedTint()
            itemView.onActivate = { [weak self] in
                self?.selectItem(at: index)
            }
            container.addSubview(itemView)
            itemViews.append(itemView)
        }
        accessibilityElements = itemViews
        slotFrames = []
        if isDragging {
            endDragImmediately()
        }
        contentView.bringSubviewToFront(container)
        if captureTwinRow.superview !== contentView { contentView.addSubview(captureTwinRow) }
        contentView.bringSubviewToFront(captureTwinRow)
        contentView.sendSubviewToBack(selectionView)
        contentView.sendSubviewToBack(backgroundView)
    }

    private func applyItemStates(selectedAt selected: Int, animated: Bool) {
        applyItemTints(selectedAt: selected, animated: animated)
    }

    private func applyItemTints(selectedAt selected: Int, animated: Bool) {
        let restingTint = vibrantTint(selectedTintColor, over: selectionView.renderedCenterColor ?? selectionView.captureVeilColor)
        appliedRestingTint = restingTint
        let lensTint = vibrantTint(selectedTintColor, over: lensBackdropColor, plus: lensTintBrightening)
        let unselected = unselectedTint()
        appliedUnselectedTint = unselected
        tintedSelection = selected
        let glow = backgroundGlassView.configuration.flexGlow
        for (index, itemView) in itemViews.enumerated() {
            let isSelected = index == selected
            itemView.lensTint = lensTint
            itemView.updateSelection(
                isSelected: isSelected,
                showsSelectedIcon: isSelected && !isDragging,
                tint: isSelected ? restingTint : glowed(unselected, under: itemView, glow: glow),
                animated: animated
            )
        }
    }

    /// Hides the items for the lens's backdrop pass; they reach the lens only through its item layer.
    private func showCaptureTint(_ shown: Bool) {
        guard let container = itemsContainerView else { return }
        if shown {
            guard !container.isHidden else { return }
            captureTwinRow.frame = container.frame
            itemViews.forEach { $0.syncCaptureTwin(into: captureTwinRow) }
            container.isHidden = true
            itemsHiddenForCapture = true
            let composited = backgroundGlassView.captureSnapshotOverride != nil
            barEdgeShadeLayer.isHidden = composited
            barEdgeGlowLayer.isHidden = composited
        } else if itemsHiddenForCapture {
            container.isHidden = false
            itemsHiddenForCapture = false
            barEdgeShadeLayer.isHidden = false
            barEdgeGlowLayer.isHidden = false
        }
    }

    private static func render(_ views: [UIView], in context: CGContext, to sourceView: UIView, within rect: CGRect) {
        for view in views {
            let transform = affineTransform(from: view, to: sourceView)
            guard view.bounds.applying(transform).intersects(rect) else { continue }
            context.saveGState()
            context.concatenate(transform)
            view.layer.render(in: context)
            context.restoreGState()
        }
    }

    private func drawLensItems(in context: CGContext, from sourceView: UIView) {
        guard itemsHiddenForCapture else { return }
        Self.render(itemViews.map(\.captureTwinView), in: context, to: sourceView, within: context.boundingBoxOfClipPath)
    }

    private static func affineTransform(from view: UIView, to target: UIView) -> CGAffineTransform {
        let origin = view.convert(CGPoint.zero, to: target)
        let unitX = view.convert(CGPoint(x: 1, y: 0), to: target)
        let unitY = view.convert(CGPoint(x: 0, y: 1), to: target)
        return CGAffineTransform(a: unitX.x - origin.x, b: unitX.y - origin.y, c: unitY.x - origin.x, d: unitY.y - origin.y, tx: origin.x, ty: origin.y)
    }

    private func refreshVibrantTints() {
        if backgroundGlassView.configuration.flexGlow == nil, let rendered = backgroundGlassView.renderedCenterColor {
            restGlassColor = rendered
        }
        if isDragging || isCollapsingLens {
            let lensTint = vibrantTint(selectedTintColor, over: lensBackdropColor, plus: lensTintBrightening)
            itemViews.forEach { $0.lensTint = lensTint }
        } else if let current = appliedRestingTint,
                  !current.isClose(to: vibrantTint(selectedTintColor, over: selectionView.renderedCenterColor ?? selectionView.captureVeilColor)) {
            applyItemTints(selectedAt: selectedIndex, animated: false)
        } else if let current = appliedUnselectedTint, !current.isClose(to: unselectedTint()) {
            applyItemTints(selectedAt: selectedIndex, animated: false)
        }
    }

    func unselectedTint() -> UIColor {
        guard unselectedTintColor === Self.nativeUnselectedTint else { return unselectedTintColor }
        if usesIOS26Look {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            glassBehindItems.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let w = min(max(adaptDarkWeight, 0), 1)
            let mapped = 0.1 * luma + (0.951 + 0.045 * luma - 0.1 * luma) * w
            func channel(_ value: CGFloat) -> CGFloat { min(max(mapped + value - luma, 0), 1) }
            return UIColor(red: channel(red), green: channel(green), blue: channel(blue), alpha: 1)
        }
        guard !isDarkAppearance else { return .white }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        glassBehindItems.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> CGFloat { min(max(0.317 * value - 0.254, 0), 1) }
        return UIColor(red: channel(red), green: channel(green), blue: channel(blue), alpha: 1)
    }

    /// Native's vibrant item tint over the glass behind it, from the iOS 27 colour matrix.
    private func vibrantTint(_ tint: UIColor, over glass: UIColor, plus brightening: CGFloat = 0) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        var glassRed: CGFloat = 0, glassGreen: CGFloat = 0, glassBlue: CGFloat = 0, glassAlpha: CGFloat = 0
        tint.resolvedColor(with: contentView.traitCollection).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        glass.getRed(&glassRed, green: &glassGreen, blue: &glassBlue, alpha: &glassAlpha)
        if usesIOS26Look {
            let offset: CGFloat = brightening - 0.5 * (1 - min(max(adaptDarkWeight, 0), 1))
            func channel(_ value: CGFloat, _ behind: CGFloat) -> CGFloat { min(max(value + 0.5 * behind + offset, 0), 1) }
            return UIColor(red: channel(red, glassRed), green: channel(green, glassGreen), blue: channel(blue, glassBlue), alpha: alpha)
        }
        let behind = min(0.299 * glassRed + 0.587 * glassGreen + 0.114 * glassBlue + brightening, 1)
        let shift = isDarkAppearance ? 0.2148 * glassGreen + 0.3778 * glassBlue + 0.5926 * brightening : -0.3 * (1 - behind)
        func channel(_ value: CGFloat) -> CGFloat { min(max(value + shift, 0), 1) }
        return UIColor(red: channel(red), green: channel(green), blue: channel(blue), alpha: alpha)
    }

    private func updateItemColors() {
        applyItemStates(selectedAt: selectedIndex, animated: false)
    }


    private func updateSelection(animated: Bool) {
        applyItemStates(selectedAt: selectedIndex, animated: animated)

        updateSelectionViewFrame(animated: animated)
        updateTheseusFrame()
    }

    private func updateTheseusFrame() {
        // During a drag the SelectionAnimator owns the lens frame.
        guard !isDragging else { return }
        guard selectedIndex >= 0, selectedIndex < slotFrames.count else { return }

        let itemFrame = slotFrame(at: selectedIndex)

        if isCollapsingLens {
            lensMorphAnimator?.retarget(to: convertToTheseusContainer(selectionFrame(for: itemFrame)))
            return
        }

        let glassFrame = glassFrame(for: itemFrame)
        let convertedFrame = convertToTheseusContainer(glassFrame)

        guard let glassView = theseusView else { return }

        // Never CoreAnimation-animate the Metal-backed lens's frame.
        glassView.frame = convertedFrame
        var shape = glassView.shape
        shape.widthInset = 0
        shape.heightInset = 0
        shape.cornerRadius = lensCornerRadius(forHeight: glassFrame.height)
        glassView.shape = shape
    }

    /// Negative is the shader's lens sentinel; the magnitude is the stadium corner radius.
    private func lensCornerRadius(forHeight height: CGFloat) -> CGFloat {
        -(height * 0.5)
    }

    static let iOS27LensOutset: CGFloat = 0.8

    private var lensOutset: CGFloat {
        usesIOS26Look ? 0 : Self.iOS27LensOutset
    }

    private func glassFrame(for itemFrame: CGRect) -> CGRect {
        let size = usesIOS26Look ? Self.iOS26LensSize : Self.lensSize
        return CGRect(x: itemFrame.midX - size.width / 2, y: itemFrame.midY - size.height / 2, width: size.width, height: size.height)
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
        return contentView.convert(frame, to: container)
    }

    private func convertFromTheseusContainer(_ frame: CGRect) -> CGRect {
        guard let container = theseusContainer else { return frame }
        return container.convert(frame, to: contentView)
    }

    private func setupTheseus() {
        guard theseusView == nil else { return }
        guard let container = theseusContainer,
              let sourceView = theseusSourceView else { return }

        var config = TheseusConfiguration.lens
        // Covers the rim and shadow outside the shape, no more: capture cost follows the area.
        config.shape.padding = CGPoint(x: 18, y: 18)
        config.lensChain = TheseusConfiguration.LensChain()
        config.edgeFeather = TheseusTabBar.pillFeather
        config.captureMethod = TheseusCapability.isDeviceSupported ? .layerRendering : .surfaceBased
        config.refraction.magnificationCenterY = 0
        config.refraction.intensity = 1.1
        config.edgeEffects.rimGlow = 0
        config.edgeEffects.glareIntensity = 0
        config.theme.tintColor = glassTint
        config.theme.tintOpacity = glassTintIntensity
        apply(lensMaterial, activity: 0, to: &config)

        let glassView = TheseusView(configuration: config)
        glassView.sourceView = sourceView
        glassView.isHidden = true
        glassView.alpha = 0
        glassView.isUserInteractionEnabled = false

        container.addSubview(glassView)
        theseusView = glassView
        applyAdaptiveOverride()
        glassView.captureWillBegin = { [weak self] in
            self?.showCaptureTint(true)
        }
        glassView.captureDidEnd = { [weak self] in
            self?.showCaptureTint(false)
        }
        glassView.captureItemLayer = { [weak self] context, sourceView in
            self?.drawLensItems(in: context, from: sourceView)
        }
    }

    private func showTheseus() {
        setupTheseus()

        guard let glassView = theseusView,
              let container = theseusContainer else { return }

        if glassView.superview !== container {
            glassView.removeFromSuperview()
            container.addSubview(glassView)
        }
        if let sourceView = theseusSourceView, sourceView.bounds.width > 0 {
            glassView.sourceView = sourceView
        }
        glassView.resumeRendering()
        glassView.continuousUpdate = true
        glassView.invalidateBackground()

        lensMorphAnimator?.cancel()
        selectionAnimator?.cancel()
        isCollapsingLens = false

        setBarLifted(liftsBar)

        guard selectedIndex >= 0, selectedIndex < slotFrames.count else { return }
        let itemFrame = slotFrame(at: selectedIndex)
        let pillFrame = convertToTheseusContainer(selectionFrame(for: itemFrame))
        let lensFrame = convertToTheseusContainer(glassFrame(for: itemFrame))

        let startFrame: CGRect
        let startProgress: CGFloat
        if glassView.isHidden {
            startFrame = pillFrame
            startProgress = 0
        } else {
            startFrame = glassView.frame
            startProgress = lensItemProgress
        }
        // A transform about a fixed frame, not a drawable resize every tick.
        setLensFill(0, rim: startProgress)
        setLensRefraction(startProgress)
        glassView.layer.transform = CATransform3DIdentity
        let lifted = glassFrame(for: itemFrame).size.applying(CGAffineTransform(scaleX: Self.liftScale, y: Self.liftScale))
        let hostFrame = CGRect(x: lensFrame.midX - lifted.width / 2, y: lensFrame.midY - lifted.height / 2, width: lifted.width, height: lifted.height)
        glassView.frame = hostFrame
        var lensShape = glassView.shape
        lensShape.widthInset = -lensOutset
        lensShape.heightInset = -lensOutset
        lensShape.cornerRadius = lensCornerRadius(forHeight: hostFrame.height + 2 * lensOutset)
        glassView.shape = lensShape
        glassView.layer.transform = LensMorph.transform(mapping: hostFrame, onto: startFrame)
        glassView.alpha = 1
        glassView.isHidden = false
        let pillLocal = selectionFrame(for: itemFrame)
        pillRestFrame = pillLocal
        selectionView.layer.transform = CATransform3DIdentity
        selectionView.bounds = CGRect(origin: .zero, size: pillLocal.size)
        selectionView.center = CGPoint(x: pillLocal.midX, y: pillLocal.midY)
        selectionView.shape.cornerRadius = pillLocal.height / 2
        updatePillShade(size: pillLocal.size)
        selectionView.isHidden = false
        fadePill(to: 0, spring: Self.pillFadeOutSpring)
        setLensItemProgress(startProgress)
        if startProgress == 0, TheseusSettings.shared.areMorphAnimationsEnabled {
            startLensStretch()
        }
        var lastFrame = startFrame

        let animator = lensMorphAnimator ?? LensMorphAnimator()
        lensMorphAnimator = animator
        animator.morph(from: startFrame, to: lensFrame, spring: Self.lensGrowSpring, onTick: { [weak self, weak glassView] frame, progress in
            guard let self = self, let glassView = glassView else { return }
            lastFrame = frame
            glassView.layer.transform = self.stretched(LensMorph.transform(mapping: hostFrame, onto: frame))
            let localFrame = self.convertFromTheseusContainer(frame)
            self.selectionView.layer.transform = LensMorph.transform(mapping: pillLocal, onto: localFrame)
            self.updateHoveredItem(lensCenterX: localFrame.midX)
            let grown = startProgress + (1 - startProgress) * progress
            self.setLensItemProgress(grown)
            self.setLensFill(0, rim: min(max(grown, 0), 1))
            self.setLensRefraction(min(max(grown, 0), 1))
        }, onComplete: { [weak self, weak glassView] in
            guard let self = self, let glassView = glassView else { return }
            glassView.layer.transform = self.stretched(CATransform3DIdentity)
            self.placeLens(at: lastFrame)
            self.setLensItemProgress(1)
            self.setLensFill(0, rim: 1)
            self.setLensRefraction(1)
        })

    }

    private func hideTheseus() {
        guard let glassView = theseusView, !glassView.isHidden else {
            pillFadeDriver.stop()
            isPillFading = false
            selectionView.isHidden = false
            selectionView.alpha = 1
            return
        }

        selectionAnimator?.cancel()
        lensMorphAnimator?.cancel()
        stopLensStretch()

        setBarLifted(false)

        guard selectedIndex >= 0, selectedIndex < slotFrames.count else {
            glassView.isHidden = true
            glassView.continuousUpdate = false
            glassView.pauseRendering()
            setLensFill(0, rim: -1)
            pillFadeDriver.stop()
            isPillFading = false
            selectionView.isHidden = false
            selectionView.alpha = 1
            return
        }

        isCollapsingLens = true
        glassView.continuousUpdate = true
        let landingIndex = selectedIndex
        let pillFrame = convertToTheseusContainer(selectionFrame(for: slotFrame(at: landingIndex)))
        let startRim = max(glassView.configuration.lensRimScale, 0)
        let startRefraction = glassView.configuration.lensRefractionScale
        let startProgress = lensItemProgress
        selectionView.layer.transform = CATransform3DIdentity
        selectionView.isHidden = false
        fadePill(to: 1, spring: Self.pillFadeInSpring)
        glassView.layer.transform = CATransform3DIdentity
        let releaseFrame = glassView.frame.insetBy(dx: glassView.shape.widthInset, dy: glassView.shape.heightInset)
        if glassView.shape.widthInset != 0 || glassView.shape.heightInset != 0 {
            glassView.frame = releaseFrame
            var shape = glassView.shape
            shape.widthInset = 0
            shape.heightInset = 0
            shape.cornerRadius = lensCornerRadius(forHeight: releaseFrame.height)
            glassView.shape = shape
        }

        let animator = lensMorphAnimator ?? LensMorphAnimator()
        lensMorphAnimator = animator
        animator.morph(from: releaseFrame, to: pillFrame, spring: Self.lensShrinkSpring, onTick: { [weak self, weak glassView, weak animator] frame, progress in
            guard let self = self, let glassView = glassView else { return }
            glassView.layer.transform = LensMorph.transform(mapping: releaseFrame, onto: frame)
            if landingIndex < self.slotFrames.count {
                animator?.retarget(to: self.convertToTheseusContainer(self.selectionFrame(for: self.slotFrame(at: landingIndex))))
            }
            let remaining = min(max(1 - progress, 0), 1)
            self.setLensFill(0, rim: startRim * remaining)
            self.setLensRefraction(startRefraction * remaining)
            self.setLensItemProgress(startProgress * remaining)
        }, onComplete: { [weak self, weak glassView] in
            guard let self = self else { return }
            self.isCollapsingLens = false
            self.selectionView.isHidden = false
            self.setLensItemProgress(0)
            self.applyItemStates(selectedAt: self.selectedIndex, animated: false)
            if let glassView = glassView {
                glassView.isHidden = true
                glassView.layer.transform = CATransform3DIdentity
                glassView.continuousUpdate = false
                glassView.pauseRendering()
            }
            self.setLensFill(0, rim: -1)
            self.setLensRefraction(1)
        })
    }

    /// Places the lens without resizing its drawable: the bounds keep the lifted
    /// resting size and the shape insets take up the difference.
    private func placeLens(at containerFrame: CGRect) {
        guard let glassView = theseusView else { return }
        let resting = (slotFrames.first.map { glassFrame(for: $0).size } ?? containerFrame.size).applying(CGAffineTransform(scaleX: Self.liftScale, y: Self.liftScale))
        glassView.bounds = CGRect(origin: .zero, size: resting)
        glassView.center = CGPoint(x: containerFrame.midX, y: containerFrame.midY)
        var shape = glassView.shape
        let outset = lensOutset
        shape.widthInset = (resting.width - containerFrame.width) / 2 - outset
        shape.heightInset = (resting.height - containerFrame.height) / 2 - outset
        shape.cornerRadius = lensCornerRadius(forHeight: containerFrame.height + 2 * outset)
        glassView.shape = shape
    }

    private func setLensFill(_ fill: CGFloat, rim: CGFloat) {
        guard let glassView = theseusView else { return }
        var config = glassView.configuration
        let shadow = lensMaterial.shadowOpacity * min(max(rim < 0 ? 1 : rim, 0), 1)
        guard config.lensFill != fill || config.lensRimScale != rim || config.lensShadowOpacity != shadow else { return }
        config.lensFill = fill
        config.lensRimScale = rim
        config.lensShadowOpacity = shadow
        glassView.configuration = config
    }

    private func setLensRefraction(_ share: CGFloat) {
        guard let glassView = theseusView, glassView.configuration.lensRefractionScale != share else { return }
        glassView.configuration.lensRefractionScale = share
    }

    /// Scales only the lens's item twins; the bar's own items never change size.
    private func setLensItemProgress(_ progress: CGFloat) {
        lensItemProgress = progress
        let scale = 1 + (lensMaterial.itemScale - 1) * progress
        let iconScale = 1 + (lensMaterial.iconScale - 1) * progress
        let raster = max(lensMaterial.itemScale, 1) * max(lensMaterial.iconScale, 1) * Self.liftScale
        for itemView in itemViews {
            itemView.lensScale = scale
            itemView.lensIconScale = iconScale
            itemView.lensRasterScale = raster
        }
    }

    /// Mass 1, omega in rad/s; `settle` is how long it runs before it is pinned.
    struct Spring {
        var stiffness: CGFloat
        var damping: CGFloat
        var initialVelocity: CGFloat = 0
        var settle: TimeInterval = 0.6

        init(omega: CGFloat, dampingRatio: CGFloat, initialVelocity: CGFloat = 0, settle: TimeInterval = 0.6) {
            stiffness = omega * omega
            damping = 2 * dampingRatio * omega
            self.initialVelocity = initialVelocity
            self.settle = settle
        }

        func progress(_ t: TimeInterval) -> CGFloat {
            LensMorph.underdamped(t, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity)
        }
    }

    /// Lens, pill, lift and glow springs read frame by frame from the native iOS 27 bar.
    static let lensGrowSpring = Spring(omega: 21.83, dampingRatio: 0.934, initialVelocity: 8.06)
    static let iOS26PressStretch: [(time: TimeInterval, excess: CGFloat)] = [
        (0.32, 0), (0.34, 0.018), (0.37, 0.064), (0.405, 0.092), (0.433, 0.110),
        (0.47, 0.119), (0.54, 0.101), (0.59, 0.083), (0.78, 0.018), (1.02, 0)
    ]
    static let iOS27PressStretch: [(time: TimeInterval, excess: CGFloat)] = [
        (0.31, 0), (0.33, 0.018), (0.36, 0.037), (0.38, 0.055), (0.41, 0.092), (0.46, 0.101),
        (0.56, 0.128), (0.65, 0.096), (0.72, 0.064), (0.78, 0.037), (0.83, 0.028), (0.87, 0.018), (0.92, 0.009), (0.96, 0)
    ]

    private var pressStretchTable: [(time: TimeInterval, excess: CGFloat)] {
        usesIOS26Look ? Self.iOS26PressStretch : Self.iOS27PressStretch
    }

    static func pressStretch(at time: TimeInterval, table: [(time: TimeInterval, excess: CGFloat)] = iOS26PressStretch) -> CGFloat {
        guard let first = table.first, let last = table.last, time > first.time, time < last.time else { return 1 }
        for i in 1..<table.count where time <= table[i].time {
            let (t0, e0) = table[i - 1]
            let (t1, e1) = table[i]
            return 1 + e0 + (e1 - e0) * CGFloat((time - t0) / (t1 - t0))
        }
        return 1
    }

    private func stretched(_ transform: CATransform3D) -> CATransform3D {
        lensStretch == 1 ? transform : CATransform3DScale(transform, 1, lensStretch, 1)
    }

    private func startLensStretch() {
        let table = pressStretchTable
        let end = table.last?.time ?? 0
        lensStretchDriver.run { [weak self] elapsed in
            guard let self = self else { return true }
            let done = elapsed >= end
            self.setLensStretch(done ? 1 : Self.pressStretch(at: elapsed, table: table))
            return done
        }
    }

    private func setLensStretch(_ stretch: CGFloat) {
        guard stretch != lensStretch else { return }
        lensStretch = stretch
        guard let glassView = theseusView, lensMorphAnimator?.isRunning != true else { return }
        glassView.layer.transform = stretched(CATransform3DIdentity)
    }

    private func stopLensStretch() {
        lensStretchDriver.stop()
        lensStretch = 1
    }
    static let lensShrinkSpring = Spring(omega: 23.9, dampingRatio: 0.96, initialVelocity: -1.77)
    static let pillFadeOutSpring = Spring(omega: 25, dampingRatio: 1)
    static let pillFadeInSpring = Spring(omega: 15.22, dampingRatio: 0.978, initialVelocity: 1.83)
    static let liftSpring = Spring(omega: 20.05, dampingRatio: 0.626)
    static let unliftSpring = Spring(omega: 17.48, dampingRatio: 0.601)
    static let bodyGlowSpring = Spring(omega: 33.26, dampingRatio: 0.81)
    static let bodyGlowOffSpring = Spring(omega: 12.15, dampingRatio: 0.968, settle: 0.8)
    static let flexSpreadSpring = Spring(omega: 12.5, dampingRatio: 1, settle: 0.42)

    private func fadePill(to target: CGFloat, spring: Spring) {
        let start = selectionView.alpha
        selectionView.isHidden = false
        isPillFading = true
        pillFadeDriver.run { [weak self] elapsed in
            guard let self = self else { return true }
            let done = elapsed >= spring.settle
            let progress = done ? 1 : min(max(spring.progress(elapsed), 0), 1)
            self.selectionView.alpha = start + (target - start) * progress
            guard done else { return false }
            self.isPillFading = false
            if target <= 0 {
                self.selectionView.isHidden = true
                self.selectionView.layer.transform = CATransform3DIdentity
            }
            return true
        }
    }

    private func setBarLifted(_ lifted: Bool) {
        let animated = TheseusSettings.shared.areMorphAnimationsEnabled
        let gainFrom = barBodyLift
        let gainTo: CGFloat = lifted ? 1 : 0
        if !animated || gainFrom == gainTo {
            bodyGainDriver.stop()
            applyBarBodyGain(progress: gainTo)
        } else {
            let spring = lifted ? Self.bodyGlowSpring : Self.bodyGlowOffSpring
            bodyGainDriver.run { [weak self] elapsed in
                guard let self = self else { return true }
                let done = elapsed >= spring.settle
                let progress = done ? 1 : spring.progress(elapsed)
                self.applyBarBodyGain(progress: gainFrom + (gainTo - gainFrom) * progress)
                return done
            }
        }
        let from = barLift
        let to: CGFloat = lifted ? Self.liftScale : 1
        guard animated, from != to else {
            liftDriver.stop()
            applyBarLift(to)
            return
        }
        let spring = lifted ? Self.liftSpring : Self.unliftSpring
        let frame = LensMorphAnimator.frameInterval
        applyBarLift(from + (to - from) * spring.progress(frame))
        liftDriver.run { [weak self] elapsed in
            guard let self = self else { return true }
            if elapsed >= spring.settle {
                self.applyBarLift(to)
                return true
            }
            self.applyBarLift(from + (to - from) * spring.progress(elapsed + frame))
            return false
        }
    }

    private func applyBarLift(_ scale: CGFloat) {
        let changed = scale != barLift
        barLift = scale
        applyBarTransform()
        if changed {
            backgroundGlassView.invalidateBackground()
        }
        if isDragging {
            selectionAnimator?.refresh()
        }
    }

    /// Shares of the lens's travel the lifted bar slides and stretches by, from native.
    static let followShift: CGFloat = 0.00954
    static let followStretch: CGFloat = 0.0096

    private func applyBarTransform() {
        let pull = max(barLift - 1, 0) / (Self.liftScale - 1)
        let travel = barFollow * pull
        let width = max(contentBarFrame.width, 1)
        let stretch = Self.followStretch * abs(travel) / width
        let transform = CGAffineTransform(
            a: barLift + stretch, b: 0,
            c: 0, d: barLift - stretch,
            tx: Self.followShift * travel, ty: 0
        )
        contentView.transform = transform.isIdentity || (abs(barLift - 1) < 0.0001 && abs(travel) < 0.0001) ? .identity : transform
    }

    private func applyBarBodyGain(progress: CGFloat) {
        barBodyLift = progress
        let isDark = isDarkAppearance
        backgroundView.backgroundColor = .clear
        backgroundGlassView.configuration.theme.neutralBodyScale = 1.0
        let chrome = usesIOS26Look
            ? iOS26ChromeState()
            : Self.iOS27Chrome(isDark: isDark, spectrum: TheseusSettings.shared.tintSpectrum)
        backgroundGlassView.configuration.theme.bodyCurve = chrome.knots
        backgroundGlassView.configuration.theme.bodyCurveChromaSlope = chrome.chromaSlope
        backgroundGlassView.configuration.theme.bodyCurveSaturation = 1
        backgroundGlassView.configuration.theme.backdropSaturation = chrome.chroma
        backgroundGlassView.configuration.theme.backdropGain = 1
        backgroundGlassView.configuration.theme.luminanceLift = 0
        backgroundGlassView.configuration.refraction.interiorSharpness = isDark ? Self.chromeDetailDark : Self.chromeDetailLight
        backgroundGlassView.invalidateBackground()
        theseusView?.configuration.theme.luminanceLift = (isDark ? lensMaterial.liftDark : lensMaterial.lift) * progress
        updateFlexGlow()
    }

    private func startFlexSpread() {
        flexSpreadStarted = true
        let spring = Self.flexSpreadSpring
        flexSpreadDriver.run { [weak self] elapsed in
            guard let self = self else { return true }
            let done = elapsed >= spring.settle
            self.flexSpread = done ? 1 : min(max(spring.progress(elapsed), 0), 1)
            self.updateFlexGlow()
            return done
        }
    }

    private func resetFlexGlow() {
        flexSpreadDriver.stop()
        flexSpread = 0
        flexSpreadStarted = false
        flexReleaseScale = nil
        flexTouchStartX = nil
    }

    private func updateFlexGlow() {
        let progress = min(max(barBodyLift, 0), 1)
        var glow: FlexGlow?
        if progress > 0.001, let center = flexSpotCenter {
            let spread = min(max(flexSpread, 0), 1)
            let scale = flexReleaseScale.map { $0 + (FlexGlow.spotReleaseScale - $0) * (1 - progress) } ?? (1 + spread)
            glow = FlexGlow(
                amount: FlexGlow.alpha * progress,
                spotAmount: FlexGlow.spotAlpha * progress * (1 - spread / 2),
                spotCenter: contentView.convert(center, to: backgroundGlassView),
                spotRadius: FlexGlow.spotRadius * scale
            )
        }
        if backgroundGlassView.configuration.flexGlow != glow {
            backgroundGlassView.configuration.flexGlow = glow
        }
        applyFlexItemTints()
    }

    private func applyFlexItemTints() {
        guard let base = appliedUnselectedTint else { return }
        let glow = backgroundGlassView.configuration.flexGlow
        for (index, itemView) in itemViews.enumerated() where index != tintedSelection {
            let tint = glowed(base, under: itemView, glow: glow)
            if !(itemView.tintColor?.isClose(to: tint) ?? false) {
                itemView.tintColor = tint
            }
        }
    }

    private func glowed(_ tint: UIColor, under itemView: UIView, glow: FlexGlow?) -> UIColor {
        guard let glow else { return tint }
        let center = itemView.convert(CGPoint(x: itemView.bounds.midX, y: itemView.bounds.midY), to: backgroundGlassView)
        return glow.applied(to: tint, at: center)
    }

    private var glassBehindItems: UIColor {
        if backgroundGlassView.configuration.flexGlow != nil, let rest = restGlassColor {
            return rest
        }
        return backgroundGlassView.renderedCenterColor ?? backgroundGlassView.captureVeilColor
    }

    private var lensBackdropColor: UIColor {
        let glass = glassBehindItems
        let lit = backgroundGlassView.configuration.flexGlow.map { $0.applied(to: glass, spot: $0.spotAmount * FlexGlow.spotPeak) } ?? glass
        guard usesIOS26Look, let hold = theseusView?.configuration.nativeLens?.holdingWhite else { return lit }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        lit.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(red: red * hold, green: green * hold, blue: blue * hold, alpha: alpha)
    }

    private var lensTintBrightening: CGFloat {
        usesIOS26Look ? 0 : (isDarkAppearance ? lensMaterial.liftDark : lensMaterial.lift) * barBodyLift
    }

    @objc private func theseusSettingsDidChange() {
        if !usesIOS26Look, adaptLevel != nil || adaptiveDark != nil {
            resetAdaptation()
            applyAdaptiveOverride()
            updateAppearanceForCurrentMode()
        }
        applyBarBodyGain(progress: barBodyLift)
        updateBarShadow()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }


    /// Native magnifies the live bar; no copy of the item is composited over the lens.
    private func updateHoveredItem(lensCenterX: CGFloat) {
        guard isDragging, !itemViews.isEmpty else { return }
        let hovered = findClosestItemIndex(to: CGPoint(x: lensCenterX, y: 0))
        guard hovered != hoveredIndex else { return }
        let isFirst = hoveredIndex < 0
        hoveredIndex = hovered
        if isFirst {
            applyItemTints(selectedAt: -1, animated: true)
        }
    }

    private func endDragImmediately() {
        isDragging = false
        resetFlexGlow()
        hoveredIndex = -1
        currentDragVelocity = .zero
        stopLensActivity()
        selectionAnimator?.cancel()
        lensMorphAnimator?.cancel()
        stopLensStretch()
        isCollapsingLens = false
        if let glassView = theseusView {
            glassView.isHidden = true
            glassView.alpha = 1
            glassView.layer.transform = CATransform3DIdentity
            glassView.continuousUpdate = false
            glassView.pauseRendering()
        }
        setLensFill(0, rim: -1)
        selectionView.layer.transform = CATransform3DIdentity
        selectionView.isHidden = false
        selectionView.alpha = 1
        liftDriver.stop()
        applyBarLift(1)
        bodyGainDriver.stop()
        applyBarBodyGain(progress: 0)
        pillFadeDriver.stop()
        isPillFading = false
        setLensItemProgress(0)
        setLensRefraction(1)
        updateItemColors()
    }


    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              pan.view !== self,
              bounds.contains(pan.location(in: self)) else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = pan.velocity(in: self)
        if abs(velocity.x) >= abs(velocity.y) {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    private func selectItem(at index: Int) {
        guard index != selectedIndex else { return }
        selectedIndex = index
        onItemSelected?(index)
    }

    /// A press lifts the bar on touch down; a tap is a press that ends on the item it began on.
    @_spi(Scripting) public func scriptedTouchBegan(at location: CGPoint) {
        liftsBar = true
        beginInteraction(at: convert(location, to: contentView), rawX: location.x)
    }

    @_spi(Scripting) public func scriptedTouchMoved(to location: CGPoint, velocity: CGPoint) {
        currentDragVelocity = velocity
        if !isCollapsingLens, !isPillFading, !(lensMorphAnimator?.isRunning ?? false) {
            selectionView.alpha = 0
            selectionView.isHidden = true
        }
        followFinger(at: location)
    }

    @_spi(Scripting) public func scriptedTouchEnded(at location: CGPoint) {
        finishInteraction(rawX: location.x)
    }

    @objc private func handlePress(_ gesture: TouchTimestampingPressGestureRecognizer) {
        let location = gesture.location(in: contentView)
        switch gesture.state {
        case .began:
            liftsBar = !gesture.beganAmongOtherTouches
            beginInteraction(at: location, rawX: gesture.location(in: self).x, time: gesture.lastTouchTimestamp)
        case .changed:
            followFinger(at: gesture.location(in: self), time: gesture.lastTouchTimestamp)
        case .ended, .cancelled, .failed:
            finishInteraction(rawX: gesture.location(in: self).x)
        default:
            break
        }
    }

    /// The lens flies to the centre of the pressed item, then moves with the
    /// finger from there with no snap to the item underneath.
    private func beginInteraction(at location: CGPoint, rawX: CGFloat, time: TimeInterval = CACurrentMediaTime()) {
        guard !isDragging, isUserInteractionEnabled else { return }
        isDragging = true
        let anchorX = slotFrames.isEmpty ? rawX : slotFrame(at: findClosestItemIndex(to: CGPoint(x: rawX, y: 0))).midX
        fingerAnchorOffset = anchorX - rawX
        touchDownX = anchorX
        resetFlexGlow()
        flexTouchStartX = rawX
        flexTouchY = location.y
        barFollow = 0
        hoveredIndex = -1
        currentDragVelocity = .zero

        if selectionAnimator == nil {
            selectionAnimator = SelectionAnimator()
            selectionAnimator?.frameForCenterX = { [weak self] x in
                self?.calculateInterpolatedFrame(for: CGPoint(x: x, y: 0))
            }
            selectionAnimator?.onFrameChanged = { [weak self] frame in
                guard let self = self else { return }
                if self.isDragging {
                    self.barFollow = frame.midX - self.touchDownX
                    self.applyBarTransform()
                }
                let containerFrame = self.convertToTheseusContainer(frame)
                self.updateHoveredItem(lensCenterX: frame.midX)
                self.flexSpotCenter = CGPoint(x: frame.midX, y: self.flexTouchY ?? frame.midY)
                self.updateFlexGlow()
                if let morph = self.lensMorphAnimator, morph.isRunning, !self.isCollapsingLens {
                    morph.retarget(to: containerFrame)
                } else {
                    self.placeLens(at: containerFrame)
                    if self.isPillFading, !self.selectionView.isHidden {
                        self.selectionView.layer.transform = LensMorph.transform(mapping: self.pillRestFrame, onto: frame)
                    }
                }
            }
        }

        let restingCenterX: CGFloat
        if let glassView = theseusView, !glassView.isHidden {
            restingCenterX = convertFromTheseusContainer(glassView.layer.frame).midX
        } else {
            restingCenterX = glassFrame(for: slotFrame(at: max(selectedIndex, 0))).midX
        }
        selectionAnimator?.rest(at: restingCenterX)

        showTheseus()
        startLensActivity()
        let now = CACurrentMediaTime()
        followFinger(at: CGPoint(x: rawX, y: location.y), time: time > now - 0.2 ? min(time, now) : now)
    }

    /// `time` is the touch's own timestamp; stamping on arrival turns a
    /// main-thread stall into a burst of fast moves.
    private func followFinger(at location: CGPoint, time: TimeInterval = CACurrentMediaTime()) {
        selectionAnimator?.follow(x: location.x + fingerAnchorOffset, at: time)
        if !flexSpreadStarted, let start = flexTouchStartX, abs(location.x - start) >= FlexGlow.spotTravel {
            startFlexSpread()
        }
    }

    private func finishInteraction(rawX: CGFloat) {
        guard isDragging else { return }
        let landingIndex = findClosestItemIndex(to: CGPoint(x: rawX + fingerAnchorOffset, y: 0))
        if landingIndex != selectedIndex {
            isCommittingDrag = true
            selectedIndex = landingIndex
            isCommittingDrag = false
            onItemSelected?(landingIndex)
        }
        isDragging = false
        hoveredIndex = -1
        currentDragVelocity = .zero
        flexSpreadDriver.stop()
        flexReleaseScale = 1 + flexSpread
        stopLensActivity()
        applyItemTints(selectedAt: selectedIndex, animated: false)
        selectionView.layer.removeAllAnimations()
        updateSelectionViewFrame(animated: false)
        hideTheseus()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: contentView)

        switch gesture.state {
        case .began:
            beginInteraction(at: location, rawX: gesture.location(in: self).x)

        case .changed:
            // UIKit's filtered velocity; finite differences of touch points stutter.
            currentDragVelocity = gesture.velocity(in: self)

            // isHidden, not alpha: a fractional alpha still renders into layer.render captures.
            if !isCollapsingLens, !isPillFading, !(lensMorphAnimator?.isRunning ?? false) {
                selectionView.alpha = 0
                selectionView.isHidden = true
            }

        case .ended, .cancelled:
            finishInteraction(rawX: gesture.location(in: self).x)

        default:
            break
        }
    }

    private func findClosestItemIndex(to point: CGPoint) -> Int {
        var closestIndex = 0
        var minDistance: CGFloat = .greatestFiniteMagnitude

        for (index, slot) in slotFrames.enumerated() {
            let distance = abs(point.x - slot.midX)
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }

        return closestIndex
    }

    /// Points past the end items' centres the lens may run, from native.
    static let lensOverrun: CGFloat = 7.2

    private func calculateInterpolatedFrame(for point: CGPoint) -> CGRect? {
        guard let first = slotFrames.min(by: { $0.midX < $1.midX }),
              let last = slotFrames.max(by: { $0.midX < $1.midX }) else { return nil }
        let centerX = min(max(point.x, first.midX - Self.lensOverrun), last.midX + Self.lensOverrun)
        let baseFrame = glassFrame(for: first)
        return CGRect(x: centerX - baseFrame.width / 2, y: baseFrame.origin.y, width: baseFrame.width, height: baseFrame.height)
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        theseusView?.sourceView = theseusSourceView
    }

    // The lens lives in an ancestor container and would outlive the bar there.
    private func teardownTheseus() {
        stopLensActivity()
        selectionAnimator?.cancel()
        selectionAnimator = nil
        lensMorphAnimator?.cancel()
        lensMorphAnimator = nil
        isCollapsingLens = false
        theseusView?.pauseRendering()
        theseusView?.removeFromSuperview()
        theseusView = nil
        hoveredIndex = -1
        pillFadeDriver.stop()
        isPillFading = false
        selectionView.isHidden = false
        selectionView.alpha = 1
        isDragging = false
        resetFlexGlow()
        bodyGainDriver.stop()
        lensStretchDriver.stop()
        applyBarBodyGain(progress: 0)
        updateItemColors()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            teardownTheseus()
        } else {
            // Pre-warms the lens's Metal pipelines off the interaction path.
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.window != nil else { return }
                self.setupTheseus()
                self.theseusView?.pauseRendering()
                // Layout ran before the window attached.
                if self.backgroundGlassView.sourceView == nil {
                    self.backgroundGlassView.sourceView = self.theseusSourceView
                }
                if self.selectionView.sourceView == nil {
                    self.selectionView.sourceView = self.theseusSourceView
                }
                self.backgroundGlassView.invalidateBackground()
                self.selectionView.invalidateBackground()
            }
        }
    }
}


private class TabItemView: UIView {
    private let iconImageView = UIImageView()
    private let iconBox = UIView()
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    private let captureTwin = UIView()
    var captureTwinView: UIView { captureTwin }
    private let captureIconView = UIImageView()
    private let captureLabel = UILabel()
    private let captureTitleView = UIImageView()
    private var captureTitleSource: (title: String, tint: UIColor, scale: CGFloat, size: CGSize)?
    private var captureIconSource: (image: UIImage, tint: UIColor, scale: CGFloat)?
    private var lensIcon: UIImage?

    var lensTint: UIColor = .systemBlue {
        didSet {
            captureIconView.tintColor = lensTint
            captureLabel.textColor = lensTint
        }
    }

    private var item: TheseusTabBarItem?
    var onActivate: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 1.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        iconBox.isUserInteractionEnabled = false
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconBox)
        addSubview(iconImageView)

        titleLabel.font = TabItemView.titleFont
        titleLabel.textAlignment = .center
        titleLabel.transform = CGAffineTransform(translationX: 0, y: TabItemView.titleNudge)
        stackView.addArrangedSubview(titleLabel)

        captureTwin.isUserInteractionEnabled = false
        captureIconView.contentMode = .scaleToFill
        captureIconView.tintColor = lensTint
        captureTwin.addSubview(captureIconView)
        captureLabel.font = TabItemView.selectedTitleFont
        captureLabel.textAlignment = .center
        captureLabel.textColor = lensTint
        captureTwin.addSubview(captureTitleView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -0.67),
            iconBox.widthAnchor.constraint(equalToConstant: TabItemView.iconSize.width),
            iconBox.heightAnchor.constraint(equalToConstant: TabItemView.iconSize.height)
        ])
    }

    static let iconSize = CGSize(width: 38, height: 28)
    /// Native's titles draw 0.45 px below where the stack lays ours out.
    static let titleNudge: CGFloat = 0.15
    static let titleFont = UIFont.systemFont(ofSize: 10, weight: .medium)
    static let selectedTitleFont = UIFont.systemFont(ofSize: 10, weight: .semibold)

    /// Symbols take native iOS 27's configuration; raster images fit the icon box.
    static func preparedIcon(from image: UIImage?) -> UIImage? {
        guard var image = image else { return nil }
        if #available(iOS 13.0, *), image.isSymbolImage {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .large)
            image = image.applyingSymbolConfiguration(config) ?? image
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stackView.layoutIfNeeded()
        let offset = titleOffset
        titleLabel.transform = CGAffineTransform(translationX: offset.x, y: offset.y)
        let transform = iconImageView.transform
        iconImageView.transform = .identity
        iconImageView.contentMode = isSymbol(iconImageView.image) ? .scaleToFill : .scaleAspectFit
        iconImageView.frame = iconFrame(for: iconImageView.image)
        iconImageView.transform = transform
    }

    private func isSymbol(_ image: UIImage?) -> Bool {
        guard let image = image else { return false }
        if #available(iOS 13.0, *) { return image.isSymbolImage }
        return false
    }

    private func iconFrame(for image: UIImage?) -> CGRect {
        let box = stackView.convert(iconBox.frame, to: self)
        guard let image = image, isSymbol(image) else { return box }
        let insets = image.alignmentRectInsets
        let scale = displayScale
        let centerX = box.midX - (insets.left - insets.right) / 2
        let centerY = box.midY - (insets.top - insets.bottom) / 2
        let offset = pixelOrigin
        let originX = TabItemView.usesIOS26Layout
            ? TabItemView.iOS26Origin(width: image.size.width, center: bounds.midX)
            : ((centerX - image.size.width / 2 + offset.x) * scale).rounded() / scale - offset.x
        let originY = ((centerY - image.size.height / 2 + offset.y) * scale).rounded() / scale - offset.y
        return CGRect(x: originX, y: originY, width: image.size.width, height: image.size.height)
    }

    static let iOS26ButtonWidth: CGFloat = 74

    var pixelOrigin: CGPoint = .zero {
        didSet {
            if pixelOrigin != oldValue { setNeedsLayout() }
        }
    }

    static var usesIOS26Layout: Bool {
        TheseusSettings.shared.effectiveGlassStyle == .iOS26
    }

    static func iOS26Origin(width: CGFloat, center: CGFloat) -> CGFloat {
        center - iOS26ButtonWidth / 2 + ((iOS26ButtonWidth - width) / 2).rounded()
    }

    private var titleOffset: CGPoint {
        let center = stackView.convert(titleLabel.center, to: self)
        let width = titleLabel.bounds.width
        let x = TabItemView.usesIOS26Layout ? TabItemView.iOS26Origin(width: width, center: bounds.midX) - (center.x - width / 2) : 0
        let top = pixelOrigin.y + center.y - titleLabel.bounds.height / 2
        let y = ((top + TabItemView.titleNudge) * displayScale).rounded() / displayScale - top
        return CGPoint(x: x, y: y)
    }

    func configure(with item: TheseusTabBarItem, isSelected: Bool) {
        self.item = item
        setIcon(TabItemView.preparedIcon(
            from: (isSelected ? item.selectedIcon : item.icon) ?? item.icon))
        titleLabel.font = isSelected ? TabItemView.selectedTitleFont : TabItemView.titleFont
        titleLabel.text = item.title
        titleLabel.isHidden = item.title == nil
        lensIcon = TabItemView.preparedIcon(from: item.selectedIcon ?? item.icon)
        captureLabel.text = item.title
        isAccessibilityElement = true
        accessibilityLabel = item.title ?? item.icon?.accessibilityLabel
        accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    }

    override func accessibilityActivate() -> Bool {
        guard let onActivate = onActivate else { return false }
        onActivate()
        return true
    }

    /// `showsSelectedIcon` stays false under the lens: the selected glyph and
    /// semibold title appear only when the selection commits.
    func updateSelection(isSelected: Bool, showsSelectedIcon: Bool, tint: UIColor, animated: Bool) {
        guard let item = item else { return }
        accessibilityTraits = isSelected ? [.button, .selected] : [.button]
        // No selected-state scale: native draws the selected item at its neighbours' size.
        let apply = {
            self.setIcon(TabItemView.preparedIcon(
                from: (showsSelectedIcon ? item.selectedIcon : item.icon) ?? item.icon))
            self.titleLabel.font = showsSelectedIcon ? TabItemView.selectedTitleFont : TabItemView.titleFont
            self.tintColor = tint
        }
        if animated {
            UIView.transition(
                with: self,
                duration: 0.15,
                options: [.transitionCrossDissolve, .beginFromCurrentState],
                animations: apply
            )
        } else {
            apply()
        }
    }

    override var tintColor: UIColor! {
        didSet {
            iconImageView.tintColor = tintColor
            titleLabel.textColor = tintColor
        }
    }

    private var displayScale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : UIScreen.main.scale
    }

    private func setIcon(_ image: UIImage?) {
        iconImageView.image = image
        setNeedsLayout()
    }

    /// Twin bitmaps are rasterised at `lensRasterScale` times the display scale.
    var lensScale: CGFloat = 1
    var lensIconScale: CGFloat = 1
    var lensRasterScale: CGFloat = 1

    func syncCaptureTwin(into row: UIView) {
        if captureTwin.superview !== row { row.addSubview(captureTwin) }
        let scale = displayScale * lensRasterScale
        if let icon = lensIcon, captureIconSource?.image !== icon || captureIconSource?.tint != lensTint || captureIconSource?.scale != scale {
            captureIconSource = (icon, lensTint, scale)
            captureIconView.image = TabItemView.tinted(icon, with: lensTint, scale: scale)
        }
        captureTwin.transform = .identity
        captureTwin.bounds = bounds
        captureTwin.center = center
        captureTwin.transform = CGAffineTransform(scaleX: lensScale, y: lensScale)
        layoutIfNeeded()
        captureIconView.transform = .identity
        captureIconView.contentMode = isSymbol(lensIcon) ? .scaleToFill : .scaleAspectFit
        captureIconView.frame = iconFrame(for: lensIcon)
        captureIconView.transform = CGAffineTransform(scaleX: lensIconScale, y: lensIconScale)
        let title = captureLabel.text ?? ""
        let titleSize = captureLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        let size = CGSize(width: ceil(titleSize.width * displayScale) / displayScale, height: titleLabel.bounds.height)
        if captureTitleSource?.title != title || captureTitleSource?.tint != lensTint || captureTitleSource?.scale != scale || captureTitleSource?.size != size {
            captureTitleSource = (title, lensTint, scale, size)
            captureLabel.bounds = CGRect(origin: .zero, size: size)
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false
            captureTitleView.image = size.width > 0 && size.height > 0
                ? UIGraphicsImageRenderer(size: size, format: format).image { context in captureLabel.layer.render(in: context.cgContext) }
                : nil
        }
        captureTitleView.transform = .identity
        captureTitleView.bounds = CGRect(origin: .zero, size: size)
        let titleCenter = stackView.convert(titleLabel.center, to: self)
        let offset = titleOffset
        let twinX = TabItemView.usesIOS26Layout ? TabItemView.iOS26Origin(width: size.width, center: bounds.midX) + size.width / 2 : titleCenter.x
        captureTitleView.center = CGPoint(x: twinX, y: titleCenter.y + offset.y)
        captureTitleView.isHidden = titleLabel.isHidden
    }

    /// Pre-tinted bitmap: a template image is re-tinted on every capture.
    private static func tinted(_ image: UIImage, with tint: UIColor, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let bitmap = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.withTintColor(tint, renderingMode: .alwaysOriginal).draw(at: .zero)
        }
        return bitmap.withAlignmentRectInsets(image.alignmentRectInsets)
    }

}


/// Touch timestamps are on the `CACurrentMediaTime` clock the follow spring ticks on.
private final class TouchTimestampingPressGestureRecognizer: UILongPressGestureRecognizer {
    private(set) var lastTouchTimestamp: TimeInterval = 0
    private(set) var beganAmongOtherTouches = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        lastTouchTimestamp = touches.first?.timestamp ?? event.timestamp
        beganAmongOtherTouches = (event.allTouches?.count ?? touches.count) > touches.count
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        lastTouchTimestamp = touches.first?.timestamp ?? event.timestamp
        super.touchesMoved(touches, with: event)
    }

}

/// Spring on the lens centre targeting the velocity-led finger, read in the bar's
/// unlifted coordinates. It keeps ticking once settled; a restart from rest costs 40 ms.
private final class SelectionAnimator {
    var onFrameChanged: ((CGRect) -> Void)?
    var frameForCenterX: ((CGFloat) -> CGRect?)?

    deinit { cancel() }

    static let omega: CGFloat = 13.1
    static let flyOmega: CGFloat = 19.75
    static let flyDampingRatio: CGFloat = 0.8
    static let flyDelay: CFTimeInterval = 0.145
    static let flyEndDistance: CGFloat = 1
    static let dampingRatio: CGFloat = 0.66
    static let stoppedDampingRatio: CGFloat = 0.85
    static let startVelocityShare: CGFloat = 0.46
    static let startSpeed: CGFloat = 17
    static let movingSpeed: CGFloat = 67
    static let stoppedSpeed: CGFloat = 33
    static let staleAfter: CFTimeInterval = 0.034
    static let lead: CGFloat = 0.029
    static let restOffset: CGFloat = 0.25
    static let heightAccelerationGain: CGFloat = 1.16e-4
    static let heightFilter: CFTimeInterval = 0.29
    static let heightDelay: CFTimeInterval = 0.053
    static let velocityWindow: CFTimeInterval = 0.025
    static let sampleRetention: CFTimeInterval = 0.25
    static let frameInterval: CGFloat = 1.0 / 60.0

    private var displayLink: DisplayLinkDriver.Link?
    private var lastTick: CFTimeInterval = 0
    private var centerX: CGFloat = 0
    private var velocity: CGFloat = 0
    private var targetFrame: CGRect = .zero
    private var samples: [(t: CFTimeInterval, x: CGFloat)] = []
    private var fingerVelocity: CGFloat = 0
    private var hasStarted = false
    private var isFlying = false
    private var touchDownSampleX: CGFloat?
    private var restingX: CGFloat = 0
    private var flyStart: CFTimeInterval = 0
    private var lastSpeed: CGFloat = 0
    private var motionHistory: [(t: CFTimeInterval, acceleration: CGFloat)] = []
    private var filteredAcceleration: CGFloat = 0

    /// Native's lens height follows its acceleration, not its speed; the width holds.
    private var heightScale: CGFloat {
        let scale = 1 - Self.heightAccelerationGain * filteredAcceleration
        return min(max(scale, 0.9), 1.1)
    }

    private var currentFrame: CGRect {
        let height = targetFrame.height * heightScale
        return CGRect(x: centerX - targetFrame.width / 2, y: targetFrame.midY - height / 2, width: targetFrame.width, height: height)
    }

    private func trackMotion(at timestamp: CFTimeInterval, dt: CGFloat) {
        let speed = abs(velocity)
        let acceleration = (speed - lastSpeed) / max(dt, 0.001)
        lastSpeed = speed
        guard !isFlying else {
            motionHistory.removeAll()
            filteredAcceleration = 0
            return
        }
        motionHistory.append((timestamp, acceleration))
        let cutoff = timestamp - Self.heightDelay
        while motionHistory.count > 1, motionHistory[1].t <= cutoff { motionHistory.removeFirst() }
        guard let delayed = motionHistory.first, delayed.t <= cutoff else { return }
        let blend = 1 - exp(-dt / CGFloat(Self.heightFilter))
        filteredAcceleration += (delayed.acceleration - filteredAcceleration) * blend
    }

    /// `x` is in the bar's unlifted coordinates.
    func follow(x: CGFloat, at time: CFTimeInterval) {
        if let start = touchDownSampleX {
            if abs(x - start) > Self.flyEndDistance { isFlying = false }
        } else {
            touchDownSampleX = x
            flyStart = time + Self.flyDelay
        }
        if let last = samples.last, time - last.t < 0.001 {
            samples[samples.count - 1] = (last.t, x)
        } else {
            samples.append((time, x))
        }
        let cutoff = time - Self.sampleRetention
        samples.removeAll { $0.t < cutoff }

        guard TheseusSettings.shared.areMorphAnimationsEnabled else {
            cancel()
            guard let frame = frameForCenterX?(x) else { return }
            targetFrame = frame
            centerX = frame.midX
            velocity = 0
            onFrameChanged?(frame)
            return
        }

        retarget()
        if displayLink == nil {
            lastTick = time
            displayLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] timestamp in
                self?.update(at: timestamp)
            }
            displayLink?.isPaused = false
        }
    }

    private func retarget() {
        guard let newest = samples.last, let oldest = samples.first else { return }
        let span = min(Self.velocityWindow, newest.t - oldest.t)
        fingerVelocity = span > 0.008 ? (newest.x - sampleX(at: newest.t - span)) / CGFloat(span) : 0
        if !hasStarted, abs(fingerVelocity) > Self.startSpeed {
            velocity += fingerVelocity * Self.startVelocityShare
            hasStarted = true
        }
        retarget(at: newest.t)
    }

    private func retarget(at timestamp: CFTimeInterval) {
        guard let newest = samples.last else { return }
        let x = isFlying && timestamp < flyStart
            ? restingX
            : newest.x + Self.restOffset + fingerVelocity * leadTime(at: timestamp)
        guard let frame = frameForCenterX?(x) else { return }
        targetFrame = frame
    }

    private func isFresh(at timestamp: CFTimeInterval) -> Bool {
        guard let newest = samples.last else { return false }
        return timestamp - newest.t <= Self.staleAfter
    }

    private func leadTime(at timestamp: CFTimeInterval) -> CGFloat {
        isFresh(at: timestamp) ? Self.lead : 0
    }

    private func dampingRatio(at timestamp: CFTimeInterval) -> CGFloat {
        let speed = isFresh(at: timestamp) ? abs(fingerVelocity) : 0
        if speed >= Self.movingSpeed { return Self.dampingRatio }
        if speed <= Self.stoppedSpeed { return Self.stoppedDampingRatio }
        let blend = (speed - Self.stoppedSpeed) / (Self.movingSpeed - Self.stoppedSpeed)
        return Self.stoppedDampingRatio + (Self.dampingRatio - Self.stoppedDampingRatio) * blend
    }

    private func sampleX(at time: CFTimeInterval) -> CGFloat {
        guard let first = samples.first else { return 0 }
        if time <= first.t { return first.x }
        for i in 1..<samples.count where time <= samples[i].t {
            let (t0, x0) = samples[i - 1]
            let (t1, x1) = samples[i]
            let fraction = t1 > t0 ? CGFloat((time - t0) / (t1 - t0)) : 1
            return x0 + (x1 - x0) * fraction
        }
        return samples[samples.count - 1].x
    }

    /// Closed-form spring over the real tick interval, so dropped frames neither slow nor stiffen it.
    private func update(at timestamp: CFTimeInterval) {
        let dt = max(CGFloat(timestamp - lastTick), Self.frameInterval)
        lastTick = timestamp
        guard targetFrame != .zero else { return }
        retarget(at: timestamp)
        let omega = isFlying ? Self.flyOmega : Self.omega
        let zeta = isFlying ? Self.flyDampingRatio : dampingRatio(at: timestamp)
        let offset = centerX - targetFrame.midX
        if zeta < 0.999 {
            let damped = omega * (1 - zeta * zeta).squareRoot()
            let a = offset
            let b = (velocity + zeta * omega * offset) / damped
            let decay = exp(-zeta * omega * dt)
            let c = cos(damped * dt)
            let s = sin(damped * dt)
            centerX = targetFrame.midX + decay * (a * c + b * s)
            velocity = decay * ((damped * b - zeta * omega * a) * c - (damped * a + zeta * omega * b) * s)
        } else {
            let heavy = max(zeta, 1.001)
            let root = omega * (heavy * heavy - 1).squareRoot()
            let slow = -heavy * omega + root
            let fast = -heavy * omega - root
            let bCoefficient = (velocity - offset * slow) / (fast - slow)
            let aCoefficient = offset - bCoefficient
            let slowDecay = exp(slow * dt)
            let fastDecay = exp(fast * dt)
            centerX = targetFrame.midX + aCoefficient * slowDecay + bCoefficient * fastDecay
            velocity = aCoefficient * slow * slowDecay + bCoefficient * fast * fastDecay
        }

        if abs(targetFrame.midX - centerX) < 0.02, abs(velocity) < 1 {
            centerX = targetFrame.midX
            velocity = 0
        }
        trackMotion(at: timestamp, dt: dt)
        onFrameChanged?(currentFrame)
    }

    /// Parks the follow with no target. Until the finger moves, the lens holds
    /// 145 ms after the touch and then flies to the pressed item.
    func rest(at x: CGFloat) {
        cancel()
        restingX = x
        centerX = x
        velocity = 0
        targetFrame = .zero
        samples.removeAll()
        isFlying = true
        touchDownSampleX = nil
        fingerVelocity = 0
        hasStarted = false
        lastSpeed = 0
        motionHistory.removeAll()
        filteredAcceleration = 0
    }

    /// Re-emits the resting frame when the bar lift moves the space under it.
    func refresh() {
        guard displayLink == nil, targetFrame != .zero else { return }
        onFrameChanged?(currentFrame)
    }

    /// A lingering follow tick would fight the morph animator.
    func cancel() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
    }
}

/// Display-link driven: the Metal-backed lens renders at its model size, so a
/// CoreAnimation frame animation would not resize its drawable.
private final class LensMorphAnimator {
    deinit { cancel() }

    private var displayLink: DisplayLinkDriver.Link?
    private var startTime: CFTimeInterval = 0
    private var spring = TheseusTabBar.Spring(omega: 20, dampingRatio: 1)
    private var fromFrame: CGRect = .zero
    private var toFrame: CGRect = .zero
    private var onTick: ((CGRect, CGFloat) -> Void)?
    private var onComplete: (() -> Void)?

    private(set) var isRunning = false

    static let frameInterval: TimeInterval = 1.0 / 60.0

    /// Progress may pass 1 on a lightly damped spring.
    func morph(
        from: CGRect,
        to: CGRect,
        spring: TheseusTabBar.Spring,
        onTick: @escaping (CGRect, CGFloat) -> Void,
        onComplete: @escaping () -> Void
    ) {
        cancel()
        guard TheseusSettings.shared.areMorphAnimationsEnabled else {
            onTick(to, 1)
            onComplete()
            return
        }
        fromFrame = from
        toFrame = to
        self.spring = spring
        self.onTick = onTick
        self.onComplete = onComplete
        startTime = CACurrentMediaTime()
        isRunning = true

        displayLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] _ in
            self?.tick()
        }
        displayLink?.isPaused = false
        tick()
    }

    func retarget(to frame: CGRect) {
        guard isRunning else { return }
        toFrame = frame
    }

    /// Stops without calling `onComplete`.
    func cancel() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
        onTick = nil
        onComplete = nil
    }

    private func tick() {
        let elapsed = CACurrentMediaTime() - startTime + Self.frameInterval
        let raw = spring.progress(elapsed)
        let finished = elapsed >= spring.settle || (elapsed > 0.15 && abs(1 - raw) < 0.002)
        let eased = finished ? 1 : raw
        let frame = CGRect(
            x: fromFrame.origin.x + (toFrame.origin.x - fromFrame.origin.x) * eased,
            y: fromFrame.origin.y + (toFrame.origin.y - fromFrame.origin.y) * eased,
            width: fromFrame.width + (toFrame.width - fromFrame.width) * eased,
            height: fromFrame.height + (toFrame.height - fromFrame.height) * eased
        )
        onTick?(frame, eased)

        if finished {
            let complete = onComplete
            cancel()
            complete?()
        }
    }
}

extension TheseusTabBar: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer.view === self && otherGestureRecognizer.view === self
    }
}

private extension UIColor {
    func isClose(to other: UIColor) -> Bool {
        var a = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0)), b = a
        getRed(&a.0, green: &a.1, blue: &a.2, alpha: &a.3)
        other.getRed(&b.0, green: &b.1, blue: &b.2, alpha: &b.3)
        return max(abs(a.0 - b.0), abs(a.1 - b.1), abs(a.2 - b.2)) < 1.5 / 255
    }
}
