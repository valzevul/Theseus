import UIKit
import Metal
import QuartzCore

/// A UIView subclass that renders Liquid Glass effects using Metal.
public class TheseusView: UIView {

    public var configuration: TheseusConfiguration = TheseusConfiguration() {
        didSet {
            renderer?.updateConfiguration(configuration)
            fallbackView?.configure(with: configuration)
            if oldValue.shape.padding != configuration.shape.padding || oldValue.glassRim != configuration.glassRim {
                setNeedsLayout()
            }
        }
    }

    public var shape: TheseusShape {
        get { configuration.shape }
        set { configuration.shape = newValue }
    }

    public var blur: TheseusBlur {
        get { configuration.blur }
        set { configuration.blur = newValue }
    }

    public var refraction: TheseusRefraction {
        get { configuration.refraction }
        set { configuration.refraction = newValue }
    }

    public var edgeEffects: TheseusEdgeEffects {
        get { configuration.edgeEffects }
        set { configuration.edgeEffects = newValue }
    }

    public var theme: TheseusTheme {
        get { configuration.theme }
        set { configuration.theme = newValue }
    }

    public var morph: TheseusMorphConfiguration {
        get { configuration.morph }
        set { configuration.morph = newValue }
    }

    public var opacity: CGFloat {
        get { configuration.opacity }
        set { configuration.opacity = newValue }
    }

    public weak var sourceView: UIView? {
        didSet {
            renderer?.updateSourceView(sourceView ?? superview)
        }
    }

    /// Called on the main thread once each rendered frame has completed on the
    /// GPU, a vsync before it is on screen.
    public var onPresent: (() -> Void)? {
        didSet { renderer?.onPresent = onPresent }
    }

    /// Keeps a copy of each rendered frame so another glass view capturing
    /// the tree sees this one as rendered, not as a flat veil.
    public var providesCaptureSnapshot: Bool = false {
        didSet { applySnapshotSetting() }
    }

    private(set) var captureSnapshot: CGImage?

    /// What a capture shows in this view's place instead of the bare
    /// snapshot, with its frame in this view's coordinates.
    var captureSnapshotOverride: (image: CGImage, frame: CGRect)?

    /// Called on the main thread whenever `captureSnapshot` is replaced.
    var snapshotDidUpdate: (() -> Void)?

