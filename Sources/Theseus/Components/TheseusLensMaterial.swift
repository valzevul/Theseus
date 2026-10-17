import UIKit

/// Everything that shapes a drag lens: the bevel band (`depth` in points), rim
/// lines, frost, lift (fraction of white), item scale and drag-motion gain.
public struct TheseusLensMaterial: Equatable {
    public var bandWidth: CGFloat
    public var depth: CGFloat
    public var dispersion: CGFloat
    public var blurRadius: CGFloat
    /// Loupe scale of the backdrop through the interior, about the lens centre; below 1 it minifies.
    public var magnification: CGFloat
    /// Share of the unblurred capture mixed into the interior, 0 (blurred) to 1 (sharp).
    public var interiorDetail: CGFloat
    /// Width in points of the backdrop the interior averages (the band a quarter
    /// of it); 0 uses the blur alone.
    public var interiorAverage: CGFloat
    /// Red-to-blue offset in points along the rim, red leading clockwise, and
    /// the depth in points it fades over.
    public var rimDispersion: CGFloat
    public var rimDispersionDepth: CGFloat
    /// Drop shadow outside the rim: opacity, downward offset and Gaussian radius in points.
    public var shadowOpacity: CGFloat
    public var shadowOffset: CGFloat
    public var shadowRadius: CGFloat
    public var lift: CGFloat
    public var liftDark: CGFloat
    public var gain: CGFloat
    public var gainDark: CGFloat
    public var poleMix: CGFloat
    public var poleMixDark: CGFloat
    public var profile: TheseusLensProfile
    public var itemScale: CGFloat
    public var iconScale: CGFloat
    public var motionGain: CGFloat
    public var motionSpeed: CGFloat
    public var motionDecay: CGFloat

    public init(
        bandWidth: CGFloat = 33.3,
        depth: CGFloat = 3.67,
        dispersion: CGFloat = 10,
        blurRadius: CGFloat = 2,
        magnification: CGFloat = 1.0,
        interiorDetail: CGFloat = 1.0,
        interiorAverage: CGFloat = 0,
        rimDispersion: CGFloat = 5.6,
        rimDispersionDepth: CGFloat = 11.3,
        shadowOpacity: CGFloat = 0.06,
        shadowOffset: CGFloat = 5.7,
        shadowRadius: CGFloat = 3.3,
        lift: CGFloat = 0,
        liftDark: CGFloat = 0,
        gain: CGFloat = 1.0,
        gainDark: CGFloat = 1.0,
        poleMix: CGFloat = 0,
        poleMixDark: CGFloat = 0,
        profile: TheseusLensProfile = TheseusLensProfile(),
        itemScale: CGFloat = 1.16,
        iconScale: CGFloat = 1.0,
        motionGain: CGFloat = 0,
        motionSpeed: CGFloat = 600,
        motionDecay: CGFloat = 0.45
    ) {
        self.bandWidth = bandWidth
        self.depth = depth
        self.dispersion = dispersion
        self.blurRadius = blurRadius
        self.magnification = magnification
        self.interiorDetail = interiorDetail
        self.interiorAverage = interiorAverage
        self.rimDispersion = rimDispersion
        self.rimDispersionDepth = rimDispersionDepth
        self.shadowOpacity = shadowOpacity
        self.shadowOffset = shadowOffset
        self.shadowRadius = shadowRadius
        self.lift = lift
        self.liftDark = liftDark
        self.gain = gain
        self.gainDark = gainDark
        self.poleMix = poleMix
        self.poleMixDark = poleMixDark
        self.profile = profile
        self.itemScale = itemScale
        self.iconScale = iconScale
        self.motionGain = motionGain
        self.motionSpeed = motionSpeed
        self.motionDecay = motionDecay
    }

    public static let `default` = TheseusLensMaterial()

    /// `knobGlass` with the rim of the native slider knob on iOS 27.
    public static let sliderKnobGlass: TheseusLensMaterial = {
        var material = knobGlass
        material.profile.contourRamp = 2.5
        material.profile.contourDarkeningLight = 0.28
        material.profile.contourRampDark = 0
        material.profile.contourDarkening = 0.41
        material.profile.contourSide = 1.3
        material.profile.contourSideDark = 1.3
        material.profile.contourSideWidth = 1.0
        material.profile.contourSideWidthDark = 1.0
        material.profile.highlight = 0.10
        material.profile.highlightFade = 2.5
        material.profile.highlightLight = 0.03
        material.profile.highlightWidth = 1.3
        material.profile.highlightFadeLight = 1.0
        material.profile.highlightBottom = 2.0
        material.profile.highlightBottomDark = 1.1
        material.profile.shadeOnset = 30
        material.profile.capExponent = 3.4
        material.profile.capExponentTip = 2.15
        return material
    }()

