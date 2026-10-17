import UIKit

/// How background content is captured for refraction effects.
public enum CaptureMethod {
    case surfaceBased
    case layerRendering
}

/// Light or dark appearance with an optional tint, as `Glass.tint(_:)` (iOS 26+).
/// `tintColor` may carry its own alpha; `tintOpacity` is a 0...1 multiplier on top.
public struct TheseusTheme {
    public var isDark: Bool
    public var tintColor: UIColor
    public var tintOpacity: CGFloat

    /// Tint weight over the whole glass interior (Metal backend); native composites the tint at full alpha.
    public var surfaceTintWeight: CGFloat

    /// Extra tint weight in the refractive edge zone, on top of `surfaceTintWeight` (Metal backend).
    public var edgeTintWeight: CGFloat

    /// How much rim and specular highlights keep the tint hue: 0 = white, 1 = fully hued (Metal backend).
    public var highlightTintPreservation: CGFloat

    /// Strength of the spectral dispersion fringes at the refractive edge (Metal backend, 0 = off).
    public var edgeIridescence: CGFloat

    /// Scales the adaptive body untinted glass takes from the clear-tinted spectrum.
    /// 1 = native regular glass and tab bar chrome, 0 = lenses.
    public var neutralBodyScale: CGFloat

    /// Additive, hue-preserving lift of the backdrop as a fraction of full white; negative values darken.
    public var luminanceLift: CGFloat

    /// Multiplier on the chroma scale the material applies about luminance (1 = native regular glass).
    public var backdropSaturation: CGFloat

    /// Multiplier on the backdrop after the body and before the lift; native clear glass runs 0.95.
    public var backdropGain: CGFloat

    /// Above 0, `bodyPoleMix` mixes the backdrop luminance toward `bodyPole` in place of the
    /// regular-glass transfer, with the chroma scale `backdropSaturation` alone.
    public var bodyPole: CGFloat
    public var bodyPoleMix: CGFloat

    var bodyCurve: [CGFloat]?
    var bodyCurveChromaSlope: CGFloat = 0
    var bodyCurveSaturation: CGFloat = 1

    public init(
        isDark: Bool = false,
        tintColor: UIColor = .clear,
        tintOpacity: CGFloat = 1.0,
        surfaceTintWeight: CGFloat = 1.0,
        edgeTintWeight: CGFloat = 0.0,
        highlightTintPreservation: CGFloat = 0.5,
        neutralBodyScale: CGFloat = 1.0,
        edgeIridescence: CGFloat = 0.0,
        backdropSaturation: CGFloat = 1.0,
        luminanceLift: CGFloat = 0.0,
        backdropGain: CGFloat = 1.0,
        bodyPole: CGFloat = 1.0,
        bodyPoleMix: CGFloat = 0.0
    ) {
        self.isDark = isDark
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
        self.surfaceTintWeight = surfaceTintWeight
        self.edgeTintWeight = edgeTintWeight
        self.highlightTintPreservation = highlightTintPreservation
        self.neutralBodyScale = neutralBodyScale
        self.edgeIridescence = edgeIridescence
        self.backdropSaturation = backdropSaturation
        self.luminanceLift = luminanceLift
        self.backdropGain = backdropGain
        self.bodyPole = bodyPole
        self.bodyPoleMix = bodyPoleMix
    }

    public static let light = TheseusTheme(isDark: false)
    public static let dark = TheseusTheme(isDark: true)
}

/// Controls how edge refraction is rendered.
public enum RefractionMode {
    case disabled
    case approximate
    case precise
}

/// Quality level for refraction rendering, affects GPU performance.
public enum RefractionFidelity: Int {
    case low = 0
    case medium = 1
    case high = 2
}

/// Bevel, contour, rim line and shade of a drag lens (a shape with a negative corner radius).
/// Reach, lip and side-reach values are points; onset, width, ramp and fade values are device pixels.
public struct TheseusLensProfile: Equatable {
    public var riseStart: CGFloat
    public var riseEnd: CGFloat
    public var fallStart: CGFloat
    public var fallLength: CGFloat
    public var frost: CGFloat
    public var contourDarkening: CGFloat
    public var contourDarkeningLight: CGFloat
    public var highlight: CGFloat
    public var highlightLight: CGFloat
    public var highlightSide: CGFloat
    public var highlightBottom: CGFloat
    public var highlightWidth: CGFloat
    public var highlightFade: CGFloat
    public var highlightFadeLight: CGFloat
    public var shade: CGFloat
    public var shadeDark: CGFloat
    public var shadeReach: CGFloat
    public var contourSide: CGFloat
    public var shadeSide: CGFloat
    public var shadeOnset: CGFloat
    public var shadeSideOnset: CGFloat
    public var highlightBottomDark: CGFloat
    public var shadeSideDark: CGFloat
    public var shadeOnsetDark: CGFloat
    public var shadeFloor: CGFloat
    public var shadeFloorDark: CGFloat
    public var lip: CGFloat
    public var lipReach: CGFloat
    public var highlightTail: CGFloat
    public var highlightTailDark: CGFloat
    public var contourRamp: CGFloat
    public var contourRampDark: CGFloat
    public var contourSideDark: CGFloat
    public var contourSideWidth: CGFloat
    public var contourSideWidthDark: CGFloat
    public var shadeSideReach: CGFloat
    public var shadeSideReachDark: CGFloat
    public var shadeShoulder: CGFloat
    public var shadeSideShoulder: CGFloat
    public var shadeLobeTilt: CGFloat
    public var highlightLobe: CGFloat
    public var highlightLobeLight: CGFloat
    public var shadeSideOnsetWidth: CGFloat
    public var shadeCapOnsetShare: CGFloat
    public var shadeTopExponent: CGFloat
    public var shadeTopLobeShift: CGFloat
    public var shadeSideExponent: CGFloat
    public var contourChroma: CGFloat
    public var contourChromaDark: CGFloat
    public var capExponent: CGFloat
    public var capExponentTip: CGFloat
    public var capOutlineOnly: Bool
    public var contourFlat: CGFloat
    public var contourFlatDark: CGFloat
    public var highlightInLinearLight: Bool