    /// Average colour of the last rendered frame around the centre; nil until a snapshot exists.
    var renderedCenterColor: UIColor? {
        guard let snapshot = captureSnapshot else { return nil }
        let side = 8
        let rect = CGRect(x: snapshot.width / 2 - side / 2, y: snapshot.height / 2 - side / 2, width: side, height: side)
        guard let patch = snapshot.cropping(to: rect),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return nil }
        context.draw(patch, in: CGRect(x: 0, y: 0, width: side, height: side))
        let bytes = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        var sums = [CGFloat](repeating: 0, count: 4)
        for index in 0..<(side * side) {
            for channel in 0..<4 { sums[channel] += CGFloat(bytes[index * 4 + channel]) }
        }
        let count = CGFloat(side * side) * 255
        let alpha = max(sums[3] / count, 0.001)
        return UIColor(red: sums[0] / count / alpha, green: sums[1] / count / alpha, blue: sums[2] / count / alpha, alpha: 1)
    }

    var backdropLuminance: CGFloat? {
        renderer?.lastBackdropColor?.luminance
    }

    var captureSnapshotFrame: CGRect {
        let padding = configuration.drawPadding(for: bounds.size)
        return (metalLayerView?.frame ?? bounds).insetBy(dx: -padding.x, dy: -padding.y)
    }

    private func applySnapshotSetting() {
        metalLayer?.framebufferOnly = !providesCaptureSnapshot
        renderer?.keepsSnapshot = providesCaptureSnapshot
        renderer?.onSnapshot = providesCaptureSnapshot ? { [weak self] image in
            self?.captureSnapshot = image
            self?.snapshotDidUpdate?()
        } : nil
        if providesCaptureSnapshot {
            renderer?.setNeedsRender()
        } else {
            captureSnapshot = nil
        }
    }

    /// Called right before and right after this view captures its backdrop.
    var captureWillBegin: (() -> Void)? {
        didSet { renderer?.willCapture = captureWillBegin }
    }

    var captureDidEnd: (() -> Void)? {
        didSet { renderer?.didCapture = captureDidEnd }
    }

    /// Draws the layer a lens chain bends and composites over the glass, in
    /// the source view's coordinates.
    var captureItemLayer: ((CGContext, UIView) -> Void)? {
        didSet { renderer?.drawItemLayer = captureItemLayer }
    }

    public var continuousUpdate: Bool = false {
        didSet {
            renderer?.continuousUpdate = continuousUpdate
        }
    }

    /// Views hidden from the backdrop capture besides this view, weakly held. A
    /// component whose chrome is a TheseusView passes its own subtree here.
    public func setCaptureExcludedViews(_ views: [UIView]) {
        captureExclusions.removeAllObjects()
        views.forEach { captureExclusions.add($0) }
        syncCaptureExclusions()
    }

    private let captureExclusions = NSHashTable<UIView>.weakObjects()

    private func syncCaptureExclusions() {
        guard let renderer = renderer else { return }
        renderer.extraExcludedViews.removeAllObjects()
        captureExclusions.allObjects.forEach { renderer.extraExcludedViews.add($0) }
    }

    public var isRendering: Bool {
        renderer?.isRendering ?? false
    }

    public var currentQuality: QualityLevel {
        renderer?.currentQuality ?? .medium
    }

    private var renderer: TheseusRenderer?
    private var fallbackView: VisualEffectFallbackView?
    private var isUsingFallback: Bool = false
    private var metalLayerView: UIView?

    // Hierarchy moves and backend switches must not restart a renderer the owner paused.
    private var isRenderPausedByOwner: Bool = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public convenience init(configuration: TheseusConfiguration) {
        self.init(frame: .zero)
        self.configuration = configuration
    }

    private func commonInit() {
        clipsToBounds = false
        backgroundColor = .clear
        isOpaque = false

        let metalContainer = MetalLayerView()
        metalContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalContainer.frame = bounds
        addSubview(metalContainer)
        metalLayerView = metalContainer

        let metalLayer = metalContainer.metalLayer
        metalLayer.masksToBounds = false
        metalLayer.isOpaque = false
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = UIScreen.main.scale
        metalLayer.contentsGravity = .center

        metalLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "contentsScale": NSNull()
        ]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: TheseusSettings.settingsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func settingsDidChange() {
        updateRenderingMode()
        setNeedsLayout()

        // The Metal renderer observes settings itself; only the fallback needs re-configuring.
        if isUsingFallback {
            fallbackView?.configure(with: configuration)
        }
    }

    public var metalLayer: CAMetalLayer? {
        (metalLayerView as? MetalLayerView)?.metalLayer
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()

        if superview != nil {
            updateRenderingMode()
            if !isUsingFallback {
                setupRenderer()
                startRenderingIfAllowed()
            }
        } else {
            renderer?.stopRendering()
            renderer = nil
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if let window = window {
            metalLayer?.contentsScale = window.screen.scale
            startRenderingIfAllowed()
            renderer?.setNeedsRender()
        } else {
            renderer?.stopRendering()
        }
    }

    private func startRenderingIfAllowed() {
        guard !isRenderPausedByOwner, window != nil else { return }
        renderer?.startRendering()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        fallbackView?.frame = bounds

        guard let metalLayer = metalLayer else { return }

        let scale = metalLayer.contentsScale
        let padding = configuration.drawPadding(for: bounds.size)
        let paddingX = padding.x * scale
        let paddingY = padding.y * scale
        let drawableSize = CGSize(
            width: (bounds.width * scale + paddingX * 2).rounded(),
            height: (bounds.height * scale + paddingY * 2).rounded()
        )

        if metalLayer.drawableSize != drawableSize {
            metalLayer.drawableSize = drawableSize
            renderer?.setNeedsRender()
        }
    }

    public func invalidateBackground() {
        renderer?.setNeedsRender()
    }

    /// Renders a frame right away instead of at the next display-link tick.
    public func renderNow() {
        renderer?.renderNow()
    }

    /// Hosts the CAMetalLayer; hidden while another glass captures the tree, since
    /// `layer.render` cannot read Metal contents. Nil on the fallback backend.
    var captureMetalHost: UIView? { metalLayerView }

    /// Flat material stand-in for captures, derived from the shared material model.
    var captureVeilColor: UIColor {
        let isDark: Bool
        if #available(iOS 13.0, *) {
            isDark = traitCollection.userInterfaceStyle == .dark
        } else {
            isDark = configuration.theme.isDark
        }
        let spectrum = TheseusSettings.shared.tintSpectrum
        let backdropColor = renderer?.lastBackdropColor ?? .grey(isDark ? 0.2 : 0.85)
        let veil = configuration.glassRim.map {
            TheseusMaterialModel.veilColor(glassRim: $0, isDark: isDark, spectrum: spectrum, backdrop: backdropColor)
        } ?? TheseusMaterialModel.veilColor(
            configuration: configuration,
            isDark: isDark,
            spectrum: spectrum,
            backdrop: backdropColor
        )
        var tintR: CGFloat = 0, tintG: CGFloat = 0, tintB: CGFloat = 0, tintA: CGFloat = 0
        configuration.theme.tintColor.getRed(&tintR, green: &tintG, blue: &tintB, alpha: &tintA)
        tintA *= min(max(configuration.theme.tintOpacity, 0.0), 1.0)
        let weight = min(max(configuration.theme.surfaceTintWeight, 0.0), 1.0)
        guard tintA * weight > 0.001 else { return veil }
        var veilR: CGFloat = 0, veilG: CGFloat = 0, veilB: CGFloat = 0, veilAlpha: CGFloat = 0
        veil.getRed(&veilR, green: &veilG, blue: &veilB, alpha: &veilAlpha)
        let back = [backdropColor.red, backdropColor.green, backdropColor.blue].map { min(max($0, 0), 1) }
        let veilRGB = [veilR, veilG, veilB]
        let body = (0..<3).map { veilAlpha * veilRGB[$0] + (1 - veilAlpha) * back[$0] }
        let result: [CGFloat]
        if configuration.glassRim != nil {
            let tinted = TheseusConfiguration.GlassRim.tintMatrix(red: tintR, green: tintG, blue: tintB, isDark: isDark).apply(body)
            let share = tintA * weight
            result = (0..<3).map { min(max(body[$0] + share * (tinted[$0] - body[$0]), 0), 1) }
        } else {
            result = TheseusMaterialModel.tinted([tintR, tintG, tintB], alpha: tintA, weight: weight, body: body, model: TheseusMaterialModel.tintModel(isDark: isDark))
        }
        let share = tintA * weight
        return TheseusMaterialModel.veil(producing: result, over: back, minimumAlpha: share + veilAlpha * (1 - share))
    }

    /// Pauses Metal rendering to conserve resources when the view is offscreen or hidden.
    public func pauseRendering() {
        isRenderPausedByOwner = true
        renderer?.isPausedExternally = true
        renderer?.stopRendering()
    }

    /// Resumes Metal rendering; a view outside any window stays idle until it enters one.
    public func resumeRendering() {
        isRenderPausedByOwner = false
        renderer?.isPausedExternally = false
        startRenderingIfAllowed()
    }

    public func setBlurRadius(_ radius: CGFloat, animated: Bool = false) {
        blur.radius = radius
    }

    public func setSigma(_ sigma: CGFloat) {
        blur.sigma = sigma
        renderer?.configuration.blur.sigma = sigma
    }

    /// Stretch/squish for morph animations; each component is clamped to
    /// 0.05...20 and the shader divides by it.
    public func setMorphScale(_ scale: CGPoint) {
        let clamped = CGPoint(
            x: min(max(scale.x, 0.05), 20.0),
            y: min(max(scale.y, 0.05), 20.0)
        )
        morph.scale = clamped
        renderer?.configuration.morph.scale = clamped
        renderer?.setNeedsRender()
    }

    private func setupRenderer() {
        guard renderer == nil, !isUsingFallback else { return }
        guard let metalLayer = metalLayer else { return }

        let effectiveSourceView = sourceView ?? superview
        renderer = TheseusRenderer(
            metalLayer: metalLayer,
            sourceView: effectiveSourceView
        )
        renderer?.hostView = self
        renderer?.configuration = configuration
        renderer?.continuousUpdate = continuousUpdate
        renderer?.onPresent = onPresent
        renderer?.willCapture = captureWillBegin
        renderer?.didCapture = captureDidEnd
        renderer?.drawItemLayer = captureItemLayer
        applySnapshotSetting()
        renderer?.isTintDimmed = tintAdjustmentMode == .dimmed
        renderer?.isPausedExternally = isRenderPausedByOwner
        syncCaptureExclusions()
    }

    private func updateRenderingMode() {
        let shouldUseFallback = TheseusSettings.shared.shouldUseFallback

        guard shouldUseFallback != isUsingFallback else { return }

        isUsingFallback = shouldUseFallback

        if shouldUseFallback {
            renderer?.stopRendering()
            renderer = nil
            metalLayerView?.isHidden = true

            if fallbackView == nil {
                let fb = VisualEffectFallbackView()
                fb.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                fb.frame = bounds
                insertSubview(fb, at: 0)
                fallbackView = fb
            }
            fallbackView?.isHidden = false
            fallbackView?.configure(with: configuration)
            fallbackView?.updateForTraitCollection(traitCollection)
        } else {
            fallbackView?.isHidden = true

            metalLayerView?.isHidden = false
            setupRenderer()
            startRenderingIfAllowed()
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        fallbackView?.updateForTraitCollection(traitCollection)
        renderer?.setNeedsRender()
    }

    /// Sheet dimming: the glass tint desaturates with `tintAdjustmentMode`; the fallback does this itself.
    public override func tintColorDidChange() {
        super.tintColorDidChange()
        renderer?.isTintDimmed = tintAdjustmentMode == .dimmed
    }
}

private class MetalLayerView: UIView {

    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    var metalLayer: CAMetalLayer {
        layer as! CAMetalLayer
    }
}
