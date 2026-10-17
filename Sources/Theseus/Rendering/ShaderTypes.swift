import simd

/// Memory layout must match the struct in TheseusShaders.metal.
struct GaussianBlurParams {
    var texelSize: SIMD2<Float>   // 1 / texture size
    var blurRadius: Int32         // samples per direction
    var encodedAverage: Int32 = 0 // 1 averages encoded values, 0 linear light
}

/// Memory layout must match the struct in TheseusShaders.metal.
struct QuadVertex {
    var position: SIMD2<Float>    // clip space, -1 to 1
    var texCoord: SIMD2<Float>
}

/// Memory layout must match the struct in TheseusShaders.metal.
struct GlassParams {
    var viewSize: SIMD2<Float>    // pixels
    var cornerRadius: Float       // pixels
    var opacity: Float
    var edgeWidth: Float
    var iorFactor: Float
    var luminanceLift: Float      // 0...1
    var rimGlow: Float
    var lensRiseStart: Float      // fraction of the band from the rim
    var lensRiseEnd: Float        // fraction of the band
    var specularIntensity: Float
    var specularFocus: Float
    var lensFrost: Float          // blurred mix at the bevel peak
    var lensContour: Float
    var oppositeFalloff: Float
    var chromaticSpread: Float
    var mirrorMode: Float = 0     // 0 = lens, 1 = mirror
    var bodyPole: Float = 1       // luminance pole the body mixes toward when bodyParams.x > 0
    var stretchScale: SIMD2<Float>
    var shapePadding: SIMD2<Float> // pixels
    var interiorSharpness: Float = 0 // 0 = blurred backdrop, 1 = sharp source
    var magCenterY: Float = 0     // scaled px, positive = below the drawable centre
    var tint: SIMD4<Float>
    var farSpecularColor: SIMD4<Float>
    var nearSpecularColor: SIMD4<Float>
    var tintWeights: SIMD4<Float> // x surface tint, y edge tint, z highlight tint preservation, w edge iridescence
    var mergeParams: SIMD4<Float> // x merged shape count, y merge smoothing px, z interior magnification (1 = none), w slab thickness px
    var lensLight: SIMD4<Float>   // x strength, y side factor, z width px, w fade px
    var lensFall: SIMD4<Float>    // x plateau end, y tail length (fractions of the band), z rim shading strength, w shading reach px
    var bodyParams: SIMD4<Float>  // x mix toward the pole after the tone, y dark tone strength, z gain, w chroma scale
    var tintParams: SIMD4<Float>  // x body luminance past which a dark tint fades, y the grey it fades toward, z continuous capsule ends (1) or circular (0), w lens bottom-rim highlight factor
    var lensRim: SIMD4<Float>     // x contour factor on the sides, y shade factor on the sides, z side shade onset px, w top shade onset px
    var lensRim2: SIMD4<Float>    // x shade floor inside the rim, y rim lip px, z lip fade px, w rim line tail strength
    var lensRim3: SIMD4<Float>    // x contour ramp px (0 = the 2 px box), y extra side contour width px, z side shade reach px (0 = top reach), w shade shoulder (fraction of the reach; 0 = linear)
    var lensRim4: SIMD4<Float>    // x side shade shoulder (below 0 = lensRim3.w), y side shade lobe tilt deg (0 = up-weighted), z rim line lobe exponent (0 = fourth power, flat tail), w side shade fade-in px (0 = from 2 px inside the rim)
    var lensRim5: SIMD4<Float>    // x contour chroma kept (0 = multiplicative, 1 = luminance-only), y vertical superellipse exponent (0 = stadium), z flat share of the contour drop, w superellipse exponent at the side tips
    var lensRim6: SIMD4<Float>    // x lens fill (0 = glass, 1 = solid), y rim scale (below 0 = 1 - x stays clear), z rim dispersion px, w its depth px
    var lensRim7: SIMD4<Float>    // xyz fill colour (sRGB), w interior average mip level
    var lensRim8: SIMD4<Float>    // lens drop shadow: x opacity (0 = a 2% downward glow instead), y downward offset px, z radius px; w top shade lobe shift
    var lensRim9: SIMD4<Float>    // x share of the top shade onset on the sides, y top hump lobe exponent, z side lobe exponent, w rim line in linear light (1) or encoded (0)
    var shapeEdge: SIMD4<Float> = SIMD4<Float>(-1, 0, 1, 0) // x outer glow of a non-lens shape (below 0 = the built-in constant), y edge feather px (0 = hard), z lens refraction share (1 = full), w superellipse outline only (1)
    var chainWarp: SIMD4<Float> = .zero  // native lens chain, px: x backdrop warp, y its height, z inset of the outline it follows, w warp as is (1) or scaled by the refraction share (0)
    var chainItems: SIMD4<Float> = .zero // x item warp, y item lensing, z their height px, w gradient ovalisation of the warps
    var chainSplit: SIMD4<Float> = .zero // x aberration px (half the red-to-blue spread), y depth px, z fade depth px, w 0 off, 1 on, 2 on with detail from the blurred capture
    var chainInner: SIMD4<Float> = .zero // x inner refraction px (inward at the rim), y its height px, z share of the blurred capture in the warped backdrop, w depth px over which the items fade in from the rim
    var tintModel: SIMD4<Float> = .zero  // brand tint: x gain and y offset per unit of the body's shortfall from white, z closing of the weaker channels on the strongest and w move toward tintParams.y, per unit of body luminance past tintParams.x
    var glassRim: SIMD4<Float> = .zero   // UIGlassEffect rim: x off (0), on (1), iOS 26 (2); y spread of the light band outside the frame (radians), z its gradient ovalisation, w its colour bias
    var glassShadow: SIMD4<Float> = .zero // x ring shadow opacity, y drop shadow amount, z drop shadow sigma px, w drop shadow offset px
    var glassHighlight: SIMD4<Float> = .zero // highlight layer vibrancy: x brightness, y saturation, z offset; w the tint covers the band outside the frame (1) or stops at it (0)
    var glassScale: SIMD4<Float> = .zero // x pixels per point
    var glassBlur: SIMD4<Float> = .zero // frost: x lighten (light) or darken (dark) share of the fill, y the fill's cover, z darken (1) or lighten (0), w a coarse blur is bound (1)
    var glassBlurOpacity: SIMD4<Float> = .zero // the blur radius share: x deep inside (from w px in), y 1 pt inside, z at the frame
    var glassBlurSigma: SIMD4<Float> = .zero // px: x the full blur the shares scale, y the capture's softness, z the detail blur, w the coarse blur
    var glassFace: SIMD4<Float> = .zero // face colour matrix: x black, y white, z saturation, w luminance cap
    var glassFaceFill: SIMD4<Float> = .zero
    var glassOuter: SIMD4<Float> = .zero // outward refraction mixed into the outer rim, px: x amount, y height, z share at the frame, w depth it fades out by
    var glassTintRed: SIMD4<Float> = .zero
    var glassTintGreen: SIMD4<Float> = .zero
    var glassTintBlue: SIMD4<Float> = .zero
    var bodyCurve0: SIMD4<Float> = .zero
    var bodyCurve1: SIMD4<Float> = .zero
    var bodyCurve2: SIMD4<Float> = .zero
    var bodyCurve3: SIMD4<Float> = .zero
    var bodyCurveInfo: SIMD4<Float> = .zero
    var lens26: SIMD4<Float> = .zero
    var lens26Face: SIMD4<Float> = .zero
    var lens26BlurDistance: SIMD4<Float> = .zero
    var lens26BlurOpacity: SIMD4<Float> = .zero
    var lens26Blur: SIMD4<Float> = .zero
    var lens26Aberration: SIMD4<Float> = .zero
    var lens26AberrationAngle: SIMD4<Float> = .zero
    var lens26Shadow: SIMD4<Float> = .zero
    var lens26ShadowOffset: SIMD4<Float> = .zero
    var lens26Key0: SIMD4<Float> = .zero
    var lens26Key1: SIMD4<Float> = .zero
    var lens26Line: SIMD4<Float> = .zero
    var lens26Red0: SIMD4<Float> = .zero
    var lens26Green0: SIMD4<Float> = .zero
    var lens26Blue0: SIMD4<Float> = .zero
    var lens26Red1: SIMD4<Float> = .zero
    var lens26Green1: SIMD4<Float> = .zero
    var lens26Blue1: SIMD4<Float> = .zero
    var lens26Items: SIMD4<Float> = .zero
    var flexGlow: SIMD4<Float> = .zero
    var flexGlowCenter: SIMD4<Float> = .zero
    var flexBigRed: SIMD4<Float> = .zero
    var flexBigGreen: SIMD4<Float> = .zero
    var flexBigBlue: SIMD4<Float> = .zero
}   // Total: 1152 bytes; the layout test in TheseusConfigurationTests pins it.

/// Memory layout must match the struct in TheseusShaders.metal; the scalar
/// pads keep it identical on both sides (no SIMD3 stride surprises).
struct MergeShapeParams {
    var center: SIMD2<Float>      // pixels
    var halfSize: SIMD2<Float>    // pixels
    var cornerRadius: Float       // pixels
    var pad0: Float = 0
    var pad1: Float = 0
    var pad2: Float = 0
}   // Total: 32 bytes each; the shader expects a fixed array of 8

enum MergeShapeLimits {
    static let maxShapes = 8
}