    public init(
        riseStart: CGFloat = 0.05,
        riseEnd: CGFloat = 0.19,
        fallStart: CGFloat = 0.37,
        fallLength: CGFloat = 0.08,
        frost: CGFloat = 0.5,
        contourDarkening: CGFloat = 0.23,
        contourDarkeningLight: CGFloat = 0.235,
        highlight: CGFloat = 0.12,
        highlightLight: CGFloat = 0.22,
        highlightSide: CGFloat = 0.12,
        highlightBottom: CGFloat = 0.75,
        highlightWidth: CGFloat = 2.0,
        highlightFade: CGFloat = 1.0,
        highlightFadeLight: CGFloat = 1.0,
        shade: CGFloat = 0.10,
        shadeDark: CGFloat = 0.12,
        shadeReach: CGFloat = 18.7,
        contourSide: CGFloat = 1.0,
        shadeSide: CGFloat = 0.7071,
        shadeOnset: CGFloat = 30.0,
        shadeSideOnset: CGFloat = 18.0,
        highlightBottomDark: CGFloat = 0.75,
        shadeSideDark: CGFloat = 0.7071,
        shadeOnsetDark: CGFloat = 30.0,
        shadeFloor: CGFloat = 0.0,
        shadeFloorDark: CGFloat = 0.0,
        lip: CGFloat = 0.0,
        lipReach: CGFloat = 2.833,
        highlightTail: CGFloat = 0.012,
        highlightTailDark: CGFloat = 0.0,
        contourRamp: CGFloat = 0.0,
        contourRampDark: CGFloat = 0.0,
        contourSideDark: CGFloat = 1.0,
        contourSideWidth: CGFloat = 0.0,
        contourSideWidthDark: CGFloat = 0.0,
        shadeSideReach: CGFloat = 0.0,
        shadeSideReachDark: CGFloat = 0.0,
        shadeShoulder: CGFloat = 0.0,
        shadeSideShoulder: CGFloat = -1.0,
        shadeLobeTilt: CGFloat = 0.0,
        highlightLobe: CGFloat = 0.0,
        highlightLobeLight: CGFloat = 0.0,
        shadeSideOnsetWidth: CGFloat = 0.0,
        shadeCapOnsetShare: CGFloat = 0.27,
        shadeTopExponent: CGFloat = 0.7,
        shadeTopLobeShift: CGFloat = 0.0,
        shadeSideExponent: CGFloat = 6.0,
        contourChroma: CGFloat = 0.0,
        contourChromaDark: CGFloat = 0.0,
        capExponent: CGFloat = 0.0,
        capExponentTip: CGFloat = 0.0,
        capOutlineOnly: Bool = false,
        contourFlat: CGFloat = 0.5,
        contourFlatDark: CGFloat = 0.5,
        highlightInLinearLight: Bool = true
    ) {
        self.riseStart = riseStart
        self.riseEnd = riseEnd
        self.fallStart = fallStart
        self.fallLength = fallLength
        self.frost = frost
        self.contourDarkening = contourDarkening
        self.contourDarkeningLight = contourDarkeningLight
        self.highlight = highlight
        self.highlightLight = highlightLight
        self.highlightSide = highlightSide
        self.highlightBottom = highlightBottom
        self.highlightWidth = highlightWidth
        self.highlightFade = highlightFade
        self.highlightFadeLight = highlightFadeLight
        self.shade = shade
        self.shadeDark = shadeDark
        self.shadeReach = shadeReach
        self.contourSide = contourSide
        self.shadeSide = shadeSide
        self.shadeOnset = shadeOnset
        self.shadeSideOnset = shadeSideOnset
        self.highlightBottomDark = highlightBottomDark
        self.shadeSideDark = shadeSideDark
        self.shadeOnsetDark = shadeOnsetDark
        self.shadeFloor = shadeFloor
        self.shadeFloorDark = shadeFloorDark
        self.lip = lip
        self.lipReach = lipReach
        self.highlightTail = highlightTail
        self.highlightTailDark = highlightTailDark
        self.contourRamp = contourRamp
        self.contourRampDark = contourRampDark
        self.contourSideDark = contourSideDark
        self.contourSideWidth = contourSideWidth
        self.contourSideWidthDark = contourSideWidthDark
        self.shadeSideReach = shadeSideReach
        self.shadeSideReachDark = shadeSideReachDark
        self.shadeShoulder = shadeShoulder
        self.shadeSideShoulder = shadeSideShoulder
        self.shadeLobeTilt = shadeLobeTilt
        self.highlightLobe = highlightLobe
        self.highlightLobeLight = highlightLobeLight
        self.shadeSideOnsetWidth = shadeSideOnsetWidth
        self.shadeCapOnsetShare = shadeCapOnsetShare
        self.shadeTopExponent = shadeTopExponent
        self.shadeTopLobeShift = shadeTopLobeShift
        self.shadeSideExponent = shadeSideExponent
        self.contourChroma = contourChroma
        self.contourChromaDark = contourChromaDark
        self.capExponent = capExponent
        self.capExponentTip = capExponentTip
        self.capOutlineOnly = capOutlineOnly
        self.contourFlat = contourFlat
        self.contourFlatDark = contourFlatDark
        self.highlightInLinearLight = highlightInLinearLight
    }
}

public struct TheseusRefraction {
    @available(*, deprecated, message: "No effect; refraction strength comes from intensity and edgeWidth. Kept for source compatibility.")
    public var mode: RefractionMode {
        get { legacyMode }
        set { legacyMode = newValue }
    }
    public var edgeWidth: CGFloat
    public var intensity: CGFloat
    public var dispersion: CGFloat
    @available(*, deprecated, message: "No effect; render quality follows TheseusSettings.effectiveRefractionQuality. Kept for source compatibility.")
    public var fidelity: RefractionFidelity {
        get { legacyFidelity }
        set { legacyFidelity = newValue }
    }
    public var reflective: Bool

    private var legacyMode: RefractionMode
    private var legacyFidelity: RefractionFidelity

    /// Interior loupe magnification, uniform across the interior (1 = none).
    public var magnification: CGFloat

    /// Simulated slab thickness in points; sets the bevel displacement magnitude.
    public var thickness: CGFloat

