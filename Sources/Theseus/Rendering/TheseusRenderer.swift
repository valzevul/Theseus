import Metal
import MetalKit
import QuartzCore
import UIKit
import IOSurface

final class TheseusRenderer: NSObject {

    private weak var metalLayer: CAMetalLayer?
    private weak var sourceView: UIView?

    /// Excluded from the capture so the glass never samples itself.
    weak var hostView: UIView?

    var drawPadding: CGPoint {
        configuration.drawPadding(for: hostView?.bounds.size ?? .zero)
    }

    private func bodyCurveKnots(_ quad: Int) -> SIMD4<Float> {
        guard let curve = configuration.theme.bodyCurve, curve.count == 16 else { return .zero }
        return SIMD4<Float>(Float(curve[quad * 4]), Float(curve[quad * 4 + 1]), Float(curve[quad * 4 + 2]), Float(curve[quad * 4 + 3]))
    }
    private(set) var lastBackdropColor: CaptureColor?

    /// Further views hidden during capture, weakly held. A bar's glass excludes
    /// its own subtree here so it frosts the page behind it, not its own icons.
    let extraExcludedViews = NSHashTable<UIView>.weakObjects()

    private let context: MetalContext
    private let texturePool: TexturePool
    private var viewLayerCapture: ViewLayerCapture?
    private var backgroundCaptureDraw: BackgroundCaptureDraw?
    private let blurKernelCalculator: BlurKernelCalculator
    private let frostCoarseKernel: BlurKernelCalculator
    private let frostFillKernel: BlurKernelCalculator

    private var displayLink: DisplayLinkDriver.Link?
    private(set) var isRendering: Bool = false

    private static let maxFramesInFlight: UInt64 = 3

    // Touched from the render loop, the sync queue and the main thread.
    private let frameCounterLock = NSLock()
    private var _frameCounter: UInt64 = 0
    private var _lastCompletedFrame: UInt64 = 0

    private let frameEvent: MTLSharedEvent

    private var frameCounter: UInt64 {
        get { frameCounterLock.withLock { _frameCounter } }
        set { frameCounterLock.withLock { _frameCounter = newValue } }
    }

    private var lastCompletedFrame: UInt64 {
        get { frameCounterLock.withLock { _lastCompletedFrame } }
        set { frameCounterLock.withLock { _lastCompletedFrame = newValue } }
    }

    private var isShuttingDown: Bool = false

    // Written on the main thread while the render loop reads it.
    private let configurationLock = NSLock()
    private var _configuration: TheseusConfiguration = TheseusConfiguration()

    var configuration: TheseusConfiguration {
        get { configurationLock.withLock { _configuration } }
        set { configurationLock.withLock { _configuration = newValue } }
    }

    var continuousUpdate: Bool = false {
        didSet {
            if continuousUpdate != oldValue {
                // Drags need the full display rate, or the refracted content steps behind the lens.
                updateDisplayLinkFrameRate()
                metalLayer?.presentsWithTransaction = continuousUpdate
            }
        }
    }

    /// Set while the owner has paused rendering on purpose; blocks the app-active
    /// auto-restart, which would otherwise wake every hidden lens.
    var isPausedExternally: Bool = false
    var onPresent: (() -> Void)?

    /// Copies each frame into a CPU-readable texture for `onSnapshot` (main thread),
    /// since `layer.render` cannot read a CAMetalLayer. Needs a non-framebuffer-only drawable.
    var keepsSnapshot = false
    var onSnapshot: ((CGImage) -> Void)?

    /// Run either side of each capture in the same runloop turn, so the owner
    /// can show the capture something the screen never sees.
    var willCapture: (() -> Void)?
    var didCapture: (() -> Void)?
    var drawItemLayer: ((CGContext, UIView) -> Void)?
    private var itemLayerContext: CGContext?
    private var itemLayerTextures: [MTLTexture] = []
    private var itemLayerTextureIndex = 0
    private lazy var clearItemTexture: MTLTexture? = {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead
        let texture = context.device.makeTexture(descriptor: descriptor)
        var pixel: UInt32 = 0
        texture?.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
        return texture
    }()

    /// Mirrors the owner's `tintAdjustmentMode`; the tint desaturates while dimmed.
    var isTintDimmed: Bool = false {
        didSet {
            if isTintDimmed != oldValue {
                setNeedsRender()
            }
        }
    }

    private var needsRender: Bool = true

    private var lastViewFrame: CGRect = .zero
    private var lastSourceBounds: CGRect = .zero

    private(set) var currentQuality: QualityLevel
    private(set) var currentRefractionQuality: RefractionQuality

    init?(metalLayer: CAMetalLayer, sourceView: UIView?) {
        guard let context = MetalContext.shared,
              let frameEvent = context.device.makeSharedEvent() else {
            return nil
        }

        self.context = context
        self.frameEvent = frameEvent
        self.metalLayer = metalLayer
        self.sourceView = sourceView

        self.texturePool = TexturePool(device: context.device)
        self.blurKernelCalculator = BlurKernelCalculator(device: context.device)
        self.frostCoarseKernel = BlurKernelCalculator(device: context.device)
        self.frostFillKernel = BlurKernelCalculator(device: context.device)

        // The backing store, not the property: self is not ready until super.init.
        let settings = TheseusSettings.shared
        self.currentQuality = _configuration.quality ?? context.recommendedQuality
        self.currentRefractionQuality = settings.effectiveRefractionQuality

        super.init()
        setupNotifications()
    }

    deinit {
        stopRendering()
    }

    func startRendering() {
        guard !isRendering else { return }

        currentRefractionQuality = TheseusSettings.shared.effectiveRefractionQuality

        displayLink = DisplayLinkDriver.shared.add(
            framesPerSecond: .fps(continuousUpdate ? 60 : currentRefractionQuality.frameRate),
            priority: .render
        ) { [weak self] _ in
            self?.render()
        }
        displayLink?.isPaused = false
        isRendering = true
        markAllFramesCompleted()
    }

    func stopRendering() {
        guard isRendering else { return }

        isShuttingDown = true

        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
        isRendering = false

        waitForGPUCompletion()
        markAllFramesCompleted()

        isShuttingDown = false
    }