    /// The pressed knob glass of the native switch and slider on iOS 27.
    public static let knobGlass = TheseusLensMaterial(
        bandWidth: 32,
        depth: 3.17,
        dispersion: 0,
        blurRadius: 2.5,
        magnification: 1.0,
        interiorDetail: 1.0,
        interiorAverage: 0,
        rimDispersion: 0,
        rimDispersionDepth: 0,
        shadowOpacity: 0,
        shadowOffset: 0,
        shadowRadius: 0,
        lift: 0,
        liftDark: 0,
        gain: 1.0,
        gainDark: 1.0,
        poleMix: 0.10,
        poleMixDark: 0.10,
        profile: TheseusLensProfile(
            riseStart: 0.03,
            riseEnd: 0.21,
            fallStart: 0.37,
            fallLength: 0.055,
            frost: 0,
            contourDarkening: 0.416,
            contourDarkeningLight: 0.264,
            highlight: 0.13,
            highlightLight: 0.08,
            highlightSide: 0,
            highlightBottom: 1.0,
            highlightWidth: 0.3,
            highlightFade: 3.5,
            highlightFadeLight: 1.5,
            shade: 0.085,
            shadeDark: 0.21,
            shadeReach: 19.0,
            contourSide: 1.32,
            shadeSide: 1.086,
            shadeOnset: 29.4,
            shadeSideOnset: 7.13,
            highlightBottomDark: 1.0,
            shadeSideDark: 0.95,
            shadeOnsetDark: 30,
            shadeFloor: 0.021,
            shadeFloorDark: 0.06,
            lip: 5.333,
            lipReach: 1.2,
            highlightTail: 0.012,
            highlightTailDark: 0.03,
            contourRamp: 4.0,
            contourSideDark: 1.28,
            contourSideWidth: -0.2,
            contourSideWidthDark: 1.5,
            shadeSideReach: 10.93,
            shadeSideReachDark: 12.51,
            shadeShoulder: 0.55,
            shadeSideShoulder: 0.163,
            shadeLobeTilt: 12.74,
            highlightLobe: 4,
            highlightLobeLight: 8,
            shadeSideOnsetWidth: 24.4,
            shadeCapOnsetShare: 0.711,
            shadeTopExponent: 0.561,
            shadeTopLobeShift: 0.287,
            shadeSideExponent: 3.27,
            contourChroma: 1.0,
            capExponent: 3.0,
            capExponentTip: 2.3,
            capOutlineOnly: true,
            contourFlat: 0.69,
            contourFlatDark: 0.17,
            highlightInLinearLight: false
        ),
        itemScale: 1,
        motionGain: 0
    )

    /// Depth multiplier for a motion activity in 0...1.
    public func depthScale(activity: CGFloat) -> CGFloat {
        1 + max(motionGain, 0) * min(max(activity, 0), 1)
    }
}

extension TheseusLensMaterial {
    func apply(to configuration: inout TheseusConfiguration, isDark: Bool, activity: CGFloat) {
        configuration.refraction.edgeWidth = bandWidth
        configuration.refraction.thickness = depth * depthScale(activity: activity)
        configuration.refraction.dispersion = dispersion
        configuration.refraction.magnification = magnification
        configuration.refraction.interiorSharpness = interiorDetail
        configuration.refraction.interiorAverage = interiorAverage
        configuration.refraction.rimDispersion = rimDispersion
        configuration.refraction.rimDispersionDepth = rimDispersionDepth
        configuration.lensShadowOpacity = shadowOpacity
        configuration.lensShadowOffset = shadowOffset
        configuration.lensShadowRadius = shadowRadius
        configuration.refraction.lensProfile = profile
        configuration.theme.luminanceLift = isDark ? liftDark : lift
        configuration.theme.backdropGain = isDark ? gainDark : gain
        configuration.theme.bodyPoleMix = isDark ? poleMixDark : poleMix
    }
}