    /// Interior sample sharpness: 0 = the blurred backdrop, 1 = the sharp source.
    public var interiorSharpness: CGFloat

    /// Width in points of the backdrop the interior averages in place of the blur (0 = off).
    public var interiorAverage: CGFloat

    /// Red-to-blue offset in points along the rim at the edge, red leading clockwise; native drag lens 4.7 pt.
    public var rimDispersion: CGFloat

    /// Depth in points over which `rimDispersion` fades to nothing (native: 11.3 pt).
    public var rimDispersionDepth: CGFloat

    /// Vertical offset in points of the magnification centre, positive downward.
    /// A lens riding above its content sets this so the loupe magnifies about the content's centre.
    public var magnificationCenterY: CGFloat

    /// Bevel and rim shape used when the shape renders as a drag lens.
    public var lensProfile: TheseusLensProfile

    public init(
        mode: RefractionMode = .precise,
        edgeWidth: CGFloat = 15.0,
        intensity: CGFloat = 1.45,
        dispersion: CGFloat = 4.0,
        fidelity: RefractionFidelity = .high,
        reflective: Bool = false,
        magnification: CGFloat = 1.0,
        thickness: CGFloat = 45.0,
        interiorSharpness: CGFloat = 0.0,
        interiorAverage: CGFloat = 0.0,
        rimDispersion: CGFloat = 0.0,
        rimDispersionDepth: CGFloat = 0.0,
        magnificationCenterY: CGFloat = 0.0,
        lensProfile: TheseusLensProfile = TheseusLensProfile()
    ) {
        self.legacyMode = mode
        self.edgeWidth = edgeWidth
        self.intensity = intensity
        self.dispersion = dispersion
        self.legacyFidelity = fidelity
        self.reflective = reflective
        self.magnification = magnification
        self.thickness = thickness
        self.interiorSharpness = interiorSharpness
        self.interiorAverage = interiorAverage
        self.rimDispersion = rimDispersion
        self.rimDispersionDepth = rimDispersionDepth
        self.lensProfile = lensProfile
        self.magnificationCenterY = magnificationCenterY
    }

    public static let disabled = TheseusRefraction(mode: .disabled, intensity: 0)
    public static let subtle = TheseusRefraction(edgeWidth: 10, intensity: 1.2, dispersion: 2.0)
    public static let standard = TheseusRefraction()
    public static let pronounced = TheseusRefraction(edgeWidth: 20, intensity: 1.8, dispersion: 6.0)
}

/// Gaussian blur settings for the frosted glass background.
public struct TheseusBlur {
    public var radius: CGFloat
    public var sigma: CGFloat?
    @available(*, deprecated, message: "No effect on either backend; kept for source compatibility.")
    public var vibrancy: CGFloat {
        get { legacyVibrancy }
        set { legacyVibrancy = newValue }
    }
    @available(*, deprecated, message: "No effect on either backend; kept for source compatibility.")
    public var luminance: CGFloat {
        get { legacyLuminance }
        set { legacyLuminance = newValue }
    }

    private var legacyVibrancy: CGFloat
    private var legacyLuminance: CGFloat

    private static let sigmaToRadiusRatio: CGFloat = 0.3

    public init(
        radius: CGFloat = 1.0,
        sigma: CGFloat? = nil,
        vibrancy: CGFloat = 1.0,
        luminance: CGFloat = 1.0
    ) {
        self.radius = radius
        self.sigma = sigma
        self.legacyVibrancy = vibrancy
        self.legacyLuminance = luminance
    }

    public var effectiveSigma: CGFloat {
        sigma ?? (radius * Self.sigmaToRadiusRatio)
    }

    public static let none = TheseusBlur(radius: 0)
    public static let light = TheseusBlur(radius: 0.5)
    public static let standard = TheseusBlur()
    public static let heavy = TheseusBlur(radius: 2.0)
}

/// Rim lighting and specular glare settings for depth and dimensionality.
public struct TheseusEdgeEffects {
    @available(*, deprecated, message: "No effect since the height-field rebuild; kept for source compatibility.")
    public var rimRange: CGFloat {
        get { legacyRimRange }
        set { legacyRimRange = newValue }
    }
    public var rimGlow: CGFloat
    @available(*, deprecated, message: "No effect since the height-field rebuild; kept for source compatibility.")
    public var rimHardness: CGFloat {
        get { legacyRimHardness }
        set { legacyRimHardness = newValue }
    }

    @available(*, deprecated, message: "No effect since the height-field rebuild; kept for source compatibility.")
    public var glareRange: CGFloat {
        get { legacyGlareRange }
        set { legacyGlareRange = newValue }
    }
    public var glareIntensity: CGFloat
    public var glareFocus: CGFloat
    @available(*, deprecated, message: "No effect since the height-field rebuild; kept for source compatibility.")
    public var glareConvergence: CGFloat {
        get { legacyGlareConvergence }
        set { legacyGlareConvergence = newValue }
    }
    @available(*, deprecated, message: "No effect since the height-field rebuild; kept for source compatibility.")
    public var lightAngle: CGFloat {
        get { legacyLightAngle }
        set { legacyLightAngle = newValue }
    }
    public var oppositeFalloff: CGFloat
    public var farColor: UIColor
    public var nearColor: UIColor

    private var legacyRimRange: CGFloat
    private var legacyRimHardness: CGFloat
    private var legacyGlareRange: CGFloat
    private var legacyGlareConvergence: CGFloat
    private var legacyLightAngle: CGFloat

    public init(
        rimRange: CGFloat = 45.0,
        rimGlow: CGFloat = 0.5,
        rimHardness: CGFloat = 12.0,
        glareRange: CGFloat = 450.0,
        glareIntensity: CGFloat = 1.0,
        glareFocus: CGFloat = 0.55,
        glareConvergence: CGFloat = 0.75,
        lightAngle: CGFloat = .pi * 0.3,
        oppositeFalloff: CGFloat = 0.6,
        farColor: UIColor = UIColor(white: 0.0, alpha: 0.7),
        nearColor: UIColor = UIColor(white: 1.0, alpha: 0.7)
    ) {
        self.legacyRimRange = rimRange
        self.rimGlow = rimGlow
        self.legacyRimHardness = rimHardness
        self.legacyGlareRange = glareRange
        self.glareIntensity = glareIntensity
        self.glareFocus = glareFocus
        self.legacyGlareConvergence = glareConvergence
        self.legacyLightAngle = lightAngle
        self.oppositeFalloff = oppositeFalloff
        self.farColor = farColor
        self.nearColor = nearColor
    }