    private func waitForGPUCompletion() {
        guard frameCounter > lastCompletedFrame else { return }

        if let flushBuffer = context.commandQueue.makeCommandBuffer() {
            flushBuffer.commit()
            flushBuffer.waitUntilCompleted()
        }
    }

    private func markAllFramesCompleted() {
        frameCounterLock.withLock { _lastCompletedFrame = _frameCounter }
    }

    func setNeedsRender() {
        needsRender = true
    }

    func renderNow() {
        guard isRendering, !isPausedExternally else { return }
        needsRender = true
        render()
    }

    func updateSourceView(_ view: UIView?) {
        sourceView = view
        viewLayerCapture?.invalidate()
        backgroundCaptureDraw?.invalidate()
        setNeedsRender()
    }

    private func getViewLayerCapture() -> ViewLayerCapture? {
        if viewLayerCapture == nil {
            viewLayerCapture = ViewLayerCapture(device: context.device)
        }
        return viewLayerCapture
    }

    private func getBackgroundCaptureDraw() -> BackgroundCaptureDraw? {
        if backgroundCaptureDraw == nil {
            backgroundCaptureDraw = BackgroundCaptureDraw(device: context.device)
        }
        return backgroundCaptureDraw
    }

    func updateConfiguration(_ config: TheseusConfiguration) {
        let previous = configuration
        configuration = config
        currentQuality = config.quality ?? context.recommendedQuality
        if previous.blur.radius != config.blur.radius
            || previous.blur.effectiveSigma != config.blur.effectiveSigma
            || previous.quality != config.quality {
            blurKernelCalculator.invalidateCache()
        }
        setNeedsRender()
    }

    private func render() {
        guard !isShuttingDown else { return }
        if hostView?.isHidden == true { return }
        guard shouldRender() else { return }

        let framesInFlight = frameCounter - lastCompletedFrame
        guard framesInFlight < Self.maxFramesInFlight else { return }

        guard let metalLayer = metalLayer,
              let drawable = metalLayer.nextDrawable() else {
            return
        }

        frameCounter += 1
        let thisFrameValue = frameCounter

        let didCommit = autoreleasepool {
            performRender(to: drawable, frameValue: thisFrameValue)
        }

        guard didCommit else {
            frameCounter -= 1
            return
        }

        needsRender = false
    }

    private func shouldRender() -> Bool {
        if continuousUpdate { return true }

        if needsRender { return true }

        if let layer = metalLayer {
            let currentFrame = layer.frame
            if currentFrame != lastViewFrame {
                lastViewFrame = currentFrame
                return true
            }
        }

        if let source = sourceView {
            let currentBounds = source.bounds
            if currentBounds != lastSourceBounds {
                lastSourceBounds = currentBounds
                return true
            }
        }

        return false
    }