    public static let subtle = TheseusEdgeEffects(rimGlow: 0.3, glareIntensity: 0.5)
    public static let standard = TheseusEdgeEffects()
    public static let dramatic = TheseusEdgeEffects(rimGlow: 0.8, glareIntensity: 1.5)
}

/// A rounded rectangle smooth-unioned with the view's primary glass shape, in view coordinates.
public struct TheseusMergedShape {
    public var frame: CGRect
    public var cornerRadius: CGFloat

    public init(frame: CGRect, cornerRadius: CGFloat) {
        self.frame = frame
        self.cornerRadius = cornerRadius
    }
}

/// Corner radius and padding for the Liquid Glass shape.
public struct TheseusShape {
    public var cornerRadius: CGFloat
    public var padding: CGPoint

    /// Extra rounded rectangles smooth-unioned with the primary shape (up to 8; Metal backend only).
    public var mergedShapes: [TheseusMergedShape]

    /// Blend distance for shape merging, in points.
    public var mergeSmoothing: CGFloat

    /// Points the primary shape gives up on each side inside the view; negative values grow it.
    /// Lets a drag lens change size without resizing the drawable every frame.
    var widthInset: CGFloat = 0
    var heightInset: CGFloat = 0

    /// A capsule (corner radius >= half the short side) draws native's continuous ends; smaller radii are unaffected.
    public var continuousCapsule = true

    public init(
        cornerRadius: CGFloat = 18.0,
        padding: CGPoint = .zero,
        mergedShapes: [TheseusMergedShape] = [],
        mergeSmoothing: CGFloat = 12.0
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.mergedShapes = mergedShapes
        self.mergeSmoothing = mergeSmoothing
    }

    public static let pill = TheseusShape(cornerRadius: 9999)
    public static let rounded = TheseusShape(cornerRadius: 12)
    public static let card = TheseusShape(cornerRadius: 20)
}

/// Spring physics parameters for stretch/squish morphing animations during gestures.
public struct TheseusMorphConfiguration {
    public var scale: CGPoint
    public var sizeFactor: CGFloat
    public var tension: CGFloat
    public var friction: CGFloat
    public var squish: CGFloat
    @available(*, deprecated, message: "Unimplemented; the spring integrates toward the raw target. Tune tension and friction instead.")
    public var smoothing: CGFloat {
        get { legacySmoothing }
        set { legacySmoothing = newValue }
    }

    private var legacySmoothing: CGFloat

    public init(
        scale: CGPoint = CGPoint(x: 1.0, y: 1.0),
        sizeFactor: CGFloat = 0.35,
        tension: CGFloat = 0.18,
        friction: CGFloat = 0.88,
        squish: CGFloat = 0.55,
        smoothing: CGFloat = 0.45
    ) {
        self.scale = scale
        self.sizeFactor = sizeFactor
        self.tension = tension
        self.friction = friction
        self.squish = squish
        self.legacySmoothing = smoothing
    }

    public static let `default` = TheseusMorphConfiguration()
    public static let subtle = TheseusMorphConfiguration(sizeFactor: 0.2, tension: 0.1)
    public static let bouncy = TheseusMorphConfiguration(tension: 0.25, friction: 0.8)
}

/// Complete configuration for a Liquid Glass view, combining all visual and animation settings.
public struct TheseusConfiguration {

    public var theme: TheseusTheme

    public var refraction: TheseusRefraction

    public var blur: TheseusBlur

    public var edgeEffects: TheseusEdgeEffects

    public var shape: TheseusShape

    public var morph: TheseusMorphConfiguration

    public var quality: QualityLevel?

    public var opacity: CGFloat

    @available(*, deprecated, message: "No effect; the capture region always equals the drawable extent (view bounds + shape.padding). Kept for source compatibility.")
    public var capturePadding: CGPoint? {
        get { legacyCapturePadding }
        set { legacyCapturePadding = newValue }
    }

    private var legacyCapturePadding: CGPoint?

    public var captureMethod: CaptureMethod

    /// How far the lens body is filled toward `lensFillColor`, 0 (glass) to 1 (solid).
    public var lensFill: CGFloat = 0

    public var lensFillColor: UIColor = .white

    /// Scale on the lens rim's displacement, frost, shade, contour and line, 0 (clear pane) to 1.
    /// Below 0 it follows `1 - lensFill` and the fill mixes in under the shade and contour.
    public var lensRimScale: CGFloat = -1

    /// Drop shadow of a lens outside its rim: a Gaussian ring of `lensShadowRadius` points, moved
    /// down by `lensShadowOffset` points, at `lensShadowOpacity` black. 0 keeps the 2 % downward glow.
    public var lensShadowOpacity: CGFloat = 0
    public var lensShadowOffset: CGFloat = 0
    public var lensShadowRadius: CGFloat = 0

    /// `outerGlow`: dark glow under a non-lens shape's lower edge (below 0 = the default 22 %).
    /// `edgeFeather`: width in points over which the outline is anti-aliased (0 = a hard edge).
    var outerGlow: CGFloat = -1
    var edgeFeather: CGFloat = 0

    /// Share of a lens's refraction and rim dispersion, 0...1.
    var lensRefractionScale: CGFloat = 1

    /// The iOS 27.0 drag lens's warp chain: outward backdrop warp, inward inner refraction, item warps
    /// and rim aberration, each over F(x) = 1 - sqrt(x(2 - x)) of depth / height. All lengths in points.
    struct LensChain: Equatable {
        var backdropWarp: CGFloat = 9
        var backdropWarpHeight: CGFloat = 36
        var itemWarp: CGFloat = 17.5
        var itemLensing: CGFloat = 14
        var itemWarpHeight: CGFloat = 11.2
        var itemLensingHeight: CGFloat = 0
        var ovalization: CGFloat = 0.5
        var aberration: CGFloat = 2.2
        var aberrationBand: CGFloat = 9
        var aberrationFade: CGFloat = 3
        var inset: CGFloat = 0
        var innerRefraction: CGFloat = 10.5
        var innerRefractionHeight: CGFloat = 7
        var frost: CGFloat = 0
        var itemRimFade: CGFloat = 3.6
        var warpIgnoresShare = false
        /// Above 0, the inner refraction is this share of the short side (capped at `innerRefractionCap` pt)
        /// and its height `innerHeightPerSide` of it (capped at `innerHeightCap` pt).
        var innerRefractionPerSide: CGFloat = 0
        var innerRefractionCap: CGFloat = 0
        var innerHeightPerSide: CGFloat = 0
        var innerHeightCap: CGFloat = 0
        /// Takes the detail from the blurred capture's finest level.
        var detailBlurred = false

        /// `UIGlassEffect` glass on iOS 27.0; `GlassRim` carries the frost.
        static let glass = LensChain(
            backdropWarp: 0,
            itemWarp: 0,
            itemLensing: 0,
            aberration: 0,
            inset: 0.8,
            itemRimFade: 0,
            warpIgnoresShare: true,
            innerRefractionPerSide: 0.5,
            innerRefractionCap: 60,
            innerHeightPerSide: 0.25,
            innerHeightCap: 20,
            detailBlurred: true
        )

        /// `UIGlassEffect(style: .clear)` on iOS 27.0.
        static let clearGlass: LensChain = {
            var chain = LensChain.glass
            chain.innerRefractionPerSide = 0.65
            chain.innerHeightPerSide = 0.36
            return chain
        }()

        /// The pressed `UISwitch` knob on iOS 27.0; its rim draws 2/3 pt outside the knob frame.
        static let knob = LensChain(
            itemWarp: 0,
            itemLensing: 0,
            aberration: 0,
            inset: 2.0 / 3.0,
            innerRefraction: 11.5,
            innerRefractionHeight: 6.9,
            itemRimFade: 0,
            warpIgnoresShare: true
        )

        static let tabLens26 = LensChain(
            itemLensing: 17.5,
            itemLensingHeight: 14,
            aberration: 0,
            innerRefraction: 70.0 / 4,
            innerRefractionHeight: 0.1 * 70.0,
            itemRimFade: 0
        )

        static let knob26 = LensChain(
            itemWarp: 0,
            itemLensing: 0,
            aberration: 0,
            inset: 0,
            innerRefraction: 38.333 / 2,
            innerRefractionHeight: 0.18 * 38.333,
            itemRimFade: 0,
            warpIgnoresShare: true
        )

        static let sliderKnob26 = LensChain(
            backdropWarp: 0,
            itemWarp: 0,
            itemLensing: 0,
            aberration: 0,
            inset: 0,
            innerRefraction: 37.0 / 2,
            innerRefractionHeight: 0.18 * 37.0,
            itemRimFade: 0,
            warpIgnoresShare: true
        )

        /// The pressed `UISlider` knob on iOS 27.0.
        static let sliderKnob = LensChain(
            backdropWarp: 0,
            itemWarp: 0,
            itemLensing: 0,
            aberration: 0,
            inset: 2.0 / 3.0,
            innerRefraction: 11.1,
            innerRefractionHeight: 6.66,
            itemRimFade: 0,
            warpIgnoresShare: true
        )
    }

    var lensChain: LensChain?

    var nativeLens: NativeLens26?

    var flexGlow: FlexGlow?

    var shapeOffset: CGPoint = .zero

    /// `UIGlassEffect`'s rim band, ring and drop shadows, highlight and depth-varying frost on iOS 27.0.
    /// Band spreads in radians; sigmas in points; both blurs average encoded values.
    struct GlassRim: Equatable {
        var bandSpreadLight: CGFloat
        var bandSpreadDark: CGFloat
        var bandOvalization: CGFloat
        var bandBias: CGFloat = -0.3
        var ringShadowOpacity: CGFloat
        var highlightBrightness: CGFloat
        var highlightSaturation: CGFloat
        var highlightOffset: CGFloat
        var fillSigma: CGFloat
        var blurRadiusDeep: CGFloat
        var blurRadiusNearRim: CGFloat
        var blurRadiusAtRim: CGFloat
        var outerRefractionShare: CGFloat
        var material: Material
        var generation: Generation = .iOS27
        var highlightDarkBrightness: CGFloat?
        var highlightDarkSaturation: CGFloat?
        var highlightDarkOffset: CGFloat?

        enum Material: Equatable {
            case regular
            case clear
        }

        enum Generation: Equatable {
            case iOS27
            case iOS26
        }

        func styled(_ style: TheseusSettings.GlassStyle) -> GlassRim {
            guard style == .iOS26 else { return self }
            var rim = self
            rim.generation = .iOS26
            rim.ringShadowOpacity = 0
            rim.highlightBrightness = 0.1
            rim.highlightSaturation = 15
            rim.highlightOffset = 0.9
            rim.highlightDarkBrightness = 1.35
            rim.highlightDarkSaturation = 2.2222
            rim.highlightDarkOffset = 0.15
            rim.blurRadiusDeep = 1
            rim.blurRadiusNearRim = 0.5
            rim.blurRadiusAtRim = 0.5
            rim.outerRefractionShare = material == .regular ? 0.3 : 0
            return rim
        }

        func highlight(isDark: Bool) -> SIMD3<Float> {
            guard isDark else { return SIMD3(Float(highlightBrightness), Float(highlightSaturation), Float(highlightOffset)) }
            return SIMD3(Float(highlightDarkBrightness ?? highlightBrightness), Float(highlightDarkSaturation ?? highlightSaturation), Float(highlightDarkOffset ?? highlightOffset))
        }

        func innerRefraction(shortSide: CGFloat) -> (amount: CGFloat, height: CGFloat)? {
            guard generation == .iOS26 else { return nil }
            switch material {
            case .regular: return (min(0.8 * shortSide, 60), min(0.25 * shortSide, 20))
            case .clear: return (min(shortSide, 60), min(0.36 * shortSide, 20))
            }
        }

        func outerRefraction(shortSide: CGFloat) -> (amount: CGFloat, height: CGFloat) {
            guard generation == .iOS26 else { return Self.outerRefraction(shortSide: shortSide) }
            return (0.2 * shortSide, 0.125 * shortSide)
        }