    /// The owner's item layer, drawn at the capture's region and resolution so it
    /// lines up texel for texel; triple-buffered like the backdrop capture.
    private func renderItemLayer(region: CGRect, scale: CGFloat, sourceView: UIView, draw: (CGContext, UIView) -> Void) -> MTLTexture? {
        let renderScale = (sourceView.window?.screen.scale ?? UIScreen.main.scale) * scale
        let width = Int(ceil(region.width * renderScale - 0.001))
        let height = Int(ceil(region.height * renderScale - 0.001))
        guard width > 0, height > 0 else { return nil }
        if itemLayerContext?.width != width || itemLayerContext?.height != height {
            itemLayerContext = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            )
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            itemLayerTextures = (0..<3).compactMap { _ in context.device.makeTexture(descriptor: descriptor) }
        }
        guard let ctx = itemLayerContext, let data = ctx.data, itemLayerTextures.count == 3 else { return nil }
        ctx.saveGState()
        ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: renderScale, y: -renderScale)
        ctx.translateBy(x: -region.origin.x, y: -region.origin.y)
        UIGraphicsPushContext(ctx)
        draw(ctx, sourceView)
        UIGraphicsPopContext()
        ctx.restoreGState()
        itemLayerTextureIndex = (itemLayerTextureIndex + 1) % 3
        let texture = itemLayerTextures[itemLayerTextureIndex]
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: data, bytesPerRow: ctx.bytesPerRow)
        return texture
    }

    private func performRender(to drawable: CAMetalDrawable, frameValue: UInt64) -> Bool {
        guard let metalLayer = metalLayer,
              let sourceView = sourceView else {
            return false
        }

        let viewFrame = metalLayer.frame
        let captureRegion = calculateCaptureRegion(viewFrame: viewFrame, in: sourceView)

        let renderScale = currentRefractionQuality.renderScale

        let sourceTexture: MTLTexture
        var capturedSurface: IOSurface? = nil

        let excludedViews = ([hostView] + extraExcludedViews.allObjects).compactMap { $0 }
        willCapture?()
        defer { didCapture?() }

        switch configuration.captureMethod {
        case .surfaceBased:
            guard let capture = getViewLayerCapture(),
                  let captureResult = capture.captureTexture(
                    from: sourceView,
                    region: captureRegion,
                    scale: renderScale,
                    excludedViews: excludedViews
                  ) else {
                return false
            }
            sourceTexture = captureResult.texture
            capturedSurface = captureResult.surface
            lastBackdropColor = captureResult.meanColor

        case .layerRendering:
            guard let captureDraw = getBackgroundCaptureDraw(),
                  let capture = captureDraw.captureTexture(
                    from: sourceView,
                    region: captureRegion,
                    scale: renderScale,
                    excludedViews: excludedViews
                  ) else {
                return false
            }
            sourceTexture = capture.texture
            lastBackdropColor = capture.meanColor
        }

        let itemTexture = drawItemLayer.flatMap { renderItemLayer(region: captureRegion, scale: renderScale, sourceView: sourceView, draw: $0) }

        #if DEBUG
        if ProcessInfo.processInfo.environment["THESEUS_DUMP_CAPTURE"] != nil,
           frameValue % 30 == 0 {
            Self.dumpTexture(sourceTexture, name: "theseus_capture")
        }
        #endif

        let pixelsPerPoint = metalLayer.contentsScale * renderScale
        let tintAmount = TheseusConfiguration.GlassRim.frostAmount(spectrum: TheseusSettings.shared.tintSpectrum, style: TheseusSettings.shared.effectiveGlassStyle)
        let glassRim = configuration.glassRim?.styled(TheseusSettings.shared.effectiveGlassStyle)
        let detailSigma = glassRim.map { $0.detailSigma(tintAmount: tintAmount) * pixelsPerPoint }
        let effectiveRadius = detailSigma.map { min(Int(($0 * 3).rounded(.up)), currentQuality.maxBlurRadius) }
            ?? configuration.effectiveBlurRadius(for: currentQuality, pixelsPerPoint: pixelsPerPoint)
        let effectiveSigma = Float(min(detailSigma ?? configuration.effectiveSigma * pixelsPerPoint, CGFloat(effectiveRadius) * 0.5))

        guard let weightsBuffer = blurKernelCalculator.weightsBuffer(
            radius: effectiveRadius,
            sigma: effectiveSigma
        ) else {
            return false
        }

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            return false
        }

        let textureWidth = sourceTexture.width
        let textureHeight = sourceTexture.height

        let usesQuarterBlur = glassRim.map { rim in
            let frost = rim.frost(tintAmount: tintAmount)
            return frost.blend > 0 || frost.cover > 0 || rim.coarseSigma(tintAmount: tintAmount) * pixelsPerPoint >= Self.quarterBlurPixels
        } ?? false
        let averagesInterior = configuration.refraction.interiorAverage > 0 && glassRim == nil
        guard let intermediateTexture1 = texturePool.checkout(width: textureWidth, height: textureHeight) else {
            return false
        }
        guard let intermediateTexture2 = texturePool.checkout(width: textureWidth, height: textureHeight, mipmapped: usesQuarterBlur || averagesInterior) else {
            texturePool.checkin(intermediateTexture1)
            return false
        }

        var blurUniforms = GaussianBlurParams(
            texelSize: SIMD2<Float>(1.0 / Float(textureWidth), 1.0 / Float(textureHeight)),
            blurRadius: Int32(effectiveRadius),
            encodedAverage: glassRim == nil ? 0 : 1
        )

        encodeBlurPass(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: intermediateTexture1,
            uniforms: &blurUniforms,
            weightsBuffer: weightsBuffer,
            isHorizontal: false
        )

        encodeBlurPass(
            commandBuffer: commandBuffer,
            sourceTexture: intermediateTexture1,
            destinationTexture: intermediateTexture2,
            uniforms: &blurUniforms,
            weightsBuffer: weightsBuffer,
            isHorizontal: true
        )

        let frostTextures = glassRim.map { rim in
            encodeFrostBlurs(commandBuffer: commandBuffer, from: intermediateTexture2, rim: rim, tintAmount: tintAmount, pixelsPerPoint: pixelsPerPoint)
        }

        let outputSize = SIMD2<Float>(Float(drawable.texture.width), Float(drawable.texture.height))
        if averagesInterior, intermediateTexture2.mipmapLevelCount > 1,
           let blit = commandBuffer.makeBlitCommandEncoder() {
            let linearView = intermediateTexture2.pixelFormat == .bgra8Unorm
                ? intermediateTexture2.makeTextureView(pixelFormat: .bgra8Unorm_srgb)
                : nil
            blit.generateMipmaps(for: linearView ?? intermediateTexture2)
            blit.endEncoding()
        }

        encodeRefractionCompositePass(
            commandBuffer: commandBuffer,
            blurredTexture: intermediateTexture2,
            originalSourceTexture: sourceTexture,
            itemTexture: itemTexture,
            frostTextures: frostTextures,
            destinationTexture: drawable.texture,
            viewSize: outputSize
        )

        if keepsSnapshot, !drawable.texture.isFramebufferOnly {
            encodeSnapshot(of: drawable.texture, commandBuffer: commandBuffer)
        }

        commandBuffer.encodeSignalEvent(frameEvent, value: frameValue)

        let presentsWithTransaction = metalLayer.presentsWithTransaction
        if !presentsWithTransaction {
            commandBuffer.present(drawable)
        }
        if let onPresent = onPresent {
            commandBuffer.addCompletedHandler { _ in
                DispatchQueue.main.async(execute: onPresent)
            }
        }

        frameEvent.notify(
            context.eventListener,
            atValue: frameValue
        ) { [weak self] _, value in
            // Runs on the serial `com.theseus.sync` queue, not the main thread: everything
            // here goes through a lock, and the capture object is only read, never built.
            guard let self = self else { return }

            self.lastCompletedFrame = value

            self.texturePool.checkin(intermediateTexture1)
            self.texturePool.checkin(intermediateTexture2)
            for texture in frostTextures?.pooled ?? [] {
                self.texturePool.checkin(texture)
            }

            if let surface = capturedSurface {
                self.viewLayerCapture?.recycleSurface(surface)
            }
        }

        commandBuffer.commit()
        if presentsWithTransaction {
            commandBuffer.waitUntilScheduled()
            drawable.present()
        }
        return true
    }

    /// A glass with a lens chain draws through the lens branch, which reads a
    /// negative radius grown by whatever the shape gives up to the rim.
    private var shaderCornerRadius: CGFloat {
        let radius = configuration.shape.cornerRadius
        guard configuration.lensChain != nil, radius > 0 else { return radius }
        return -(radius - min(configuration.shape.widthInset, configuration.shape.heightInset, 0))
    }

    private func interiorAverageLevel(for texture: MTLTexture, viewSize: SIMD2<Float>, scale: CGFloat) -> Float {
        let span = configuration.refraction.interiorAverage
        guard span > 0, texture.mipmapLevelCount > 1, viewSize.x > 0 else { return 0 }
        let texelsPerPoint = Float(texture.width) / (viewSize.x / Float(scale))
        let level = log2(max(Float(span) * texelsPerPoint, 1))
        return min(max(level, 0), Float(texture.mipmapLevelCount - 1))
    }

    /// Blurs at least this wide, in pixels, run at a quarter of the capture size.
    private static let quarterBlurPixels: CGFloat = 8

    /// The frost blurs: `coarse` at full or quarter size, `fill` at a quarter.
    struct FrostTextures {
        var coarse: MTLTexture?
        var fill: MTLTexture?
        var pooled: [MTLTexture] = []
    }

    private func encodeFrostBlurs(
        commandBuffer: MTLCommandBuffer,
        from detail: MTLTexture,
        rim: TheseusConfiguration.GlassRim,
        tintAmount: CGFloat,
        pixelsPerPoint: CGFloat
    ) -> FrostTextures {
        var result = FrostTextures()
        let fine = rim.detailSigma(tintAmount: tintAmount)
        let coarse = rim.coarseSigma(tintAmount: tintAmount)
        let frost = rim.frost(tintAmount: tintAmount)
        let needsCoarse = coarse > fine + 0.01
        let coarseAtQuarter = coarse * pixelsPerPoint >= Self.quarterBlurPixels
        let needsFill = frost.blend > 0 || frost.cover > 0
        var quarter: MTLTexture?
        if (needsFill || (needsCoarse && coarseAtQuarter)), detail.mipmapLevelCount > 2,
           let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: detail)
            blit.endEncoding()
            quarter = detail.makeTextureView(pixelFormat: detail.pixelFormat, textureType: .type2D, levels: 2..<3, slices: 0..<1)
        }
        func blur(_ source: MTLTexture, sigma: CGFloat, texelsPerPoint: CGFloat, kernel: BlurKernelCalculator, width: Int, height: Int) -> MTLTexture? {
            let sigmaTexels = Float(sigma * texelsPerPoint)
            let radius = max(Int((sigmaTexels * 3).rounded(.up)), 1)
            guard let weights = kernel.weightsBuffer(radius: radius, sigma: max(sigmaTexels, 0.01)),
                  let scratch = texturePool.checkout(width: width, height: height) else { return nil }
            guard let destination = texturePool.checkout(width: width, height: height) else {
                texturePool.checkin(scratch)
                return nil
            }
            result.pooled += [scratch, destination]
            var uniforms = GaussianBlurParams(
                texelSize: SIMD2<Float>(1.0 / Float(width), 1.0 / Float(height)),
                blurRadius: Int32(radius),
                encodedAverage: 1
            )
            encodeBlurPass(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: scratch, uniforms: &uniforms, weightsBuffer: weights, isHorizontal: false)
            encodeBlurPass(commandBuffer: commandBuffer, sourceTexture: scratch, destinationTexture: destination, uniforms: &uniforms, weightsBuffer: weights, isHorizontal: true)
            return destination
        }
        var coarseAtQuarterTexture: MTLTexture?
        if needsCoarse {
            let extra = (coarse * coarse - fine * fine).squareRoot()
            if coarseAtQuarter, let quarter = quarter {
                coarseAtQuarterTexture = blur(quarter, sigma: extra, texelsPerPoint: pixelsPerPoint / 4, kernel: frostCoarseKernel, width: quarter.width, height: quarter.height)
                result.coarse = coarseAtQuarterTexture
            } else if !coarseAtQuarter {
                result.coarse = blur(detail, sigma: extra, texelsPerPoint: pixelsPerPoint, kernel: frostCoarseKernel, width: detail.width, height: detail.height)
            }
        }
        if needsFill, let quarter = quarter {
            let source = coarseAtQuarterTexture ?? quarter
            let from = coarseAtQuarterTexture == nil ? fine : coarse
            let extra = (max(rim.fillSigma * rim.fillSigma - from * from, 0)).squareRoot()
            result.fill = blur(source, sigma: extra, texelsPerPoint: pixelsPerPoint / 4, kernel: frostFillKernel, width: quarter.width, height: quarter.height)
        }
        return result
    }

    private func encodeBlurPass(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        uniforms: inout GaussianBlurParams,
        weightsBuffer: MTLBuffer,
        isHorizontal: Bool
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        guard let pipelineState = isHorizontal ? context.horizontalBlurPipelineState : context.verticalBlurPipelineState else {
            encoder.endEncoding()
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(context.quadVertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GaussianBlurParams>.size, index: 0)
        encoder.setFragmentBuffer(weightsBuffer, offset: 0, index: 1)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    /// View points -> drawable pixels (scale plus padding), then divided by the
    /// stretch scale to match the shader's space for the primary shape.
    private func makeMergeShapeArray(scale: CGFloat) -> ([MergeShapeParams], Int) {
        let stretch = configuration.morph.scale
        let padding = drawPadding
        let paddingX = padding.x * scale
        let paddingY = padding.y * scale
        var array = [MergeShapeParams](
            repeating: MergeShapeParams(center: .zero, halfSize: .zero, cornerRadius: 0),
            count: MergeShapeLimits.maxShapes
        )
        let mergedShapes = configuration.shape.mergedShapes.prefix(MergeShapeLimits.maxShapes)
        for (index, shape) in mergedShapes.enumerated() {
            let centerX = (shape.frame.midX * scale + paddingX) / max(stretch.x, 0.0001)
            let centerY = (shape.frame.midY * scale + paddingY) / max(stretch.y, 0.0001)
            array[index] = MergeShapeParams(
                center: SIMD2<Float>(Float(centerX), Float(centerY)),
                halfSize: SIMD2<Float>(
                    Float(shape.frame.width * scale / 2),
                    Float(shape.frame.height * scale / 2)
                ),
                cornerRadius: Float(shape.cornerRadius * scale)
            )
        }
        return (array, mergedShapes.count)
    }

    private func encodeRefractionCompositePass(
        commandBuffer: MTLCommandBuffer,
        blurredTexture: MTLTexture,
        originalSourceTexture: MTLTexture,
        itemTexture: MTLTexture?,
        frostTextures: FrostTextures?,
        destinationTexture: MTLTexture,
        viewSize: SIMD2<Float>
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let scale = metalLayer?.contentsScale ?? 1
        let padding = drawPadding
        let refractionPadding = SIMD2<Float>(
            Float((padding.x + configuration.shape.widthInset) * scale),
            Float((padding.y + configuration.shape.heightInset) * scale)
        )

        var tintR: CGFloat = 0, tintG: CGFloat = 0, tintB: CGFloat = 0, tintA: CGFloat = 0
        configuration.theme.tintColor.getRed(&tintR, green: &tintG, blue: &tintB, alpha: &tintA)

        let spectrum = min(max(TheseusSettings.shared.tintSpectrum, 0.0), 1.0)

        // Branch on colour alpha x intensity, not alpha alone: zero intensity
        // falls back to the neutral body, not to a third state.
        tintA *= min(max(configuration.theme.tintOpacity, 0.0), 1.0)

        let isDarkAppearance = hostView.map {
            $0.traitCollection.userInterfaceStyle == .dark
        } ?? configuration.theme.isDark
        let luminanceLift = TheseusMaterialModel.liftAmount(configuration: configuration)
        let transfer = TheseusMaterialModel.bodyTransfer(
            configuration: configuration,
            isDark: isDarkAppearance,
            spectrum: spectrum,
            style: TheseusSettings.shared.effectiveGlassStyle
        )
        let bodyParams = SIMD4<Float>(
            Float(transfer.poleMix),
            Float(transfer.toneStrength),
            Float(TheseusMaterialModel.gain(configuration: configuration)),
            Float(TheseusMaterialModel.chromaScale(configuration: configuration, isDark: isDarkAppearance, spectrum: spectrum))
        )
        let bodyPole = Float(transfer.pole)

        if isTintDimmed {
            let gray = 0.299 * tintR + 0.587 * tintG + 0.114 * tintB
            tintR = gray
            tintG = gray
            tintB = gray
        }
        let tintModel = TheseusMaterialModel.tintModel(isDark: isDarkAppearance)
        let glassStyle = TheseusSettings.shared.effectiveGlassStyle
        let glassAmount = TheseusConfiguration.GlassRim.frostAmount(spectrum: spectrum, style: glassStyle)
        let styledRim = configuration.glassRim?.styled(glassStyle)
        let glassFace = configuration.glassRim?.face(isDark: isDarkAppearance, tintAmount: spectrum, style: glassStyle)
        let glassTint = configuration.glassRim.map { _ in
            TheseusConfiguration.GlassRim.tintMatrix(red: tintR, green: tintG, blue: tintB, isDark: isDarkAppearance)
        }

        var specFarR: CGFloat = 0, specFarG: CGFloat = 0, specFarB: CGFloat = 0, specFarA: CGFloat = 0
        configuration.edgeEffects.farColor.getRed(&specFarR, green: &specFarG, blue: &specFarB, alpha: &specFarA)

        var specNearR: CGFloat = 0, specNearG: CGFloat = 0, specNearB: CGFloat = 0, specNearA: CGFloat = 0
        configuration.edgeEffects.nearColor.getRed(&specNearR, green: &specNearG, blue: &specNearB, alpha: &specNearA)

        let (mergeShapeArray, mergeShapeCount) = makeMergeShapeArray(scale: scale)

        let lensProfile = configuration.refraction.lensProfile
        let fillColor = LensMorph.sRGBComponents(configuration.lensFillColor.cgColor).map { $0.map(Float.init) } ?? [1, 1, 1, 1]
        var refractionUniforms = GlassParams(
            viewSize: viewSize,
            cornerRadius: Float(shaderCornerRadius * scale),
            opacity: Float(configuration.opacity),
            edgeWidth: Float(configuration.refraction.edgeWidth * scale),
            iorFactor: Float(configuration.refraction.intensity),
            luminanceLift: Float(luminanceLift),
            rimGlow: Float(configuration.edgeEffects.rimGlow),
            lensRiseStart: Float(lensProfile.riseStart),
            lensRiseEnd: Float(lensProfile.riseEnd),
            specularIntensity: Float(configuration.edgeEffects.glareIntensity),
            specularFocus: Float(configuration.edgeEffects.glareFocus),
            lensFrost: Float(lensProfile.frost),
            lensContour: Float(isDarkAppearance ? lensProfile.contourDarkening : lensProfile.contourDarkeningLight),
            oppositeFalloff: Float(configuration.edgeEffects.oppositeFalloff),
            chromaticSpread: Float(configuration.refraction.dispersion),
            mirrorMode: configuration.refraction.reflective ? 1.0 : 0.0,
            bodyPole: bodyPole,
            stretchScale: SIMD2<Float>(
                Float(configuration.morph.scale.x),
                Float(configuration.morph.scale.y)
            ),
            shapePadding: refractionPadding,
            interiorSharpness: Float(min(max(configuration.refraction.interiorSharpness, 0.0), 1.0)),
            magCenterY: Float(configuration.refraction.magnificationCenterY * scale),
            tint: SIMD4<Float>(Float(tintR), Float(tintG), Float(tintB), Float(tintA)),
            farSpecularColor: SIMD4<Float>(Float(specFarR), Float(specFarG), Float(specFarB), Float(specFarA)),
            nearSpecularColor: SIMD4<Float>(Float(specNearR), Float(specNearG), Float(specNearB), Float(specNearA)),
            tintWeights: SIMD4<Float>(
                Float(min(max(configuration.theme.surfaceTintWeight, 0.0), 1.0)),
                Float(min(max(configuration.theme.edgeTintWeight, 0.0), 1.0)),
                Float(min(max(configuration.theme.highlightTintPreservation, 0.0), 1.0)),
                Float(min(max(configuration.theme.edgeIridescence, 0.0), 1.0))
            ),
            mergeParams: SIMD4<Float>(
                Float(mergeShapeCount),
                Float(configuration.shape.mergeSmoothing * scale),
                Float(max(configuration.refraction.magnification, 0.25)),
                Float(max(configuration.refraction.thickness, 1.0) * scale)
            ),
            lensLight: SIMD4<Float>(
                Float(isDarkAppearance ? lensProfile.highlight : lensProfile.highlightLight),
                Float(lensProfile.highlightSide),
                Float(lensProfile.highlightWidth),
                Float(isDarkAppearance ? lensProfile.highlightFade : lensProfile.highlightFadeLight)
            ),
            lensFall: SIMD4<Float>(
                Float(lensProfile.fallStart),
                Float(lensProfile.fallLength),
                Float(isDarkAppearance ? lensProfile.shadeDark : lensProfile.shade),
                Float(lensProfile.shadeReach * scale)
            ),
            bodyParams: bodyParams,
            tintParams: SIMD4<Float>(
                Float(tintModel.threshold),
                Float(tintModel.pole),
                configuration.shape.continuousCapsule ? 1 : 0,
                Float(isDarkAppearance ? lensProfile.highlightBottomDark : lensProfile.highlightBottom)
            ),
            lensRim: SIMD4<Float>(
                Float(isDarkAppearance ? lensProfile.contourSideDark : lensProfile.contourSide),
                Float(isDarkAppearance ? lensProfile.shadeSideDark : lensProfile.shadeSide),
                Float(lensProfile.shadeSideOnset),
                Float(isDarkAppearance ? lensProfile.shadeOnsetDark : lensProfile.shadeOnset)
            ),
            lensRim2: SIMD4<Float>(
                Float(isDarkAppearance ? lensProfile.shadeFloorDark : lensProfile.shadeFloor),
                Float(lensProfile.lip * scale),
                Float(lensProfile.lipReach * scale),
                Float(isDarkAppearance ? lensProfile.highlightTailDark : lensProfile.highlightTail)
            ),
            lensRim3: SIMD4<Float>(
                Float(isDarkAppearance ? lensProfile.contourRampDark : lensProfile.contourRamp),
                Float(isDarkAppearance ? lensProfile.contourSideWidthDark : lensProfile.contourSideWidth),
                Float((isDarkAppearance && lensProfile.shadeSideReachDark > 0 ? lensProfile.shadeSideReachDark : lensProfile.shadeSideReach) * scale),
                Float(lensProfile.shadeShoulder)
            ),
            lensRim4: SIMD4<Float>(
                Float(lensProfile.shadeSideShoulder),
                Float(lensProfile.shadeLobeTilt),
                Float(!isDarkAppearance && lensProfile.highlightLobeLight > 0 ? lensProfile.highlightLobeLight : lensProfile.highlightLobe),
                Float(lensProfile.shadeSideOnsetWidth)
            ),
            lensRim5: SIMD4<Float>(
                Float(isDarkAppearance ? lensProfile.contourChromaDark : lensProfile.contourChroma),
                Float(lensProfile.capExponent),
                Float(isDarkAppearance ? lensProfile.contourFlatDark : lensProfile.contourFlat),
                Float(lensProfile.capExponentTip)
            ),
            lensRim6: SIMD4<Float>(Float(configuration.lensFill), Float(configuration.lensRimScale), Float(configuration.refraction.rimDispersion * scale), Float(configuration.refraction.rimDispersionDepth * scale)),
            lensRim7: SIMD4<Float>(fillColor[0], fillColor[1], fillColor[2], interiorAverageLevel(for: blurredTexture, viewSize: viewSize, scale: scale)),
            lensRim8: SIMD4<Float>(Float(configuration.lensShadowOpacity), Float(configuration.lensShadowOffset * scale), Float(configuration.lensShadowRadius * scale), Float(lensProfile.shadeTopLobeShift)),
            lensRim9: SIMD4<Float>(Float(lensProfile.shadeCapOnsetShare), Float(lensProfile.shadeTopExponent), Float(lensProfile.shadeSideExponent), lensProfile.highlightInLinearLight ? 1 : 0),
            shapeEdge: SIMD4<Float>(Float(configuration.outerGlow), Float(configuration.edgeFeather * scale), Float(configuration.lensRefractionScale), lensProfile.capOutlineOnly ? 1 : 0),
            chainWarp: configuration.lensChain.map { SIMD4<Float>(Float($0.backdropWarp * scale), Float($0.backdropWarpHeight * scale), Float($0.inset * scale), $0.warpIgnoresShare ? 1 : 0) } ?? .zero,
            chainItems: configuration.lensChain.map { SIMD4<Float>(Float($0.itemWarp * scale), Float($0.itemLensing * scale), Float($0.itemWarpHeight * scale), Float($0.ovalization)) } ?? .zero,
            chainSplit: configuration.lensChain.map { SIMD4<Float>(Float($0.aberration * scale), Float($0.aberrationBand * scale), Float($0.aberrationFade * scale), $0.detailBlurred ? 2 : 1) } ?? .zero,
            chainInner: configuration.lensChain.map { chain in
                let side = min(CGFloat(viewSize.x) / scale - 2 * padding.x, CGFloat(viewSize.y) / scale - 2 * padding.y)
                let inner = chain.innerRefractionPerSide > 0 ? min(chain.innerRefractionPerSide * side, chain.innerRefractionCap > 0 ? chain.innerRefractionCap : .greatestFiniteMagnitude) : chain.innerRefraction
                let innerHeight = chain.innerHeightPerSide > 0 ? min(chain.innerHeightPerSide * side, chain.innerHeightCap) : chain.innerRefractionHeight
                let refraction = styledRim?.innerRefraction(shortSide: side) ?? (inner, innerHeight)
                return SIMD4<Float>(Float(refraction.amount * scale), Float(refraction.height * scale), Float(min(max(chain.frost, 0), 1)), Float(max(chain.itemRimFade, 0) * scale))
            } ?? .zero,
            tintModel: SIMD4<Float>(
                Float(tintModel.gain),
                Float(tintModel.offset),
                Float(tintModel.closing),
                Float(tintModel.toPole)
            ),
            glassRim: styledRim.map { rim in
                SIMD4<Float>(rim.generation == .iOS26 ? 2 : 1, Float(isDarkAppearance ? rim.bandSpreadDark : rim.bandSpreadLight), Float(rim.bandOvalization), Float(rim.bandBias))
            } ?? .zero,
            glassShadow: styledRim.map { rim in
                let shortSide = min(CGFloat(viewSize.x) / scale - 2 * padding.x, CGFloat(viewSize.y) / scale - 2 * padding.y)
                return SIMD4<Float>(
                    Float(rim.ringShadowOpacity),
                    Float(rim.dropShadowAmount(isDark: isDarkAppearance, shortSide: shortSide)),
                    Float(rim.shadowSigma(shortSide: shortSide) * scale),
                    Float(TheseusConfiguration.GlassRim.dropShadowOffset * scale)
                )
            } ?? .zero,
            glassHighlight: styledRim.map { rim in
                let matrix = rim.highlight(isDark: isDarkAppearance)
                return SIMD4<Float>(matrix.x, matrix.y, matrix.z, isDarkAppearance || rim.generation == .iOS26 ? 0 : 1)
            } ?? .zero,
            glassScale: SIMD4<Float>(Float(scale), Float((styledRim?.outerRefractionFullDepth ?? 0) * scale), 0, 0),
            glassBlur: styledRim.map { rim in
                let frost = rim.frost(tintAmount: glassAmount)
                return SIMD4<Float>(Float(frost.blend), Float(frost.cover), isDarkAppearance ? 1 : 0, frostTextures?.coarse == nil ? 0 : 1)
            } ?? .zero,
            glassBlurOpacity: styledRim.map { rim in
                let shortSide = min(CGFloat(viewSize.x) / scale - 2 * padding.x, CGFloat(viewSize.y) / scale - 2 * padding.y)
                return SIMD4<Float>(Float(rim.blurRadiusDeep), Float(rim.blurRadiusNearRim), Float(rim.blurRadiusAtRim), Float(shortSide / 2 * scale))
            } ?? .zero,
            glassBlurSigma: styledRim.map { rim in
                SIMD4<Float>(
                    Float(rim.blurSigma(tintAmount: glassAmount) * scale),
                    Float(TheseusConfiguration.GlassRim.blurSoftness * scale),
                    Float(rim.detailSigma(tintAmount: glassAmount) * scale),
                    Float(rim.coarseSigma(tintAmount: glassAmount) * scale)
                )
            } ?? .zero,
            glassFace: glassFace.map { SIMD4<Float>(Float($0.black), Float($0.white), Float($0.saturation), Float($0.maxLuma)) } ?? .zero,
            glassFaceFill: glassFace?.fill ?? .zero,
            glassOuter: styledRim.map { rim in
                let shortSide = min(CGFloat(viewSize.x) / scale - 2 * padding.x, CGFloat(viewSize.y) / scale - 2 * padding.y)
                let outer = rim.outerRefraction(shortSide: shortSide)
                return SIMD4<Float>(Float(outer.amount * scale), Float(outer.height * scale), Float(rim.outerRefractionShare), Float(scale))
            } ?? .zero,
            glassTintRed: glassTint?.red ?? .zero,
            glassTintGreen: glassTint?.green ?? .zero,
            glassTintBlue: glassTint?.blue ?? .zero,
            bodyCurve0: bodyCurveKnots(0),
            bodyCurve1: bodyCurveKnots(1),
            bodyCurve2: bodyCurveKnots(2),
            bodyCurve3: bodyCurveKnots(3),
            bodyCurveInfo: SIMD4<Float>(configuration.theme.bodyCurve?.count == 16 ? 1 : 0, Float(configuration.theme.bodyCurveChromaSlope), Float(configuration.theme.bodyCurveSaturation), 0)
        )
        let lensLift = applyNativeLens(configuration.nativeLens, to: &refractionUniforms, scale: scale)
        applyFlexGlow(configuration.flexGlow, to: &refractionUniforms, scale: scale)
        refractionUniforms.lens26ShadowOffset.z = Float(configuration.shapeOffset.x * scale)
        refractionUniforms.lens26ShadowOffset.w = Float(configuration.shapeOffset.y * scale)
        if let chain = configuration.lensChain {
            refractionUniforms.lens26Items.x = Float((chain.itemLensingHeight > 0 ? chain.itemLensingHeight : chain.itemWarpHeight) * scale) * lensLift
        }

        encoder.setRenderPipelineState(context.refractionCompositePipelineState)
        encoder.setVertexBuffer(context.quadVertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(blurredTexture, index: 0)
        encoder.setFragmentTexture(originalSourceTexture, index: 1)
        encoder.setFragmentTexture(itemTexture ?? clearItemTexture, index: 2)
        encoder.setFragmentTexture(frostTextures?.coarse ?? clearItemTexture, index: 3)
        encoder.setFragmentTexture(frostTextures?.fill ?? clearItemTexture, index: 4)
        encoder.setFragmentBytes(&refractionUniforms, length: MemoryLayout<GlassParams>.size, index: 0)
        mergeShapeArray.withUnsafeBytes { buffer in
            encoder.setFragmentBytes(buffer.baseAddress!, length: buffer.count, index: 1)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    private func applyFlexGlow(_ glow: FlexGlow?, to uniforms: inout GlassParams, scale: CGFloat) {
        guard let glow, glow.amount > 0 || glow.spotAmount > 0 else { return }
        let s = Float(scale)
        uniforms.flexGlow = SIMD4(Float(glow.amount), Float(glow.spotAmount * FlexGlow.spotPeak), Float(FlexGlow.spotWidth * glow.spotRadius) * s, 0)
        let padding = drawPadding
        uniforms.flexGlowCenter = SIMD4(Float((glow.spotCenter.x + padding.x) * scale), Float((glow.spotCenter.y + padding.y) * scale), 0, 0)
        uniforms.flexBigRed = FlexGlow.matrix[0]
        uniforms.flexBigGreen = FlexGlow.matrix[1]
        uniforms.flexBigBlue = FlexGlow.matrix[2]
    }

    @discardableResult
    private func applyNativeLens(_ lens: NativeLens26?, to uniforms: inout GlassParams, scale: CGFloat) -> Float {
        guard let lens else { return 1 }
        var transform: Float = 1
        if lens.baseHeight > 0 {
            let visible = (uniforms.viewSize.y - 2 * uniforms.shapePadding.y) * uniforms.stretchScale.y / Float(scale)
            transform = visible / Float(lens.baseHeight)
            uniforms.chainWarp.x *= transform
            uniforms.chainWarp.y *= transform
            uniforms.chainItems.x *= transform
            uniforms.chainItems.y *= transform
            uniforms.chainItems.z *= transform
            uniforms.chainInner.x *= transform
            uniforms.chainInner.y *= transform
        }
        uniforms.lens26 = SIMD4(1, Float(scale), Float(lens.faceBlack), Float(lens.faceWhite))
        uniforms.lens26Face = SIMD4(Float(lens.faceSaturation), Float(lens.holdingWhite), Float(lens.holdingStart), Float(lens.holdingEnd))
        uniforms.lens26BlurDistance = lens.blurDistances
        uniforms.lens26BlurOpacity = lens.blurOpacities
        uniforms.lens26Blur = SIMD4(Float(lens.blurRadius * 1.6), Float(lens.innerShadowOpacity), Float(lens.innerShadowRadius) * transform, Float(lens.innerShadowOffset) * transform)
        let aberrationScale = lens.baseHeight > 0 ? (uniforms.viewSize.y - 2 * uniforms.shapePadding.y) * uniforms.stretchScale.y / Float(scale) / Float(lens.baseHeight) : 1
        uniforms.lens26Aberration = SIMD4(Float(lens.aberration) * aberrationScale, Float(lens.aberrationOffset), Float(lens.edgeStart), Float(lens.edgeEnd))
        uniforms.lens26AberrationAngle = SIMD4(Float(cos(lens.aberrationAngle)), Float(sin(lens.aberrationAngle)), Float(lens.shadowFaceOpacity), Float(lens.shadowOpacity))
        uniforms.lens26Shadow = SIMD4(lens.shadowFill.x, lens.shadowFill.y, lens.shadowFill.z, Float(lens.shadowRadius))
        let lights = Array(lens.highlights.prefix(2))
        uniforms.lens26ShadowOffset = SIMD4(Float(lens.shadowOffset), Float(lights.count), 0, 0)
        var line = SIMD4<Float>.zero
        for (index, light) in lights.enumerated() {
            let key = SIMD4(light.key.x, light.key.y, Float(cos(light.spread)), light.remap)
            let rows = light.matrix + Array(repeating: SIMD4<Float>.zero, count: max(0, 3 - light.matrix.count))
            if index == 0 {
                uniforms.lens26Key0 = key
                uniforms.lens26Red0 = rows[0]
                uniforms.lens26Green0 = rows[1]
                uniforms.lens26Blue0 = rows[2]
                line.x = Float(light.curvature)
                line.y = Float(light.height)
            } else {
                uniforms.lens26Key1 = key
                uniforms.lens26Red1 = rows[0]
                uniforms.lens26Green1 = rows[1]
                uniforms.lens26Blue1 = rows[2]
                line.z = Float(light.curvature)
                line.w = Float(light.height)
            }
        }
        uniforms.lens26Line = line
        return transform
    }

    /// The capture region must equal the drawable's extent exactly: the shader samples
    /// it at the drawable's normalised coordinates, so any extra margin rescales the view.
    private func calculateCaptureRegion(viewFrame: CGRect, in sourceView: UIView) -> CGRect {
        let padding = drawPadding
        guard let metalLayer = metalLayer,
              let superlayer = metalLayer.superlayer else {
            return viewFrame.insetBy(dx: -padding.x, dy: -padding.y)
        }

        var frameInSource = viewFrame

        // Convert through the presentation tree only while an animation is in flight;
        // otherwise the model is fresher, and the presentation trails it by a commit.
        let superAnimating = superlayer.animationKeys()?.isEmpty == false
        let sourceAnimating = sourceView.layer.animationKeys()?.isEmpty == false
        if superAnimating || sourceAnimating,
           let fromPresentation = superlayer.presentation(),
           let toPresentation = sourceView.layer.presentation() {
            frameInSource = fromPresentation.convert(viewFrame, to: toPresentation)
        } else if let superviewLayer = superlayer.delegate as? UIView {
            frameInSource = superviewLayer.convert(viewFrame, to: sourceView)
        } else {
            var currentLayer: CALayer? = superlayer
            while let layer = currentLayer {
                if let view = layer.delegate as? UIView {
                    let layerFrameInView = layer.convert(viewFrame, to: view.layer)
                    frameInSource = view.convert(layerFrameInView, to: sourceView)
                    break
                }
                currentLayer = layer.superlayer
            }
        }

        // The drawable's padding scales with any transform on the glass view, so
        // the captured margin scales with it too.
        let scaleX = viewFrame.width > 0 ? frameInSource.width / viewFrame.width : 1
        let scaleY = viewFrame.height > 0 ? frameInSource.height / viewFrame.height : 1
        return frameInSource.insetBy(dx: -padding.x * scaleX, dy: -padding.y * scaleY)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: TheseusSettings.settingsDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleSettingsChange() {
        let settings = TheseusSettings.shared
        currentRefractionQuality = settings.effectiveRefractionQuality

        updateDisplayLinkFrameRate()

        setNeedsRender()
    }

    private func updateDisplayLinkFrameRate() {
        guard let link = displayLink else { return }

        let targetFPS = continuousUpdate ? 60 : currentRefractionQuality.frameRate
        link.preferredFramesPerSecond = targetFPS
    }

    @objc private func handleMemoryWarning() {
        texturePool.drain()
        viewLayerCapture?.invalidate()
        backgroundCaptureDraw?.invalidate()
        blurKernelCalculator.invalidateCache()
    }

    @objc private func handleAppWillResignActive() {
        stopRendering()
        texturePool.trimExcess()
    }

    @objc private func handleAppDidBecomeActive() {
        guard !isPausedExternally, metalLayer?.superlayer != nil else { return }
        if let host = hostView, host.window == nil { return }
        startRendering()
    }

    private func encodeSnapshot(of texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]
        guard let snapshot = context.device.makeTexture(descriptor: descriptor),
              let blit = commandBuffer.makeBlitCommandEncoder() else { return }
        blit.copy(from: texture, to: snapshot)
        blit.endEncoding()
        commandBuffer.addCompletedHandler { [weak self] _ in
            guard let image = Self.image(from: snapshot) else { return }
            DispatchQueue.main.async { self?.onSnapshot?(image) }
        }
    }

    /// The capture context's own space, so drawing the snapshot into a capture
    /// is a copy, not a per-pixel conversion.
    private static let snapshotColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    private static func image(from texture: MTLTexture) -> CGImage? {
        let width = texture.width, height = texture.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&data, bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            .union(.byteOrder32Little)
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
            space: snapshotColorSpace, bitmapInfo: bitmapInfo,
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    #if DEBUG
    private static func dumpTexture(_ texture: MTLTexture, name: String) {
        let width = texture.width, height = texture.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&data, bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            .union(.byteOrder32Little)
        guard let ctx = CGContext(data: &data, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                  space: colorSpace, bitmapInfo: bitmapInfo.rawValue),
              let cgImage = ctx.makeImage() else { return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(name).png")
        try? UIImage(cgImage: cgImage).pngData()?.write(to: url)
    }
    #endif
}