        var outerRefractionFullDepth: CGFloat {
            generation == .iOS26 ? 2.0 / 3.0 : 0
        }

        func shadowSigma(shortSide: CGFloat) -> CGFloat {
            generation == .iOS26 ? 0.699 * 24 : Self.dropShadowSigma(shortSide: shortSide)
        }

        func dropShadowAmount(isDark: Bool, shortSide: CGFloat) -> CGFloat {
            guard material == .regular else { return 0 }
            guard generation == .iOS26 else {
                let t = min(max((shortSide - 64) / 96, 0), 1)
                return 0.3 * (0.04 + ((isDark ? 0.6 : 0.4) - 0.04) * t)
            }
            guard shortSide > 64 else { return 0.07 }
            let heights = Self.iOS26ShadowHeights
            let amounts = isDark ? Self.iOS26ShadowDark : Self.iOS26ShadowLight
            guard let upper = heights.firstIndex(where: { $0 >= shortSide }) else { return amounts[amounts.count - 1] }
            guard upper > 0 else { return amounts[0] }
            let t = (shortSide - heights[upper - 1]) / (heights[upper] - heights[upper - 1])
            return amounts[upper - 1] + (amounts[upper] - amounts[upper - 1]) * t
        }

        func dropShadowReach(shortSide: CGFloat) -> CGPoint? {
            guard material == .regular else { return nil }
            let sigma = shadowSigma(shortSide: shortSide)
            return CGPoint(x: 2 * sigma, y: Self.dropShadowOffset + 2 * sigma)
        }

        static let iOS26ShadowHeights: [CGFloat] = [65, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]
        static let iOS26ShadowLight: [CGFloat] = [0.104, 0.105, 0.106, 0.106, 0.106, 0.105, 0.103, 0.101, 0.098, 0.095, 0.090]
        static let iOS26ShadowDark: [CGFloat] = [0.042, 0.053, 0.071, 0.088, 0.104, 0.117, 0.128, 0.137, 0.145, 0.151, 0.155]

        static let regular = GlassRim(
            bandSpreadLight: 1.85005,
            bandSpreadDark: 1.30900,
            bandOvalization: 0.5,
            ringShadowOpacity: 0.06,
            highlightBrightness: 0.9117,
            highlightSaturation: 1.2905,
            highlightOffset: 0.1471,
            fillSigma: 14.6,
            blurRadiusDeep: 0.05,
            blurRadiusNearRim: 0.025,
            blurRadiusAtRim: 0.5,
            outerRefractionShare: 0.6,
            material: .regular
        )

        static let clear = GlassRim(
            bandSpreadLight: 1.30900,
            bandSpreadDark: 1.30900,
            bandOvalization: 0,
            ringShadowOpacity: 0,
            highlightBrightness: 1.2666,
            highlightSaturation: 1.0528,
            highlightOffset: 0.2,
            fillSigma: 14.6,
            blurRadiusDeep: 1,
            blurRadiusNearRim: 0.5,
            blurRadiusAtRim: 0.5,
            outerRefractionShare: 0,
            material: .clear
        )

        /// Outward refraction mixed into regular glass's outer 1 pt, `outerRefractionShare` at the frame; points.
        static func outerRefraction(shortSide: CGFloat) -> (amount: CGFloat, height: CGFloat) {
            (max(16, shortSide / 4), max(16, shortSide / 5))
        }

        /// Sigma in points of the capture's own softness before the blur.
        static let blurSoftness: CGFloat = 0.33

        /// Full blur sigma in points that the radius shares scale.
        func blurSigma(tintAmount: CGFloat) -> CGFloat {
            switch (material, generation) {
            case (.regular, .iOS26): return 3.566
            case (.clear, .iOS26): return 1.75
            case (.regular, .iOS27): return 9.6
            case (.clear, .iOS27): return 1.31 * min(max(tintAmount, 0) * 2, 1)
            }
        }

        /// The blur at a radius share, with the capture's softness.
        func sigma(radiusShare: CGFloat, tintAmount: CGFloat) -> CGFloat {
            let blur = blurSigma(tintAmount: tintAmount) * radiusShare
            return (blur * blur + Self.blurSoftness * Self.blurSoftness).squareRoot()
        }

        /// The finest and the coarsest blur the frost blends between.
        func detailSigma(tintAmount: CGFloat) -> CGFloat {
            sigma(radiusShare: min(blurRadiusDeep, blurRadiusNearRim, blurRadiusAtRim), tintAmount: tintAmount)
        }

        func coarseSigma(tintAmount: CGFloat) -> CGFloat {
            sigma(radiusShare: max(blurRadiusDeep, blurRadiusNearRim, blurRadiusAtRim), tintAmount: tintAmount)
        }

        /// `glassBackground`'s face colour matrix: luminance capped by `maxLuma`, remapped to `black`...`white`,
        /// chroma scaled by `saturation`, then mixed toward `fill` by its alpha. Encoded values.
        struct Face: Equatable {
            var black: CGFloat
            var white: CGFloat
            var saturation: CGFloat
            var maxLuma: CGFloat
            var fill: SIMD4<Float>

            func apply(_ color: [CGFloat]) -> [CGFloat] {
                let input = color.map { min(max($0, 0), 1) }
                let luma = 0.2126 * input[0] + 0.7152 * input[1] + 0.0722 * input[2]
                let t = min(max(1 - (1 - maxLuma) * luma, 0), 1)
                let capped = t * luma
                let share = t * (1 + 0.3 * (1 - t))
                let offset = black + (white - black) * capped - capped
                let mappedColor = input.map { capped + share * ($0 - luma) + offset }
                let mapped = 0.2126 * mappedColor[0] + 0.7152 * mappedColor[1] + 0.0722 * mappedColor[2]
                let fillColor = [CGFloat(fill.x), CGFloat(fill.y), CGFloat(fill.z)]
                return (0..<3).map { index in
                    let saturated = mapped + saturation * (mappedColor[index] - mapped)
                    return min(max(saturated + (fillColor[index] - saturated) * CGFloat(fill.w), 0), 1)
                }
            }
        }

        /// The face at a system tint amount (`UIViewGlassTintAmount`, 0.5 by default).
        func face(isDark: Bool, tintAmount: CGFloat) -> Face {
            let a = min(max(tintAmount, 0), 1)
            switch material {
            case .clear:
                return Face(black: 0.125, white: 1.08, saturation: 1.06, maxLuma: 1, fill: .zero)
            case .regular where isDark:
                let grey = Float(0.25 * abs(a - 0.5))
                return Face(black: 0.125, white: 1.125, saturation: 1.3, maxLuma: 0.5625 + 0.03 * max(0, 0.5 - a), fill: SIMD4<Float>(grey, grey, grey, Float(max(0, a - 0.5))))
            case .regular:
                let alpha = a <= 0.5 ? 0.4 * a : 0.2 + 0.6 * (a - 0.5)
                return Face(black: 0.4, white: 1.03, saturation: 1.2, maxLuma: 0.94, fill: SIMD4<Float>(1, 1, 1, Float(alpha)))
            }
        }

        func face(isDark: Bool, tintAmount: CGFloat, style: TheseusSettings.GlassStyle) -> Face {
            guard style == .iOS26 else { return face(isDark: isDark, tintAmount: tintAmount) }
            let a = min(max(tintAmount, 0), 1)
            func blend(_ clear: CGFloat, _ tinted: CGFloat) -> CGFloat { clear + (tinted - clear) * a }
            switch material {
            case .clear:
                return Face(black: 0.0727, white: 1.1165, saturation: 1.0274, maxLuma: 1, fill: .zero)
            case .regular where isDark:
                return Face(black: blend(0.195, 0.189), white: blend(0.583, 0.734), saturation: blend(0.98, 1.95), maxLuma: 1, fill: SIMD4<Float>(0, 0, 0, Float(blend(0.4, 0.6))))
            case .regular:
                return Face(black: blend(0.466, 0.124), white: blend(0.983, 0.88), saturation: blend(1, 2), maxLuma: 1, fill: SIMD4<Float>(1, 1, 1, Float(blend(0.4, 0.8))))
            }
        }

        static func frostAmount(spectrum: CGFloat, style: TheseusSettings.GlassStyle) -> CGFloat {
            style == .iOS26 ? 0.5 : min(max(spectrum, 0), 1)
        }

        /// The fill blur's lighten (light) or darken (dark) share and cover at a tint amount.
        func frost(tintAmount: CGFloat) -> (blend: CGFloat, cover: CGFloat) {
            guard generation == .iOS27 else { return (0, 0) }
            let a = min(max(tintAmount, 0), 1)
            switch material {
            case .regular: return (min(0.9, 0.675 + 0.45 * a), a)
            case .clear: return (0, min(max((a - 0.5) * 2, 0), 1))
            }
        }

        struct TintMatrix: Equatable {
            var red: SIMD4<Float>
            var green: SIMD4<Float>
            var blue: SIMD4<Float>

            static let clamp: CGFloat = 1.2

            func apply(_ color: [CGFloat]) -> [CGFloat] {
                let input = SIMD4<Float>(Float(color[0]), Float(color[1]), Float(color[2]), 1)
                return [red, green, blue].map { min(max(CGFloat(($0 * input).sum()), 0), Self.clamp) }
            }
        }

        static func tintMatrix(red: CGFloat, green: CGFloat, blue: CGFloat, isDark: Bool) -> TintMatrix {
            let tint = [red, green, blue]
            let (hue, saturation, lightness) = hsl(tint)
            guard saturation > 0 else {
                let burn = lightness + 0.8 * (1 - lightness)
                let dodge = 1 - min(0.2 * lightness, 0.99609375)
                let slope = Float(0.25 / burn / dodge)
                let offset = Float((1 - (1 - 0.75 * lightness) / burn) / dodge)
                return TintMatrix(red: SIMD4(slope, 0, 0, offset), green: SIMD4(0, slope, 0, offset), blue: SIMD4(0, 0, slope, offset))
            }
            let low = isDark ? tint : rgb(hue: hue, saturation: 1.2 * saturation, lightness: 0.6 * lightness)
            let high = isDark ? rgb(hue: hue, saturation: 0.95 * saturation, lightness: 1.1 * lightness) : tint
            let black: CGFloat = 0.15
            let white: CGFloat = isDark ? 0.75 : 1
            let rows = (0..<3).map { index -> SIMD4<Float> in
                let slope = (high[index] - low[index]) / (white - black)
                let offset = low[index] - slope * black
                return SIMD4(Float(0.2126 * slope), Float(0.7152 * slope), Float(0.0722 * slope), Float(offset))
            }
            return TintMatrix(red: rows[0], green: rows[1], blue: rows[2])
        }

        private static func hsl(_ color: [CGFloat]) -> (hue: CGFloat, saturation: CGFloat, lightness: CGFloat) {
            let high = max(color[0], color[1], color[2])
            let low = min(color[0], color[1], color[2])
            let lightness = (high + low) / 2
            let delta = high - low
            guard delta >= 0.000345267 else { return (0, 0, lightness) }
            let saturation = delta / (lightness > 0.5 ? 2 - high - low : high + low)
            let sector: CGFloat
            if high == color[0] {
                sector = (color[1] - color[2]) / delta + (color[1] < color[2] ? 6 : 0)
            } else if high == color[1] {
                sector = (color[2] - color[0]) / delta + 2
            } else {
                sector = (color[0] - color[1]) / delta + 4
            }
            return (sector / 6, saturation, lightness)
        }

        private static func rgb(hue: CGFloat, saturation: CGFloat, lightness: CGFloat) -> [CGFloat] {
            let q = lightness >= 0.5 ? lightness + saturation - lightness * saturation : lightness * (1 + saturation)
            let p = 2 * lightness - q
            func channel(_ turn: CGFloat) -> CGFloat {
                let t = turn < 0 ? turn + 1 : (turn > 1 ? turn - 1 : turn)
                let value: CGFloat
                if t < 1.0 / 6 {
                    value = p + (q - p) * 6 * t
                } else if t < 0.5 {
                    value = q
                } else if t < 2.0 / 3 {
                    value = p + (q - p) * (2.0 / 3 - t) * 6
                } else {
                    value = p
                }
                return min(max(value, 0), 1)
            }
            return [channel(hue + 1.0 / 3), channel(hue), channel(hue - 1.0 / 3)]
        }

        /// Points the drop shadow falls below the frame.
        static let dropShadowOffset: CGFloat = 8.03

        /// Drop shadow sigma in points, 0.699 x native's blur radius.
        static func dropShadowSigma(shortSide: CGFloat) -> CGFloat {
            0.699 * min(max(4 + (shortSide - 64) * 5 / 24, 4), 24)
        }
    }

    var glassRim: GlassRim?

    public init(
        theme: TheseusTheme = .light,
        refraction: TheseusRefraction = .standard,
        blur: TheseusBlur = .standard,
        edgeEffects: TheseusEdgeEffects = .standard,
        shape: TheseusShape = TheseusShape(),
        morph: TheseusMorphConfiguration = .default,
        quality: QualityLevel? = nil,
        opacity: CGFloat = 1.0,
        capturePadding: CGPoint? = nil,
        captureMethod: CaptureMethod = .surfaceBased
    ) {
        self.theme = theme
        self.refraction = refraction
        self.blur = blur
        self.edgeEffects = edgeEffects
        self.shape = shape
        self.morph = morph
        self.quality = quality
        self.opacity = opacity
        self.legacyCapturePadding = capturePadding
        self.captureMethod = captureMethod
    }

    public var effectiveSigma: CGFloat {
        blur.effectiveSigma
    }

    /// The standard adaptive glass material. Mirrors `Glass.regular` (iOS 26+).
    public static var regular: TheseusConfiguration {
        var configuration = TheseusConfiguration()
        configuration.drawsAsNativeGlass(chain: .glass, rim: .regular)
        return configuration
    }

    /// Draws the shape as `UIGlassEffect` does, padded so the band and drop shadow fit outside the frame.
    mutating func drawsAsNativeGlass(chain: LensChain, rim: GlassRim) {
        lensChain = chain
        glassRim = rim
        shape.widthInset = -chain.inset
        shape.heightInset = -chain.inset
        shape.padding = CGPoint(
            x: max(shape.padding.x, Self.nativeGlassPadding.x),
            y: max(shape.padding.y, Self.nativeGlassPadding.y)
        )
        outerGlow = 0
    }

    /// Room outside the frame for native glass; the drop shadow left beyond it stays under one level.
    static let nativeGlassPadding = CGPoint(x: 10, y: 17)

    func drawPadding(for size: CGSize, style: TheseusSettings.GlassStyle = TheseusSettings.shared.effectiveGlassStyle) -> CGPoint {
        guard let reach = nativeLens?.shadowReach ?? glassRim?.styled(style).dropShadowReach(shortSide: min(size.width, size.height)) else { return shape.padding }
        return CGPoint(
            x: max(shape.padding.x, (reach.x - min(shape.widthInset, 0)).rounded(.up)),
            y: max(shape.padding.y, (reach.y - min(shape.heightInset, 0)).rounded(.up))
        )
    }

    /// A more transparent material with reduced edge effects. Mirrors `Glass.clear` (iOS 26+).
    public static var clear: TheseusConfiguration {
        var configuration = TheseusConfiguration()
        configuration.edgeEffects = .subtle
        configuration.refraction = .subtle
        // Native clear glass reads 0.95 x backdrop + 31 levels on iOS 27 and 1.049 x + 19 on iOS 26.5.
        // The style is read when the preset is built.
        let iOS26 = TheseusSettings.shared.effectiveGlassStyle == .iOS26
        configuration.theme.neutralBodyScale = 0.0
        configuration.theme.backdropSaturation = 1.11
        configuration.theme.backdropGain = iOS26 ? 1.049 : 0.95
        configuration.theme.luminanceLift = iOS26 ? 19.0 / 255.0 : 31.0 / 255.0
        configuration.drawsAsNativeGlass(chain: .clearGlass, rim: .clear)
        return configuration
    }

    /// The clear drag-lens material the controls show mid-gesture.
    public static var lens: TheseusConfiguration {
        var configuration = TheseusConfiguration()
        configuration.blur = TheseusBlur(radius: 2.0)
        configuration.refraction.edgeWidth = 8.0
        configuration.refraction.intensity = 1.1
        configuration.refraction.dispersion = 1.9
        configuration.refraction.magnification = 1.2
        configuration.refraction.thickness = 24.0
        configuration.refraction.interiorSharpness = 1.0
        configuration.edgeEffects.rimGlow = 0.25
        configuration.edgeEffects.glareIntensity = 0.12
        configuration.edgeEffects.farColor = UIColor(white: 1.0, alpha: 0.5)
        configuration.edgeEffects.oppositeFalloff = 0.85
        configuration.edgeEffects.glareFocus = 0.15
        configuration.theme.neutralBodyScale = 0.0
        configuration.theme.edgeIridescence = 0.0
        return configuration
    }

    /// Returns a copy with the glass tinted; `nil` removes the tint. Mirrors `Glass.tint(_:)` (iOS 26+).
    /// `color` may carry its own alpha; `intensity` is a 0...1 multiplier on top.
    public func tint(_ color: UIColor?, intensity: CGFloat = 1.0) -> TheseusConfiguration {
        var configuration = self
        configuration.theme.tintColor = color ?? .clear
        configuration.theme.tintOpacity = min(max(intensity, 0.0), 1.0)
        return configuration
    }

    private static let capturePaddingMultiplier: CGFloat = 1.2

    @available(*, deprecated, message: "No effect; the capture region always equals the drawable extent (view bounds + shape.padding). Kept for source compatibility.")
    public var effectiveCapturePadding: CGPoint {
        let defaultPadding = blur.radius * Self.capturePaddingMultiplier
        return CGPoint(
            x: (legacyCapturePadding?.x ?? defaultPadding) + shape.padding.x,
            y: (legacyCapturePadding?.y ?? defaultPadding) + shape.padding.y
        )
    }

    public func effectiveBlurRadius(for quality: QualityLevel, pixelsPerPoint: CGFloat = 1.0) -> Int {
        min(Int((blur.radius * pixelsPerPoint).rounded()), quality.maxBlurRadius)
    }
}
