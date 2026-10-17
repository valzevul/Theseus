#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Types (must match ShaderTypes.swift)

struct GaussianBlurParams {
    float2 texelSize;
    int blurRadius;
    int encodedAverage;   // 0 averages in linear light
};

struct GlassParams {
    float2 viewSize;
    float cornerRadius;
    float opacity;
    float edgeWidth;      // refraction edge thickness, px
    float iorFactor;
    float luminanceLift;  // additive, 0...1
    float rimGlow;
    float lensRiseStart;  // bevel rise start, fraction of the band from the rim
    float lensRiseEnd;    // bevel plateau reached, fraction of the band
    float specularIntensity;
    float specularFocus;
    float lensFrost;      // blurred mix at the bevel peak
    float lensContour;    // contour darkening, 0 = none
    float oppositeFalloff;
    float chromaticSpread;
    float mirrorMode;     // 0 = lens, 1 = mirror
    float bodyPole;       // luminance the body mixes toward by bodyParams.x
    float2 stretchScale;
    float2 shapePadding;  // inset from the edges
    float interiorSharpness; // 0 = blurred backdrop, 1 = sharp source
    float magCenterY;     // loupe centre offset, scaled px, +y down
    float4 tint;
    float4 farSpecularColor;
    float4 nearSpecularColor;
    // x surface tint, y edge tint, z highlight tint preservation, w edge iridescence
    float4 tintWeights;
    // x merged shape count, y merge smoothing px, z interior loupe magnification (1 = none), w slab thickness px
    float4 mergeParams;
    // x lens highlight strength, y side factor, z width px, w fade px
    float4 lensLight;
    // x plateau end and y tail length (fractions of the band), z rim shade strength, w shade reach px
    float4 lensFall;
    // x body mix toward bodyPole after the tone, y dark tone strength, z backdrop gain, w chroma scale
    float4 bodyParams;
    // x body luminance past which a dark tint fades, y the grey it fades toward,
    // z continuous capsule ends (1) or circular (0), w bottom rim highlight share
    float4 tintParams;
    // x contour factor on the sides, y side shade factor, z side shade onset px, w top shade onset px
    float4 lensRim;
    // x shade floor inside the rim, y rim lip px, z lip fade px, w rim line tail strength
    float4 lensRim2;
    // x contour ramp px (0 = 2 px box), y extra side contour px, z side shade reach px (0 = lensFall.w),
    // w shade shoulder as a share of the reach (0 = linear)
    float4 lensRim3;
    // x side shade shoulder (< 0 = lensRim3.w), y side lobe tilt in deg below the horizontal (0 = single-lobe shade),
    // z rim line lobe exponent (0 = 4th power, flat tail), w side shade onset px, ending at lensRim.z
    float4 lensRim4;
    // x contour chroma kept (0 = multiplicative, 1 = luminance only), y superellipse exponent on the vertical axis
    // (0 = stadium), z flat share of the contour drop, w the exponent at the side tips
    float4 lensRim5;
    // x fill toward lensRim7 (0 = glass, 1 = solid), y rim scale on bevel, frost, shade, contour and line (< 0 = 1 - x)
    float4 lensRim6;
    // xyz the fill colour
    float4 lensRim7;
    // xyz the lens drop shadow (opacity, offset px, radius px), w top shade lobe reach below the horizontal
    float4 lensRim8;
    // x top shade onset share on the sides, y top lobe exponent, z side lobe exponent,
    // w rim line in linear light (1) or encoded (0)
    float4 lensRim9;
    // x outer glow (< 0 = OUTER_GLOW_STRENGTH), y edge feather px (0 = hard), z refraction and rim dispersion share,
    // w superellipse outline only (1): shade and refraction follow the stadium
    float4 shapeEdge;
    // px: x backdrop warp, y its height, z frame inset inside the drawn outline,
    // w warp taken as is (1) or scaled by the refraction share (0)
    float4 chainWarp;
    // x item warp, y item lensing, z their height, w gradient ovalisation
    float4 chainItems;
    // x aberration (half the red-to-blue spread), y its depth, z fade depth,
    // w off (0), on (1), on with the blurred capture's detail (2)
    float4 chainSplit;
    // x inner refraction px (inward at the rim), y its height, z blurred share of the warped backdrop,
    // w item fade-in depth from the rim
    float4 chainInner;
    // Brand tint: x gain and y offset per unit of body shortfall from white; z channel closing
    // and w move toward tintParams.y per unit of body luminance past tintParams.x
    float4 tintModel;
    // UIGlassEffect's rim: x on (1) / off (0), y light band spread outside the frame (radians),
    // z gradient ovalisation, w colour bias
    float4 glassRim;
    // x ring shadow opacity, y drop shadow opacity, z drop shadow sigma px, w drop shadow offset px
    float4 glassShadow;
    // Highlight vibrancy: x brightness, y saturation, z offset; w tint covers the outer band (1) or stops at the frame (0)
    float4 glassHighlight;
    // x pixels per point
    float4 glassScale;
    // Frost: x how far the fill lightens (light) or darkens (dark) what lies under it, y fill cover share,
    // z darken (1) or lighten (0), w coarse blur bound (1)
    float4 glassBlur;
    // Blur radius share: x deep inside (from w px in), y 1 pt inside, z at the frame
    float4 glassBlurOpacity;
    // px: x full blur the shares scale, y capture softness, z detail blur, w coarse blur
    float4 glassBlurSigma;
    // Face colour matrix: x black, y white, z saturation, w luminance cap; glassFaceFill the fill colour and alpha
    float4 glassFace;
    float4 glassFaceFill;
    // Outward refraction in the outer rim (px): x amount, y height, z share at the frame, w fade-out depth
    float4 glassOuter;
    float4 glassTintRed;
    float4 glassTintGreen;
    float4 glassTintBlue;
    float4 bodyCurve[4];
    float4 bodyCurveInfo;
    float4 lens26;
    float4 lens26Face;
    float4 lens26BlurDistance;
    float4 lens26BlurOpacity;
    float4 lens26Blur;
    float4 lens26Aberration;
    float4 lens26AberrationAngle;
    float4 lens26Shadow;
    float4 lens26ShadowOffset;
    float4 lens26Key0;
    float4 lens26Key1;
    float4 lens26Line;
    float4 lens26Red0;
    float4 lens26Green0;
    float4 lens26Blue0;
    float4 lens26Red1;
    float4 lens26Green1;
    float4 lens26Blue1;
    float4 lens26Items;
    float4 flexGlow;
    float4 flexGlowCenter;
    float4 flexBigRed;
    float4 flexBigGreen;
    float4 flexBigBlue;
};   // 1152 bytes, matching the Swift GlassParams layout

// Must match MergeShapeParams in ShaderTypes.swift.
struct MergeShape {
    float2 center;       // already divided by the stretch scale
    float2 halfSize;
    float cornerRadius;
    float pad0;
    float pad1;
    float pad2;
};   // 32 bytes each

constant int MAX_MERGE_SHAPES = 8;

constant float PI = 3.14159265359;

constant float CHROMATIC_SPREAD = 0.032;

constant float RIM_BASE = 0.035;
constant float RIM_SCALE = 0.965;  // 1.0 - RIM_BASE

constant float REFLECTION_POWER = 30.0;
constant float2 LIGHT_VECTOR = float2(0.7071, -0.7071);

constant float OUTER_GLOW_STRENGTH = 0.22;
constant float OUTER_GLOW_SPREAD = 6.0;
constant float OUTER_GLOW_FALLOFF = 0.85;
constant float3 GLOW_TINT = float3(0.0);
constant float2 GLOW_BIAS = float2(0.0, 1.0);
constant float GLOW_FOCUS = 1.0;

constant float INNER_VIGNETTE_STRENGTH = 0.05;

constant float DARK_TONE_LIFT = 0.1148;
constant float DARK_TONE_RANGE = 0.7557;
constant float DARK_TONE_SCALE = 0.6787;


// Left unclamped: a channel the pole mix pushes past 1 must survive the lens shade.
static float3 applyBodyUnclamped(half3 c, constant GlassParams& params) {
    float3 v = clamp(float3(c), 0.0, 1.0);
    float lum = dot(v, float3(0.2126, 0.7152, 0.0722));
    if (params.bodyCurveInfo.x > 0.5) {
        float x = lum * 15.0;
        int i = min(int(x), 14);
        int j = i + 1;
        float curve = mix(params.bodyCurve[i >> 2][i & 3], params.bodyCurve[j >> 2][j & 3], x - float(i));
        float3 w = clamp(curve + (v - lum) * (params.bodyParams.w + params.bodyCurveInfo.y * lum), 0.0, 1.0);
        float wl = dot(w, float3(0.2126, 0.7152, 0.0722));
        w = wl + (w - wl) * params.bodyCurveInfo.z;
        return max(w * params.bodyParams.z + params.luminanceLift, 0.0);
    }
    float toned = lum;
    if (params.bodyParams.y > 0.0) {
        float tone = DARK_TONE_LIFT + DARK_TONE_RANGE * (1.0 - exp(-lum / DARK_TONE_SCALE));
        toned = mix(lum, tone, params.bodyParams.y);
    }
    if (params.bodyParams.x > 0.0) {
        toned = mix(toned, params.bodyPole, params.bodyParams.x);
    }
    v = toned + (v - lum) * params.bodyParams.w;
    v = v * params.bodyParams.z + params.luminanceLift;
    return max(v, 0.0);
}

static half3 applyBody(half3 c, constant GlassParams& params) {
    return half3(clamp(applyBodyUnclamped(c, params), 0.0, 1.0));
}

constant float LENS_DISPERSION_SCALE = 0.011;
// Taps run from red (t = -1) to blue (t = 1); each channel weights them by a
// Gaussian about its own centroid.
constant int LENS_SPECTRUM_TAPS = 9;
// How far the spectrum ends sit inward of green, as a share of their spread along the rim.
constant float CHAIN_SPLIT_INWARD = 0.35;
constant float LENS_SPECTRUM_CENTROID = 0.6;
constant float LENS_SPECTRUM_WIDTH = 0.7;
// Green stays on its own tap; red and blue streak along the rim.
constant float3 CHAIN_SPECTRUM_WIDTHS = float3(0.7, 0.25, 0.7);
constant float LENS_CONTOUR_PX = 2.0;
constant float3 LENS_HIGHLIGHT_TINT = float3(0.85, 0.95, 1.0);
constant float LENS_HIGHLIGHT_SPLIT_PX = 2.0;
constant float LENS_HIGHLIGHT_TAIL_PX = 12.0;
constant float LENS_SHADOW_STRENGTH = 0.02;
constant float LENS_SHADOW_SPREAD = 12.0;

static float lensShadeFall(float nDist, float reach, float shoulder) {
    float s = clamp(shoulder, 0.0, 0.95);
    return (s > 0.0)
        ? 1.0 - smoothstep(s * reach, reach, nDist)
        : clamp(1.0 - nDist / reach, 0.0, 1.0);
}

static float lensBevelProfile(float x, float riseStart, float riseEnd, float fallStart, float fallLength) {
    float r0 = clamp(riseStart, 0.0, 0.95);
    float r1 = clamp(riseEnd, r0 + 0.01, 0.98);
    float rise = clamp((x - r0) / (r1 - r0), 0.0, 1.0);
    float f0 = max(fallStart, r1);
    float fall = (x <= f0) ? 1.0 : exp(-(x - f0) / max(fallLength, 0.01));
    return rise * fall;
}
constant float INNER_VIGNETTE_SPREAD = 20.0;
constant float INNER_VIGNETTE_FALLOFF = 1.0;
constant float2 INNER_VIGNETTE_BIAS = float2(0.0, -1.0);

inline float fresnelPow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

float rimIntensity(float2 normal, float2 viewDir) {
    float cosTheta = max(dot(normalize(normal), normalize(viewDir)), 0.0);
    return RIM_BASE + RIM_SCALE * fresnelPow5(1.0 - cosTheta);
}

float edgeReflection(float2 normal, float2 viewDir) {
    float2 lightDir = normalize(LIGHT_VECTOR);
    float2 halfVec = normalize(lightDir + normalize(viewDir));
    float NdotH = max(dot(normalize(normal), halfVec), 0.0);
    return pow(NdotH, REFLECTION_POWER);
}

// MARK: - OKLab Recoloring (tinted highlights)

// Inputs are the encoded working values, not linearised.
float3 rgbToOKLab(float3 c) {
    float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
    float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
    float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
    float3 lms = pow(max(float3(l, m, s), float3(0.0)), float3(1.0 / 3.0));
    return float3(
        0.2104542553 * lms.x + 0.7936177850 * lms.y - 0.0040720468 * lms.z,
        1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z,
        0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z
    );
}

float3 oklabToRGB(float3 lab) {
    float l_ = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
    float m_ = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
    float s_ = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
    float3 lms = float3(l_, m_, s_);
    lms = lms * lms * lms;
    return float3(
        4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
        -1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
        -0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z
    );
}

// w = chroma transfer amount (0 = base unchanged).
half3 okRecolor(half3 base, half3 tintRGB, float w) {
    float3 baseLab = rgbToOKLab(float3(base));
    float3 tintLab = rgbToOKLab(float3(tintRGB));
    float3 outLab = float3(
        baseLab.x,
        mix(baseLab.y, tintLab.y, w),
        mix(baseLab.z, tintLab.z, w)
    );
    return half3(clamp(oklabToRGB(outLab), 0.0, 1.0));
}

struct QuadVertex {
    float2 position;
    float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Vertex Shader

vertex VertexOut vertexPassthrough(
    uint vertexID [[vertex_id]],
    constant QuadVertex* vertices [[buffer(0)]]
) {
    VertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

// MARK: - Linear-light averaging

// Native materials average their backdrop in linear light.

static inline float3 srgbToLinear(float3 c) {
    return select(pow((c + 0.055) / 1.055, float3(2.4)), c / 12.92, c <= 0.04045);
}

static inline float3 linearToSrgb(float3 c) {
    c = max(c, 0.0);
    return select(1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, c * 12.92, c <= 0.0031308);
}

// Brand tint as native glass draws it: the tint follows the body's brightness,
// then covers the body at its alpha; weight fades it back out.
static float3 tintComposite(float3 body, half4 tintColor, constant GlassParams& params, float weight) {
    float alpha = clamp(float(tintColor.a), 0.0, 1.0);
    float3 tint = clamp(float3(tintColor.rgb), 0.0, 1.0);
    float lum = clamp(dot(clamp(body, 0.0, 1.0), float3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
    float3 target = tint * (1.0 - params.tintModel.x * (1.0 - lum)) - params.tintModel.y * (1.0 - lum);
    float rise = max(lum - params.tintParams.x, 0.0);
    float strongest = max(target.r, max(target.g, target.b));
    target = strongest - (1.0 - params.tintModel.z * rise) * (strongest - target);
    target += params.tintModel.w * rise * (params.tintParams.y - target);
    return body + clamp(weight, 0.0, 1.0) * alpha * (clamp(target, 0.0, 1.0) - body);
}

static half4 tintOver(half4 color, half4 tintColor, constant GlassParams& params, float weight) {
    return half4(half3(tintComposite(float3(color.rgb), tintColor, params, weight)), color.a);
}

static inline float4 linearSample(texture2d<half, access::sample> t, sampler s, float2 uv) {
    float4 c = float4(t.sample(s, uv));
    return float4(srgbToLinear(c.rgb), c.a);
}

static inline float4 blurTap(texture2d<half, access::sample> t, sampler s, float2 uv, bool encoded) {
    return encoded ? float4(t.sample(s, uv)) : linearSample(t, s, uv);
}

// MARK: - Horizontal Gaussian Blur

fragment half4 gaussianBlurHorizontal(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> srcTexture [[texture(0)]],
    constant GaussianBlurParams& params [[buffer(0)]],
    constant float* weights [[buffer(1)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    bool encoded = params.encodedAverage != 0;
    float4 color = blurTap(srcTexture, textureSampler, in.texCoord, encoded) * weights[0];

    for (int i = 1; i <= params.blurRadius; ++i) {
        float w = weights[i];
        float offsetX = float(i) * params.texelSize.x;
        color += blurTap(srcTexture, textureSampler, in.texCoord + float2(offsetX, 0.0), encoded) * w;
        color += blurTap(srcTexture, textureSampler, in.texCoord - float2(offsetX, 0.0), encoded) * w;
    }

    return encoded ? half4(color) : half4(half3(linearToSrgb(color.rgb)), half(color.a));
}

// MARK: - Vertical Gaussian Blur

fragment half4 gaussianBlurVertical(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> srcTexture [[texture(0)]],
    constant GaussianBlurParams& params [[buffer(0)]],
    constant float* weights [[buffer(1)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    bool encoded = params.encodedAverage != 0;
    float4 color = blurTap(srcTexture, textureSampler, in.texCoord, encoded) * weights[0];

    for (int i = 1; i <= params.blurRadius; ++i) {
        float w = weights[i];
        float offsetY = float(i) * params.texelSize.y;
        color += blurTap(srcTexture, textureSampler, in.texCoord + float2(0.0, offsetY), encoded) * w;
        color += blurTap(srcTexture, textureSampler, in.texCoord - float2(0.0, offsetY), encoded) * w;
    }

    return encoded ? half4(color) : half4(half3(linearToSrgb(color.rgb)), half(color.a));
}

// MARK: - Shape Distance Functions

// Native capsules leave their straight sides early: the edge runs inside the
// circular cap by this share of the radius, every 0.05 radii from 0.6 before the cap to 0.65 into it.
constant float CAPSULE_END_DEPTH[26] = {
    0.0, 0.0, 0.00006, 0.00063, 0.00155, 0.00258, 0.00354, 0.00459, 0.00578,
    0.00724, 0.00882, 0.01080, 0.01355, 0.01611, 0.01684, 0.01655, 0.01552,
    0.01320, 0.01024, 0.00752, 0.00500, 0.00285, 0.00103, 0.00031, 0.0, 0.0
};

static float capsuleContinuity(float2 uv, float2 center, float2 halfSize, float r) {
    float radius = min(halfSize.x, halfSize.y);
    float corner = (r < 0.0) ? min(-r, radius) : r;
    if (radius < 1.0 || corner < radius - 0.5) { return 0.0; }
    float2 p = abs(uv - center);
    float u = (halfSize.x >= halfSize.y) ? p.x - (halfSize.x - radius) : p.y - (halfSize.y - radius);
    float x = (u / radius + 0.6) / 0.05;
    if (x <= 0.0 || x >= 25.0) { return 0.0; }
    int i = int(x);
    return radius * mix(CAPSULE_END_DEPTH[i], CAPSULE_END_DEPTH[i + 1], x - float(i));
}

// A negative r is the drag-lens sentinel: its magnitude is the corner radius of a stadium.
float shapeDistance(float2 uv, float2 center, float2 halfSize, float r) {
    float rr = (r < 0.0) ? min(-r, min(halfSize.x, halfSize.y)) : r;
    float2 q = abs(uv - center) - (halfSize - float2(rr));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

// Always a unit vector: sign() would return 0 on the centre row and column, so 0 resolves to +1.
float2 shapeGradient(float2 uv, float2 center, float2 halfSize, float r) {
    float rr = (r < 0.0) ? min(-r, min(halfSize.x, halfSize.y)) : r;
    float2 p = uv - center;
    float2 q = abs(p) - (halfSize - float2(rr));
    float2 signP = float2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);

    float2 grad;
    if (q.x > 0.0 && q.y > 0.0) {
        float len = length(q);
        grad = (len > 0.0001) ? (q / len) : float2(0.7071, 0.7071);
        grad *= signP;
    } else if (q.x > q.y) {
        grad = float2(signP.x, 0.0);
    } else {
        grad = float2(0.0, signP.y);
    }

    return grad;
}

// Superellipse |x/a|^n + |y/b|^n = 1, n easing from nTop (vertical axis) to nTip (side tips) by (x/a)^2.
// Distance (G - 1) / |grad G| with G = F^(1/n): exact on both axes, first order elsewhere.
static void lensSuperellipseStep(float2 p, float2 hs, float nTop, float nTip,
                                 thread float& dist, thread float2& normal) {
    float2 u = abs(p) / hs;
    float n = mix(nTop, (nTip > 0.0) ? nTip : nTop, clamp(u.x * u.x, 0.0, 1.0));
    float2 un = pow(max(u, float2(1e-5)), float2(n - 1.0));
    float F = max(un.x * u.x + un.y * u.y, 1e-12);
    float G = pow(F, 1.0 / n);
    float2 gradF = float2(un.x / hs.x, un.y / hs.y) * n;
    float gradFLen = length(gradF);
    float gradGLen = max((1.0 / n) * pow(F, 1.0 / n - 1.0) * gradFLen, 1.0 / max(hs.x, hs.y));
    dist = (G - 1.0) / gradGLen;
    float2 sgn = float2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
    normal = (gradFLen > 1e-9) ? (gradF / gradFLen) * sgn : float2(0.0, sgn.y);
}

// Newton steps along the normal: the first-order distance overshoots deep inside between the axes.
static void lensSuperellipse(float2 uv, float2 center, float2 halfSize, float nTop, float nTip,
                             thread float& dist, thread float2& normal) {
    float2 hs = max(halfSize, float2(1.0));
    float2 p = uv - center;
    float d0;
    float2 n0;
    lensSuperellipseStep(p, hs, nTop, nTip, d0, n0);
    float2 q = p - d0 * n0;
    float d1;
    float2 n1;
    lensSuperellipseStep(q, hs, nTop, nTip, d1, n1);
    q = q - d1 * n1;
    float d2;
    float2 n2;
    lensSuperellipseStep(q, hs, nTop, nTip, d2, n2);
    float2 boundary = q - d2 * n2;
    float len = length(p - boundary);
    dist = (d0 < 0.0) ? -len : len;
    normal = n2;
}

float lensShapeDistance(float2 uv, float2 center, float2 halfSize, float r, float nTop, float nTip) {
    if (r >= 0.0 || nTop <= 0.0) {
        return shapeDistance(uv, center, halfSize, r);
    }
    float dist;
    float2 normal;
    lensSuperellipse(uv, center, halfSize, nTop, nTip, dist, normal);
    return dist;
}

float2 lensShapeGradient(float2 uv, float2 center, float2 halfSize, float r, float nTop, float nTip) {
    if (r >= 0.0 || nTop <= 0.0) {
        return shapeGradient(uv, center, halfSize, r);
    }
    float dist;
    float2 normal;
    lensSuperellipse(uv, center, halfSize, nTop, nTip, dist, normal);
    return normal;
}

// MARK: - Shape Merging (smooth union)

// Polynomial smooth minimum; k is the blend distance in pixels
float smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float combinedShapeDistance(
    float2 uv, float2 center, float2 halfSize, float r,
    constant MergeShape* shapes, int count, float k
) {
    float d = shapeDistance(uv, center, halfSize, r);
    for (int i = 0; i < count && i < MAX_MERGE_SHAPES; ++i) {
        float di = shapeDistance(uv, shapes[i].center, shapes[i].halfSize, shapes[i].cornerRadius);
        d = smoothUnion(d, di, k);
    }
    return d;
}

float2 combinedShapeGradient(
    float2 uv, float2 center, float2 halfSize, float r,
    constant MergeShape* shapes, int count, float k
) {
    const float eps = 1.0;
    float dx = combinedShapeDistance(uv + float2(eps, 0.0), center, halfSize, r, shapes, count, k)
             - combinedShapeDistance(uv - float2(eps, 0.0), center, halfSize, r, shapes, count, k);
    float dy = combinedShapeDistance(uv + float2(0.0, eps), center, halfSize, r, shapes, count, k)
             - combinedShapeDistance(uv - float2(0.0, eps), center, halfSize, r, shapes, count, k);
    float2 grad = float2(dx, dy);
    float len = length(grad);
    return (len > 0.0001) ? (grad / len) : float2(0.0, 1.0);
}

// CoreAnimation's SDF glass displacement falloff.
static float chainFalloff(float x) {
    return (x < 1.0) ? 1.0 - sqrt(max(x * (2.0 - x), 0.0)) : 0.0;
}

static float chainDepth(float2 q, float2 center, float2 halfSize, float r, float nTop, float nTip) {
    return max(-lensShapeDistance(q, center, halfSize, r, nTop, nTip), 0.0);
}

static float2 chainNormal(float2 q, float2 center, float2 halfSize, float r, float nTop, float nTip, float oval) {
    float2 g = lensShapeGradient(q, center, halfSize, r, nTop, nTip);
    float2 n = (dot(g, g) > 1e-8) ? normalize(g) : float2(0.0, -1.0);
    if (oval > 0.0) {
        float2 e = (q - center) / max(halfSize * halfSize, float2(1.0));
        if (dot(e, e) > 1e-12) {
            n = normalize(mix(n, normalize(e), oval));
        }
    }
    return n;
}

constant float GLASS_CORNER_EXTENT = 1.528665;
constant float GLASS_BLUR_OUTSIDE_SHARE = 1.0;

static float glassSupercircleDistance(float2 q, float2 center, float2 halfSize, float radius) {
    float2 p = abs(q - center);
    float r = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    float big = r * 1.5286649;
    float2 k = clamp((big - halfSize) / max(big - r, 1e-4), 0.0, 1.0);
    float2 c = p - halfSize + mix(big, r, max(k.x, k.y));
    float2 a = max(float2(0.0), (p - halfSize + big) / max(big, 1e-4));
    float len = length(a);
    float hi = max(a.x, a.y);
    float t = (hi == 0.0) ? 0.0 : clamp(min(a.x, a.y) / hi, 0.0, 1.0);
    float poly = (((3.1560099 - 0.9260540 * t) * t - 3.6412201) * t + 1.2680300) * t + 0.2685310;
    float continuous = (len + 1.0) - 1.0 / (1.0 - t * t * clamp(len, 0.0, 1.0) * poly);
    float circular = length(max(float2(0.0), a * 1.5286649 - 0.5286650)) * 0.6541656 + 0.3458344;
    float along = mix(continuous, circular, k.x);
    float across = mix(continuous, circular, k.y);
    float sgn = (a.y > a.x) ? 1.0 : -1.0;
    float v = float(half(mix(along, across, clamp(0.5 - sgn + sgn * t, 0.0, 1.0)) - 1.0));
    return min(max(c.x, c.y), 0.0) + big * v;
}

static float2 nativeGlassNormal(float2 p, float2 center, float2 halfSize, float radius, float oval) {
    float2 d = p - center;
    float r = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    float big = r * GLASS_CORNER_EXTENT;
    float2 k = clamp((big - halfSize) / max(big - r, 1e-4), 0.0, 1.0);
    float2 q = abs(d) - halfSize + mix(big, r, max(k.x, k.y));
    float2 qq = max(q, 0.0);
    float2 n = (qq.x + qq.y > 0.0) ? normalize(qq) : ((q.x > q.y) ? float2(1.0, 0.0) : float2(0.0, 1.0));
    n *= float2(d.x >= 0.0 ? 1.0 : -1.0, d.y >= 0.0 ? 1.0 : -1.0);
    float2 e = float2(d.x, d.y * halfSize.x / max(halfSize.y, 1e-4));
    if (oval > 0.0 && dot(e, e) > 1e-8) {
        n = normalize(mix(n, normalize(e), oval));
    }
    return n;
}

static float glassRadius(constant GlassParams& params, float2 halfSize) {
    return (params.cornerRadius < 0.0) ? min(halfSize.x, halfSize.y) : params.cornerRadius;
}

static float2 chainWarpPoint(float2 q, float2 center, float2 warpHalf, float r, float nTop, float nTip, float oval,
                             float innerPx, float innerH, float warpPx, float warpH, float share) {
    float frameDist = lensShapeDistance(q, center, warpHalf, r, nTop, nTip);
    if (frameDist >= 0.0) {
        return q;
    }
    float2 nb = chainNormal(q, center, warpHalf, r, nTop, nTip, 0.0);
    float2 qi = q - nb * (innerPx * chainFalloff(-frameDist / innerH) * share);
    float di = chainDepth(qi, center, warpHalf, r, nTop, nTip);
    float2 ni = chainNormal(qi, center, warpHalf, r, nTop, nTip, oval);
    return clamp(qi + ni * (warpPx * chainFalloff(di / warpH)), center - warpHalf, center + warpHalf);
}

// MARK: - UIGlassEffect rim

// The light band: key and fill lights reaching 0.5333 pt past the frame,
// remapped by t / (1 + k (1 - t)) with k = 1/amount - 2.
constant float GLASS_BAND_EXTENT_PT = 0.5333;
constant float GLASS_BAND_REMAP = 0.5;
// The tint layer reaches this far past the frame in light appearance.
constant float GLASS_TINT_BAND_PT = 0.5333;
// The ring shadow: a 4 pt stroke inside the frame, shifted 8 pt down and blurred.
constant float GLASS_RING_AMOUNT = 1.024;
constant float GLASS_RING_SIGMA_PT = 5.36;
constant float GLASS_RING_WIDTH_PT = 4.05;
constant float GLASS_RING_OFFSET_PT = 7.98;
constant float GLASS_LINE_HEIGHT_PT = 1.0;
constant float GLASS_LINE_COS = 0.173648;
constant float GLASS_LINE_CURVATURE = 0.75;
constant float GLASS_LINE_CURVATURE_26 = 0.7;
constant float GLASS_GLOW_HEIGHT_PT = 8.0;
constant float GLASS_GLOW_COS = 0.615661;
constant float GLASS_GLOW_REMAP = 11.333333;

static float glassNormalCDF(float x) {
    return 1.0 / (1.0 + exp(-1.702 * x));
}

static float glassDropShadow(float distance, float sigma, float amount) {
    float x = distance / max(sigma, 0.5);
    if (x >= 2.0) {
        return 0.0;
    }
    float z = abs(x) * 0.70710678;
    float t = 1.0 / (1.0 + 0.3275911 * z);
    float tail = 0.5 * t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429)))) * exp(-z * z);
    return amount * (x > 0.0 ? tail : 1.0 - tail);
}

static float glassLight(float s, float fw, float height, float cosSpread, float remap, float curvature, float facing) {
    float t = clamp(s / height, 0.0, 1.0);
    float profile = curvature >= 0.0 ? mix(t < 1.0 ? 1.0 : 0.0, 1.0 - t, curvature) : 1.0 - t;
    float v = clamp(s / fw + 0.5, 0.0, 1.0) * clamp((height - s) / fw + 0.5, 0.0, 1.0) * profile
        * clamp((facing - cosSpread) / (1.0 - cosSpread), 0.0, 1.0);
    return v / max(1.0 + remap * (1.0 - v), 1e-6);
}

// UIGlassEffect's face colour matrix, on encoded values.
static float3 glassFace(float3 c, constant GlassParams& params) {
    float3 v = clamp(c, 0.0, 1.0);
    float4 f = params.glassFace;
    float luma = dot(v, float3(0.2126, 0.7152, 0.0722));
    float t = clamp(1.0 - (1.0 - f.w) * luma, 0.0, 1.0);
    float capped = t * luma;
    v = capped + t * (1.0 + 0.3 * (1.0 - t)) * (v - luma);
    v += f.x + (f.y - f.x) * capped - capped;
    float mapped = dot(v, float3(0.2126, 0.7152, 0.0722));
    v = mapped + f.z * (v - mapped);
    return mix(v, params.glassFaceFill.rgb, params.glassFaceFill.a);
}

static float3 glassVibrancy(float3 c, float4 v) {
    float luma = dot(c, float3(0.2126, 0.7152, 0.0722));
    return clamp(v.x * mix(float3(luma), c, v.y) + v.z, -0.75, 1.0);
}

constant float GLASS_TINT_CLAMP = 1.2;

static float3 glassTint(float3 c, float alpha, constant GlassParams& params) {
    float4 x = float4(c, 1.0);
    float3 tinted = float3(dot(params.glassTintRed, x), dot(params.glassTintGreen, x), dot(params.glassTintBlue, x));
    return mix(c, clamp(tinted, -0.75, GLASS_TINT_CLAMP), alpha);
}

// depth is px inside the frame; the fill is read unrefracted at fillUV.
static float3 glassFrostTap(float3 detail, float2 uv, float2 fillUV, float depth, float pointPx,
                            texture2d<half, access::sample> blurredTexture,
                            texture2d<half, access::sample> wideBlur,
                            texture2d<half, access::sample> wideFill,
                            sampler textureSampler, constant GlassParams& params, bool filled = true) {
    float3 tap = detail;
    if (params.glassBlur.w > 0.5) {
        float radiusShare = (depth < 0.0)
            ? GLASS_BLUR_OUTSIDE_SHARE
            : (depth < pointPx)
            ? mix(params.glassBlurOpacity.z, params.glassBlurOpacity.y, depth / pointPx)
            : mix(params.glassBlurOpacity.y, params.glassBlurOpacity.x, clamp((depth - pointPx) / max(params.glassBlurOpacity.w - pointPx, 1.0), 0.0, 1.0));
        float blurPx = length(float2(params.glassBlurSigma.x * radiusShare, params.glassBlurSigma.y));
        float coarseShare = clamp((blurPx - params.glassBlurSigma.z) / max(params.glassBlurSigma.w - params.glassBlurSigma.z, 1e-3), 0.0, 1.0);
        tap = mix(tap, float3(wideBlur.sample(textureSampler, uv).rgb), coarseShare);
    }
    if (filled && (params.glassBlur.x > 0.0 || params.glassBlur.y > 0.0)) {
        float3 fill = float3(wideFill.sample(textureSampler, fillUV).rgb);
        float3 lit = (params.glassBlur.z > 0.5) ? min(tap, fill) : max(tap, fill);
        tap = mix(mix(tap, lit, params.glassBlur.x), fill, params.glassBlur.y);
    }
    return tap;
}

// Signed distance to the frame, px, negative inside; the drawn outline sits chainWarp.z outside it.
static float glassFrameDistance(float2 q, float2 center, float2 halfSize, constant GlassParams& params,
                                constant MergeShape* mergeShapes, int mergeCount, float mergeK) {
    float d = (mergeCount > 0)
        ? combinedShapeDistance(q, center, halfSize, params.cornerRadius, mergeShapes, mergeCount, mergeK)
        : (params.tintParams.z > 0.5 && params.cornerRadius < 0.0)
        ? glassSupercircleDistance(q, center, halfSize, min(halfSize.x, halfSize.y))
        : lensShapeDistance(q, center, halfSize, params.cornerRadius, 0.0, 0.0);
    return d + params.chainWarp.z;
}

static float3 glassHalfResBackdrop(texture2d<half, access::sample> t, float2 uv) {
    constexpr sampler point(filter::nearest, address::clamp_to_edge);
    float2 texel = 1.0 / float2(t.get_width(), t.get_height());
    const float w[5] = { 1.0, 4.0, 6.0, 4.0, 1.0 };
    float3 sum = float3(0.0);
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            sum += w[i + 2] * w[j + 2] * srgbToLinear(float3(t.sample(point, uv + float2(i, j) * texel).rgb));
        }
    }
    return linearToSrgb(sum / 256.0);
}

static half4 glassRimComposite(float3 body, half4 tintColor, constant GlassParams& params, float frameD,
                               float2 nrm, float2 p, float2 center, float2 halfSize, float3 back, float3 halfBack,
                               constant MergeShape* mergeShapes, int mergeCount, float mergeK) {
    float px = max(params.glassScale.x, 0.5);
    float2 frameHalf = max(halfSize - float2(params.chainWarp.z), float2(1.0));
    float2 n = nativeGlassNormal(p, center, frameHalf, glassRadius(params, frameHalf), params.glassRim.z);
    float fw = max(abs(nrm.x) + abs(nrm.y), 1e-4);
    float coverage = clamp(0.5 - frameD / fw, 0.0, 1.0);

    float3 inside = body;
    if (coverage > 0.0) {
        float ringD = glassFrameDistance(p - float2(0.0, GLASS_RING_OFFSET_PT * px), center, halfSize, params, mergeShapes, mergeCount, mergeK);
        float sigma = GLASS_RING_SIGMA_PT * px;
        float ring = GLASS_RING_AMOUNT * (glassNormalCDF(-ringD / sigma) - glassNormalCDF((-GLASS_RING_WIDTH_PT * px - ringD) / sigma));
        inside *= 1.0 - params.glassShadow.x * clamp(ring, 0.0, 1.0);
    }

    bool generation26 = params.glassRim.x > 1.5;
    float band = 0.0;
    float3 outside = back;
    float3 restore = float3(0.0);
    if (coverage < 1.0) {
        float dropD = glassFrameDistance(p - float2(0.0, params.glassShadow.w), center, halfSize, params, mergeShapes, mergeCount, mergeK);
        float drop = glassDropShadow(dropD, params.glassShadow.z, params.glassShadow.y);
        float c = cos(max(params.glassRim.y, 0.01));
        float reach = (1.0 - coverage) * clamp((GLASS_BAND_EXTENT_PT * px - frameD) / fw + 0.5, 0.0, 1.0);
        for (int side = 0; side < (generation26 ? 0 : 2); side++) {
            float facing = (side == 0) ? n.x : -n.x;
            float v = clamp((facing - c) / (1.0 - c), 0.0, 1.0) * reach;
            band += v / max(1.0 + GLASS_BAND_REMAP * (1.0 - v), 1e-6);
        }
        float3 lowered = min(glassFace(halfBack, params), halfBack);
        outside = (1.0 - drop) * mix(halfBack, lowered, band);
        restore = (1.0 - coverage) * (1.0 - drop) * (1.0 - band) * (back - halfBack);
    }

    float3 color = mix(outside, inside, coverage);
    color *= 1.0 + params.glassRim.w * band * (3.0 - 2.0 * color);
    color += restore;
    if (tintColor.a > 0.001h) {
        float tintReach = params.glassHighlight.w > 0.5 ? clamp(0.5 + (GLASS_TINT_BAND_PT * px - frameD) / fw, 0.0, 1.0) : coverage;
        float share = clamp(float(tintColor.a), 0.0, 1.0) * clamp(params.tintWeights.x, 0.0, 1.0);
        color = glassTint(color, share * tintReach, params);
    }
    float s = -frameD;
    float up = -n.y;
    float lineHeight = GLASS_LINE_HEIGHT_PT * px;
    float glowHeight = GLASS_GLOW_HEIGHT_PT * px;
    float diagonal = dot(n, float2(-M_SQRT1_2_F, -M_SQRT1_2_F));
    float light = generation26
        ? glassLight(s, fw, lineHeight, 0.0, 0.0, GLASS_LINE_CURVATURE_26, diagonal)
            + glassLight(s, fw, lineHeight, 0.0, 0.0, GLASS_LINE_CURVATURE_26, -diagonal)
        : glassLight(s, fw, lineHeight, GLASS_LINE_COS, 0.0, GLASS_LINE_CURVATURE, up)
            + glassLight(s, fw, lineHeight, GLASS_LINE_COS, 0.0, GLASS_LINE_CURVATURE, -up)
            + glassLight(s, fw, glowHeight, GLASS_GLOW_COS, GLASS_GLOW_REMAP, -1.0, up)
            + glassLight(s, fw, glowHeight, GLASS_GLOW_COS, GLASS_GLOW_REMAP, -1.0, -up);
    color += light * (glassVibrancy(color, params.glassHighlight) - color);
    return half4(half3(clamp(color, 0.0, 1.0)), 1.0h);
}

// MARK: - Glass Rendering

half4 sampleWithAberration(
    texture2d<half, access::sample> tex,
    sampler s,
    float2 baseUV,
    float2 offset,
    float aberrationFactor
) {
    float spread = CHROMATIC_SPREAD * aberrationFactor;
    half4 pixel = half4(1.0h);
    pixel.r = tex.sample(s, baseUV + offset * (1.0 + spread)).r;
    pixel.g = tex.sample(s, baseUV + offset).g;
    pixel.b = tex.sample(s, baseUV + offset * (1.0 - spread)).b;
    return pixel;
}

static float lens26Phi(float x) {
    float z = abs(x) * 0.70710678;
    float t = 1.0 / (1.0 + 0.3275911 * z);
    float tail = 0.5 * t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429)))) * exp(-z * z);
    return (x > 0.0) ? 1.0 - tail : tail;
}

static float lens26Erfc(float u) {
    float x = clamp(u, -2.0, 2.0);
    float x2 = x * x;
    return (((0.0029544830322265625 * x2 - 0.034454345703125) * x2 + 0.168212890625) * x2 - 0.560546875) * x + 0.5;
}

static float lens26BlurShare(float x, constant GlassParams& params) {
    float4 d = params.lens26BlurDistance;
    float4 o = params.lens26BlurOpacity;
    float v = o.x;
    v += (d.y > d.x) ? (o.y - o.x) * clamp((x - d.x) / (d.y - d.x), 0.0, 1.0) : 0.0;
    v += (d.z > d.y) ? (o.z - o.y) * clamp((x - d.y) / (d.z - d.y), 0.0, 1.0) : 0.0;
    v += (d.w > d.z) ? (o.w - o.z) * clamp((x - d.z) / (d.w - d.z), 0.0, 1.0) : 0.0;
    return max(v, 0.0);
}

static float3 lens26SampleLod(texture2d<half, access::sample> t, sampler s, float2 uv, float lod) {
    float3 c0 = float3(t.sample(s, uv).rgb);
    if (lod <= 0.001) {
        return c0;
    }
    float2 size = float2(t.get_width(), t.get_height());
    float2 p1 = uv * size * 0.5 - 0.5;
    float2 cell = floor(p1);
    float2 f = p1 - cell;
    float2 corner = (2.0 * cell + 1.0) / size;
    float2 step = 2.0 / size;
    float3 m00 = float3(t.sample(s, corner).rgb);
    float3 m10 = float3(t.sample(s, corner + float2(step.x, 0.0)).rgb);
    float3 m01 = float3(t.sample(s, corner + float2(0.0, step.y)).rgb);
    float3 m11 = float3(t.sample(s, corner + step).rgb);
    float3 c1 = mix(mix(m00, m10, f.x), mix(m01, m11, f.x), f.y);
    return mix(c0, c1, clamp(lod, 0.0, 1.0));
}

struct Lens26Frame {
    float2 p;
    float2 uv;
    float2 toUV;
    float2 center;
    float2 halfSize;
    float radius;
    float pt;
    float share;
    float fill;
    float rim;
};

static float3 lens26Back(float2 x, Lens26Frame f, texture2d<half, access::sample> src,
                         texture2d<half, access::sample> blurred, texture2d<half, access::sample> items,
                         sampler smp, constant GlassParams& params) {
    float d = glassSupercircleDistance(x, f.center, f.halfSize, f.radius);
    float cov = clamp(0.5 - d, 0.0, 1.0);
    float3 back = float3(src.sample(smp, f.uv + (x - f.p) * f.toUV).rgb);
    float3 outside = back;
    if (cov < 1.0) {
        float s = glassSupercircleDistance(x - float2(0.0, params.lens26ShadowOffset.x * f.pt), f.center, f.halfSize, f.radius) / f.pt;
        float a = params.lens26AberrationAngle.w * lens26Erfc(s / max(params.lens26Shadow.w, 1e-3)) * f.rim;
        outside = params.lens26Shadow.rgb * a + (1.0 - params.lens26AberrationAngle.z * a) * back;
    }
    if (cov <= 0.0) {
        return outside;
    }
    float2 n0 = nativeGlassNormal(x, f.center, f.halfSize, f.radius, 0.0);
    float disp = params.chainInner.x * f.share * chainFalloff(max(-d, 0.0) / max(params.chainInner.y, 1.0));
    float2 q = x - n0 * disp;
    float dq = max(-glassSupercircleDistance(q, f.center, f.halfSize, f.radius), 0.0);
    float2 nq = nativeGlassNormal(q, f.center, f.halfSize, f.radius, params.chainItems.w);
    float2 r = clamp(q + nq * (params.chainWarp.x * chainFalloff(dq / max(params.chainWarp.y, 1.0))), f.center - f.halfSize, f.center + f.halfSize);
    float2 uvr = f.uv + (r - f.p) * f.toUV;
    float texels = lens26BlurShare((d - disp) / f.pt, params) * params.lens26Blur.x * f.pt;
    float lod = (texels < 2.0) ? log2(1.0 + 0.5 * texels) : log2(texels);
    float3 c = lens26SampleLod(src, smp, uvr, lod);
    float frost = clamp(params.chainInner.z, 0.0, 1.0);
    if (frost > 0.0) {
        c = mix(c, float3(blurred.sample(smp, uvr).rgb), frost);
    }
    float luma = dot(c, float3(0.2126, 0.7152, 0.0722));
    c = (params.lens26.w - params.lens26.z) * luma + params.lens26.z + params.lens26Face.x * (c - luma);
    float dpt = d / f.pt;
    float span = params.lens26Face.w - params.lens26Face.z;
    float hold = (dpt < params.lens26Face.z) ? 1.0 : ((dpt < params.lens26Face.w && span > 0.0) ? 1.0 - (dpt - params.lens26Face.z) / span : 0.0);
    c *= 1.0 - (1.0 - params.lens26Face.y) * hold;
    float2 lensed = x;
    if (params.chainItems.y > 0.0) {
        float2 n1 = nativeGlassNormal(x, f.center, f.halfSize, f.radius, 0.0);
        lensed = x - n1 * (params.chainItems.y * f.share * chainFalloff(max(-d, 0.0) / max(params.lens26Items.x, 1.0)));
    }
    if (params.chainItems.x > 0.0 || params.chainItems.y > 0.0) {
        float d1 = max(-glassSupercircleDistance(lensed, f.center, f.halfSize, f.radius), 0.0);
        float2 n2 = nativeGlassNormal(lensed, f.center, f.halfSize, f.radius, params.chainItems.w);
        float2 i2 = lensed - n2 * (params.chainItems.x * f.share * chainFalloff(d1 / max(params.chainItems.z, 1.0)));
        float4 it = float4(items.sample(smp, f.uv + (i2 - f.p) * f.toUV));
        float fade = max(params.chainInner.w, 0.0);
        if (fade > 0.0) {
            it *= smoothstep(0.3 * fade, fade, max(-d, 0.0));
        }
        c = it.rgb + (1.0 - it.a) * c;
    }
    float inset = glassSupercircleDistance(lensed - float2(0.0, params.lens26Blur.w * f.pt), f.center, f.halfSize, f.radius) / f.pt;
    c *= 1.0 - params.lens26Blur.y * f.rim * lens26Phi(inset / max(params.lens26Blur.z, 1e-3));
    return mix(outside, c, cov);
}

static float3 flexGlow(float3 c, float2 pixelPos, constant GlassParams& params) {
    if (params.flexGlow.x > 0.0) {
        float3 m = float3(dot(params.flexBigRed.xyz, c) + params.flexBigRed.w,
                          dot(params.flexBigGreen.xyz, c) + params.flexBigGreen.w,
                          dot(params.flexBigBlue.xyz, c) + params.flexBigBlue.w);
        c += params.flexGlow.x * (m - c);
    }
    if (params.flexGlow.y > 0.0) {
        float2 d = pixelPos - params.flexGlowCenter.xy;
        float s = max(params.flexGlow.z, 1.0);
        c += params.flexGlow.y * exp(-0.5 * dot(d, d) / (s * s)) * (1.0 - c);
    }
    return c;
}

static float3 lens26Vibrant(float3 c, float4 r, float4 g, float4 b) {
    float3 m = float3(dot(r.xyz, c) + r.w, dot(g.xyz, c) + g.w, dot(b.xyz, c) + b.w);
    return clamp(m, -0.75, 1.0);
}

static half4 lens26Fragment(Lens26Frame f, float d, texture2d<half, access::sample> src,
                            texture2d<half, access::sample> blurred, texture2d<half, access::sample> items,
                            sampler smp, constant GlassParams& params) {
    float pt = f.pt;
    if (d >= 0.5) {
        float s = glassSupercircleDistance(f.p - float2(0.0, params.lens26ShadowOffset.x * pt), f.center, f.halfSize, f.radius) / pt;
        float a = params.lens26AberrationAngle.w * lens26Erfc(s / max(params.lens26Shadow.w, 1e-3)) * f.rim;
        float face = max(params.lens26AberrationAngle.z, 1e-3);
        return half4(half3(params.lens26Shadow.rgb / face), half(clamp(face * a, 0.0, 1.0)));
    }
    float3 comp = lens26Back(f.p, f, src, blurred, items, smp, params);
    float2 n = nativeGlassNormal(f.p, f.center, f.halfSize, f.radius, 0.0);
    float dpt = d / pt;
    float edgeSpan = params.lens26Aberration.w - params.lens26Aberration.z;
    float edge = (edgeSpan != 0.0) ? clamp((dpt - params.lens26Aberration.z) / edgeSpan, 0.0, 1.0) : 0.0;
    float k = edge * clamp(0.5 - d, 0.0, 1.0) * f.rim;
    float3 color = comp;
    if (k > 0.0) {
        float ca = params.lens26AberrationAngle.x;
        float sa = params.lens26AberrationAngle.y;
        float2 a = float2(n.x * ca - n.y * sa, n.x * sa + n.y * ca);
        float amount = (max(-dpt, 0.0) < params.lens26Aberration.y) ? params.lens26Aberration.x : 0.0;
        float2 v = amount * pt * float2(a.y, a.x);
        float3 p1 = lens26Back(f.p + v, f, src, blurred, items, smp, params);
        float3 p2 = lens26Back(f.p + v * (2.0 / 3.0), f, src, blurred, items, smp, params);
        float3 p3 = lens26Back(f.p + v * (1.0 / 3.0), f, src, blurred, items, smp, params);
        float3 m3 = lens26Back(f.p - v * (1.0 / 3.0), f, src, blurred, items, smp, params);
        float3 m2 = lens26Back(f.p - v * (2.0 / 3.0), f, src, blurred, items, smp, params);
        float3 m1 = lens26Back(f.p - v, f, src, blurred, items, smp, params);
        float3 dispersed = float3(
            0.5 * p1.r + (1.0 / 3.0) * p2.r + (1.0 / 6.0) * p3.r,
            (1.0 / 9.0) * p2.g + (2.0 / 9.0) * p3.g + (1.0 / 3.0) * comp.g + (2.0 / 9.0) * m3.g + (1.0 / 9.0) * m2.g,
            (1.0 / 6.0) * m3.b + (1.0 / 3.0) * m2.b + 0.5 * m1.b);
        color = mix(comp, dispersed, k);
    }
    float s = -dpt;
    float fw = max(abs(n.x) + abs(n.y), 1e-4) / pt;
    int lights = int(params.lens26ShadowOffset.y + 0.5);
    float lit = f.rim;
    if (lights > 0) {
        float v = lit * glassLight(s, fw, params.lens26Line.y, params.lens26Key0.z, params.lens26Key0.w, params.lens26Line.x, dot(params.lens26Key0.xy, n));
        color += v * (lens26Vibrant(color, params.lens26Red0, params.lens26Green0, params.lens26Blue0) - color);
    }
    if (lights > 1) {
        float v = lit * glassLight(s, fw, params.lens26Line.w, params.lens26Key1.z, params.lens26Key1.w, params.lens26Line.z, dot(params.lens26Key1.xy, n));
        color += v * (lens26Vibrant(color, params.lens26Red1, params.lens26Green1, params.lens26Blue1) - color);
    }
    color = mix(color, params.lensRim7.rgb, f.fill);
    return half4(half3(clamp(color, 0.0, 1.0)), 1.0h);
}

fragment half4 glassRenderFragment(
    VertexOut in [[stage_in]],
    texture2d<half, access::sample> blurredTexture [[texture(0)]],
    texture2d<half, access::sample> sourceTexture [[texture(1)]],
    texture2d<half, access::sample> itemTexture [[texture(2)]],
    texture2d<half, access::sample> wideBlur [[texture(3)]],
    texture2d<half, access::sample> wideFill [[texture(4)]],
    constant GlassParams& params [[buffer(0)]],
    constant MergeShape* mergeShapes [[buffer(1)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    float2 pixelPos = in.texCoord * params.viewSize;
    float2 center = params.viewSize * 0.5;
    float2 halfSize = center - params.shapePadding;

    float2 scaledPixelPos = pixelPos / params.stretchScale;
    float2 scaledCenter = center / params.stretchScale;

    int mergeCount = int(params.mergeParams.x);
    float mergeK = max(params.mergeParams.y, 0.0001);

    float dist = (mergeCount > 0)
        ? combinedShapeDistance(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, mergeShapes, mergeCount, mergeK)
        : lensShapeDistance(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, params.lensRim5.y, params.lensRim5.w);

    bool outlineOnly = params.shapeEdge.w > 0.5 && mergeCount == 0;
    if (params.lens26.x > 0.5 && params.cornerRadius < 0.0 && mergeCount == 0) {
        float radius = min(halfSize.x, halfSize.y);
        float2 center26 = scaledCenter + params.lens26ShadowOffset.zw / params.stretchScale;
        float d26 = glassSupercircleDistance(scaledPixelPos, center26, halfSize, radius);
        float fill26 = clamp(params.lensRim6.x, 0.0, 1.0);
        Lens26Frame frame = {
            scaledPixelPos, in.texCoord, params.stretchScale / max(params.viewSize, float2(1.0)),
            center26, halfSize, radius, max(params.lens26.y, 0.5),
            clamp(params.shapeEdge.z, 0.0, 1.0) * (1.0 - fill26), fill26,
            (params.lensRim6.y >= 0.0) ? clamp(params.lensRim6.y, 0.0, 1.0) : 1.0 - fill26
        };
        return lens26Fragment(frame, d26, sourceTexture, blurredTexture, itemTexture, textureSampler, params);
    }
    if (params.glassRim.x > 0.0 && params.tintParams.z > 0.5 && params.cornerRadius < 0.0 && mergeCount == 0) {
        dist = glassSupercircleDistance(scaledPixelPos, scaledCenter, halfSize, min(halfSize.x, halfSize.y));
    } else if (params.tintParams.z > 0.0 && mergeCount == 0 && !(params.cornerRadius < 0.0 && params.lensRim5.y > 0.0)) {
        dist += params.tintParams.z * capsuleContinuity(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius);
    }

    half4 color;
    float feather = (params.cornerRadius != 0.0) ? max(params.shapeEdge.y, 0.0) : 0.0;
    float bodyTop = outlineOnly ? 0.0 : params.lensRim5.y;
    float bodyTip = outlineOnly ? 0.0 : params.lensRim5.w;

    if (dist < 0.5 * feather) {
        float nDist = max(-dist, 0.0);
        float bodyNDist = outlineOnly
            ? max(-lensShapeDistance(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, 0.0, 0.0), 0.0)
            : nDist;

        half4 tintColor = half4(params.tint);

        if (params.cornerRadius < 0.0) {
            float2 grad = (mergeCount > 0)
                ? combinedShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, mergeShapes, mergeCount, mergeK)
                : lensShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, bodyTop, bodyTip);
            float2 nrm = (dot(grad, grad) > 1e-6) ? normalize(grad) : float2(0.0, 1.0);
            float up = clamp(0.5 - 0.5 * nrm.y, 0.0, 1.0);
            float sideness = 1.0 - nrm.y * nrm.y;
            float topness = clamp((up - 0.5) * 2.0, 0.0, 1.0);
            float2 rimGrad = outlineOnly
                ? lensShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, params.lensRim5.y, params.lensRim5.w)
                : grad;
            float2 rimNrm = (dot(rimGrad, rimGrad) > 1e-6) ? normalize(rimGrad) : nrm;
            float rimUp = clamp(0.5 - 0.5 * rimNrm.y, 0.0, 1.0);
            float rimSideness = 1.0 - rimNrm.y * rimNrm.y;
            float contourRamp = params.lensRim3.x;
            float topWidth = (contourRamp > 0.0) ? contourRamp : LENS_CONTOUR_PX;
            bool sideRamp = params.lensRim3.y != 0.0;
            float sideWidth = max(topWidth + params.lensRim3.y, 1.0);
            float sideBlend = sqrt(rimSideness);
            float topLineStart = (contourRamp > 0.0) ? max(topWidth - 1.0, LENS_CONTOUR_PX) : topWidth;
            float sideLineStart = (sideRamp || contourRamp > 0.0) ? max(sideWidth - 1.0, LENS_CONTOUR_PX) : sideWidth;
            float lineStart = mix(topLineStart, sideLineStart, sideBlend);
            float band = max(params.edgeWidth, 1.0);
            float x = clamp(bodyNDist / band, 0.0, 1.0);
            float bump = lensBevelProfile(x, params.lensRiseStart, params.lensRiseEnd, params.lensFall.x, params.lensFall.y);
            float lipBand = smoothstep(lineStart - 1.0, lineStart, nDist)
                * clamp(1.0 - (nDist - lineStart - 0.5) / max(params.lensRim2.z, 1.0), 0.0, 1.0);
            float lipFrost = (params.lensRim2.y > 0.0) ? lipBand : 0.0;
            float fill = clamp(params.lensRim6.x, 0.0, 1.0);
            float clear = (params.lensRim6.y >= 0.0) ? clamp(params.lensRim6.y, 0.0, 1.0) : 1.0 - fill;
            float refract = clamp(params.shapeEdge.z, 0.0, 1.0);
            float dispPx = (max(params.mergeParams.w, 0.0) * bump - params.lensRim2.y * lipBand) * clear * refract;
            float mag = max(params.mergeParams.z, 0.25);
            float2 loupeC = scaledCenter + float2(0.0, params.magCenterY);
            float2 toUV = params.stretchScale / max(params.viewSize, float2(1.0));
            float2 base = loupeC + (scaledPixelPos - loupeC) / mag;
            float split = LENS_DISPERSION_SCALE * params.chromaticSpread;
            float2 tangent = float2(-nrm.y, nrm.x);
            float rimDepth = max(params.lensRim6.w, 1.0);
            float rimReach = clamp(bodyNDist / rimDepth, 0.0, 1.0);
            float rimHalf = (params.lensRim6.z > 0.0) ? 0.5 * params.lensRim6.z * (1.0 - rimReach * rimReach * rimReach) * clear * refract : 0.0;
            float2 uvR = in.texCoord + (base + nrm * (dispPx * (1.0 + split)) - tangent * rimHalf - scaledPixelPos) * toUV;
            float2 uvG = in.texCoord + (base + nrm * dispPx - scaledPixelPos) * toUV;
            float2 uvB = in.texCoord + (base + nrm * (dispPx * (1.0 - split)) + tangent * rimHalf - scaledPixelPos) * toUV;
            bool chainOn = params.chainSplit.w > 0.0;
            half4 c;
            float3 chainItem = float3(0.0);
            float3 chainItemAlpha = float3(0.0);
            if (chainOn) {
                float share = refract * clear;
                float2 warpHalf = max(halfSize - float2(max(params.chainWarp.z, 0.0)), float2(1.0));
                float oval = params.chainItems.w;
                float r = params.cornerRadius;
                float nTop = bodyTop;
                float nTip = bodyTip;
                float band = max(params.chainSplit.y, 1.0);
                float fade = max(params.chainSplit.z, 1.0);
                float splitPx = params.chainSplit.x * clamp((band - bodyNDist) / fade, 0.0, 1.0) * share;
                float itemH = max(params.chainItems.z, 1.0);
                float warpH = max(params.chainWarp.y, 1.0);
                float innerH = max(params.chainInner.y, 1.0);
                float warpPx = params.chainWarp.x * ((params.chainWarp.w > 0.5) ? 1.0 : share);
                float frost = clamp(params.chainInner.z, 0.0, 1.0);
                float itemFade = max(params.chainInner.w, 0.0);
                // Taps spread along the rim, red one way and blue the other, each channel weighting those near its wavelength.
                float pointPx = max(params.glassScale.x, 0.5);
                int taps = (splitPx > 0.05) ? LENS_SPECTRUM_TAPS : 1;
                float3 back = float3(0.0);
                float3 weight = float3(0.0);
                float spread = 1.0 / LENS_SPECTRUM_CENTROID;
                for (int k = 0; k < taps; k++) {
                    float t = (taps > 1) ? -1.0 + 2.0 * float(k) / float(taps - 1) : 0.0;
                    float3 w = (taps > 1)
                        ? exp(-pow((float3(t) - float3(-LENS_SPECTRUM_CENTROID, 0.0, LENS_SPECTRUM_CENTROID)) / CHAIN_SPECTRUM_WIDTHS, float3(2.0)))
                        : float3(1.0);
                    float2 q = scaledPixelPos + (tangent * t - nrm * (CHAIN_SPLIT_INWARD * abs(t))) * (splitPx * spread);
                    bool nativeGlass = params.glassRim.x > 0.0;
                    float frameDist = (nativeGlass && params.tintParams.z > 0.5 && r < 0.0 && mergeCount == 0)
                        ? glassSupercircleDistance(q, scaledCenter, warpHalf, min(warpHalf.x, warpHalf.y))
                        : lensShapeDistance(q, scaledCenter, warpHalf, r, nTop, nTip);
                    float dq = max(-frameDist, 0.0);
                    float2 nq = chainNormal(q, scaledCenter, warpHalf, r, nTop, nTip, oval);
                    float2 ng = nativeGlass ? nativeGlassNormal(q, scaledCenter, warpHalf, glassRadius(params, warpHalf), params.glassRim.z) : nq;
                    float innerOff = (nativeGlass && frameDist < 0.0) ? params.chainInner.x * chainFalloff(dq / innerH) * share : 0.0;
                    float2 z = nativeGlass
                        ? q - ng * innerOff
                        : chainWarpPoint(q, scaledCenter, warpHalf, r, nTop, nTip, oval,
                                         params.chainInner.x, innerH, warpPx, warpH, share);
                    float4 it = float4(0.0);
                    if (frameDist < 0.0) {
                        float2 i1 = q - nq * (params.chainItems.y * chainFalloff(dq / itemH) * share);
                        float d1 = chainDepth(i1, scaledCenter, warpHalf, r, nTop, nTip);
                        float2 n2 = chainNormal(i1, scaledCenter, warpHalf, r, nTop, nTip, oval);
                        float2 i2 = i1 - n2 * (params.chainItems.x * chainFalloff(d1 / itemH) * share);
                        it = float4(itemTexture.sample(textureSampler, in.texCoord + (i2 - scaledPixelPos) * toUV));
                        if (itemFade > 0.0) {
                            it *= smoothstep(0.3 * itemFade, itemFade, dq);
                        }
                    }
                    float2 zuv = in.texCoord + (z - scaledPixelPos) * toUV;
                    float3 tap = (params.chainSplit.w > 1.5)
                        ? float3(blurredTexture.sample(textureSampler, zuv).rgb)
                        : float3(sourceTexture.sample(textureSampler, zuv).rgb);
                    if (nativeGlass) {
                        float zDepth = max(dq + innerOff, 0.0);
                        tap = glassFrostTap(tap, zuv, in.texCoord, zDepth, pointPx, blurredTexture, wideBlur, wideFill, textureSampler, params);
                        float outerShare = params.glassOuter.z * clamp((params.glassOuter.w - dq) / max(params.glassOuter.w - params.glassScale.y, 1e-3), 0.0, 1.0);
                        if (outerShare > 0.0 && frameDist < 0.0) {
                            float outerOff = params.glassOuter.x * chainFalloff(dq / max(params.glassOuter.y, 1.0));
                            float2 zo = q + ng * outerOff;
                            float2 zouv = in.texCoord + (zo - scaledPixelPos) * toUV;
                            float3 outer = glassFrostTap(float3(blurredTexture.sample(textureSampler, zouv).rgb), zouv, in.texCoord, dq - outerOff, pointPx, blurredTexture, wideBlur, wideFill, textureSampler, params, false);
                            tap = mix(tap, outer, outerShare);
                        }
                    } else if (frost > 0.0) {
                        constexpr sampler averageSampler(mag_filter::linear, min_filter::linear, mip_filter::linear, address::clamp_to_edge);
                        float3 soft = (params.lensRim7.w > 0.0)
                            ? float3(blurredTexture.sample(averageSampler, zuv, level(params.lensRim7.w)).rgb)
                            : float3(blurredTexture.sample(textureSampler, zuv).rgb);
                        tap = mix(tap, soft, frost);
                    }
                    back += tap * w;
                    chainItem += it.rgb * w;
                    chainItemAlpha += it.a * w;
                    weight += w;
                }
                back /= weight;
                chainItem /= weight;
                chainItemAlpha /= weight;
                c = half4(half3(back), 1.0h);
            } else {
                half4 sharp;
                if (split * dispPx > 0.05 || rimHalf > 0.05) {
                    // A continuous spectrum over the split, so the fringes grade instead of splitting into three copies.
                    float3 sum = float3(0.0);
                    float3 weight = float3(0.0);
                    float spread = 1.0 / LENS_SPECTRUM_CENTROID;
                    for (int k = 0; k < LENS_SPECTRUM_TAPS; k++) {
                        float t = -1.0 + 2.0 * float(k) / float(LENS_SPECTRUM_TAPS - 1);
                        float2 uv = in.texCoord + (base + nrm * (dispPx * (1.0 - split * spread * t)) + tangent * (rimHalf * spread * t) - scaledPixelPos) * toUV;
                        float3 w = exp(-pow((float3(t) - float3(-LENS_SPECTRUM_CENTROID, 0.0, LENS_SPECTRUM_CENTROID)) / LENS_SPECTRUM_WIDTH, float3(2.0)));
                        sum += float3(sourceTexture.sample(textureSampler, uv).rgb) * w;
                        weight += w;
                    }
                    sharp = half4(half3(sum / weight), 1.0h);
                } else {
                    sharp = half4(sourceTexture.sample(textureSampler, uvG).rgb, 1.0h);
                }
                half4 soft;
                if (params.lensRim7.w > 0.0) {
                    constexpr sampler averageSampler(mag_filter::linear, min_filter::linear, mip_filter::linear, address::clamp_to_edge);
                    float interiorLevel = params.lensRim7.w;
                    float bandLevel = max(interiorLevel - 1.0, 0.0);
                    float softLevel = mix(interiorLevel, bandLevel, bump);
                    soft = half4(blurredTexture.sample(averageSampler, uvR, level(softLevel)).r,
                                 blurredTexture.sample(averageSampler, uvG, level(softLevel)).g,
                                 blurredTexture.sample(averageSampler, uvB, level(softLevel)).b, 1.0h);
                } else {
                    soft = half4(blurredTexture.sample(textureSampler, uvR).r,
                                 blurredTexture.sample(textureSampler, uvG).g,
                                 blurredTexture.sample(textureSampler, uvB).b, 1.0h);
                }
                float interiorFrost = (1.0 - clamp(params.interiorSharpness, 0.0, 1.0)) * (1.0 - bump);
                c = mix(sharp, soft, half(clamp((interiorFrost + params.lensFrost * bump + lipFrost) * clear, 0.0, 1.0)));
            }
            float3 body = (params.glassRim.x > 0.0) ? glassFace(float3(c.rgb), params) : applyBodyUnclamped(c.rgb, params);
            if (params.glassRim.x > 0.0) {
                float rimD = dist + params.chainWarp.z;
                float3 back = float3(sourceTexture.sample(textureSampler, in.texCoord).rgb);
                float3 halfBack = (rimD > -1.0 && rimD < 3.0 * params.glassScale.x) ? glassHalfResBackdrop(sourceTexture, in.texCoord) : back;
                color = glassRimComposite(body, tintColor, params, rimD, nrm, scaledPixelPos, scaledCenter, halfSize,
                                          back, halfBack, mergeShapes, mergeCount, mergeK);
            } else {
                if (tintColor.a > 0.001h) {
                    body = tintComposite(body, tintColor, params, params.tintWeights.x);
                }
                if (chainOn) {
                    body = chainItem + (1.0 - chainItemAlpha) * body;
                }
                float fillBelow = (params.lensRim6.y >= 0.0) ? 0.0 : fill;
                body = mix(body, params.lensRim7.rgb, fillBelow);
                float shadeReachTop = max(params.lensFall.w, 1.0);
                float shadeReachSide = (params.lensRim3.z > 0.0) ? params.lensRim3.z : shadeReachTop;
                float sideOnsetStart = min(LENS_CONTOUR_PX, max(params.lensRim.z - 1.0, 0.0));
                float sideShoulder = (params.lensRim4.x >= 0.0) ? params.lensRim4.x : params.lensRim3.w;
                float shade;
                float floorWeight;
                float floorFall;
                if (params.lensRim4.y > 0.0) {
                    float tilt = params.lensRim4.y * (M_PI_F / 180.0);
                    float2 sideAxis = float2((nrm.x >= 0.0) ? cos(tilt) : -cos(tilt), sin(tilt));
                    float sideLobe = pow(max(dot(nrm, sideAxis), 0.0), params.lensRim9.z);
                    float topLobe = pow(clamp((params.lensRim8.w - nrm.y) / (1.0 + params.lensRim8.w), 0.0, 1.0), params.lensRim9.y);
                    float humpOnsetEnd = max(mix(params.lensRim.w, params.lensRim9.x * params.lensRim.w, sideness), LENS_CONTOUR_PX + 3.0);
                    float humpIn = smoothstep(LENS_CONTOUR_PX + 2.0, humpOnsetEnd, bodyNDist);
                    float humpFall = lensShadeFall(bodyNDist, shadeReachTop, params.lensRim3.w);
                    float sideStart = (params.lensRim4.w > 0.0) ? params.lensRim.z - params.lensRim4.w : sideOnsetStart;
                    float sideIn = smoothstep(sideStart, max(params.lensRim.z, sideStart + 1.0), bodyNDist);
                    float lowerReach = mix(0.5 * shadeReachSide, shadeReachSide, clamp(up * 2.0, 0.0, 1.0));
                    float sideFall = lensShadeFall(bodyNDist, lowerReach, sideShoulder);
                    float hump = params.lensFall.z * topLobe * humpIn * humpFall;
                    float sideShade = params.lensFall.z * params.lensRim.y * sideLobe * sideIn * sideFall;
                    shade = hump + sideShade;
                    floorWeight = topLobe;
                    floorFall = humpFall;
                } else {
                    float shadeReach = (up >= 0.5 || params.lensRim3.z <= 0.0)
                        ? mix(shadeReachSide, shadeReachTop, topness)
                        : mix(0.25 * shadeReachSide, shadeReachSide, clamp(up * 2.0, 0.0, 1.0));
                    float onsetStart = mix(LENS_CONTOUR_PX + 2.0, sideOnsetStart, sideness);
                    float onsetEnd = max(mix(params.lensRim.w, params.lensRim.z, sideness), onsetStart + 1.0);
                    float shadeIn = smoothstep(onsetStart, onsetEnd, bodyNDist);
                    float sideWeight = mix(params.lensRim.y / 0.70710678, 1.0, topness);
                    float shoulder = (up >= 0.5) ? mix(sideShoulder, params.lensRim3.w, topness) : sideShoulder * clamp(up * 2.0, 0.0, 1.0);
                    float shadeFall = lensShadeFall(bodyNDist, shadeReach, shoulder);
                    shade = params.lensFall.z * sqrt(up) * sideWeight * shadeIn * shadeFall;
                    floorWeight = sqrt(up) * sideWeight;
                    floorFall = shadeFall;
                }
                float floorStart = lineStart + ((contourRamp > 0.0 || sideRamp) ? max(params.lensLight.z, 0.5) + 0.2 : 0.0);
                float shadeFloor = params.lensRim2.x * floorWeight * smoothstep(floorStart, floorStart + 2.0, nDist) * floorFall;
                float shadeAmount = clamp(max(shade, shadeFloor), 0.0, 1.0) * clear;
                body *= 1.0 - shadeAmount * (chainOn ? (1.0 - chainItemAlpha) : float3(1.0));
                float contourTop = (contourRamp > 0.0)
                    ? clamp(1.0 - nDist / topWidth, 0.0, 1.0)
                    : 1.0 - smoothstep(topWidth - 0.5, topWidth + 0.5, nDist);
                float contourSide = (sideRamp || contourRamp > 0.0)
                    ? clamp(1.0 - nDist / sideWidth, 0.0, 1.0)
                    : contourTop;
                float contour = mix(contourTop, contourSide, sideBlend);
                float contourAmount = clamp(params.lensContour * mix(1.0, params.lensRim.x, rimSideness), 0.0, 1.0) * clear;
                float bodyLum = max(dot(body, float3(0.2126, 0.7152, 0.0722)), 1e-3);
                float contourAbs = contour * contourAmount * mix(bodyLum, 1.0, clamp(params.lensRim5.z, 0.0, 1.0));
                float3 contourMul = body * max(1.0 - contourAbs / bodyLum, 0.0);
                float3 contourSub = body - contourAbs;
                body = max(mix(contourMul, contourSub, clamp(params.lensRim5.x, 0.0, 1.0)), 0.0);
                body = mix(body, params.lensRim7.rgb, fill - fillBelow);
                float lobe = pow(rimNrm.y * rimNrm.y, (params.lensRim4.z > 0.0) ? params.lensRim4.z : 4.0);
                float strength = params.lensLight.x
                    * mix(params.lensLight.y, 1.0, lobe)
                    * mix(params.tintParams.w, 1.0, rimUp);
                float lineWidth = max(params.lensLight.z, 0.5);
                float lineFade = max(params.lensLight.w, 0.5);
                float lineSplit = LENS_HIGHLIGHT_SPLIT_PX * clamp(params.chromaticSpread / 10.0, 0.0, 1.0);
                float3 lineOffsets = float3(lineSplit, 0.0, -lineSplit);
                float3 highlight;
                for (int channel = 0; channel < 3; channel++) {
                    float d = nDist + lineOffsets[channel];
                    float lineIn = smoothstep(lineStart - 0.5, lineStart + 0.5, d);
                    float lineOut = 1.0 - smoothstep(lineStart + lineWidth, lineStart + lineWidth + lineFade, d);
                    highlight[channel] = lineIn * lineOut;
                }
                float tail = params.lensRim2.w * ((params.lensRim4.z > 0.0) ? rimNrm.y * rimNrm.y : 1.0)
                    * exp(-max(nDist - (lineStart + lineWidth), 0.0) / LENS_HIGHLIGHT_TAIL_PX);
                float3 lineTint = mix(float3(1.0), LENS_HIGHLIGHT_TINT, clamp(params.chromaticSpread / 10.0, 0.0, 1.0));
                float3 line = lineTint * (highlight * strength + float3(tail)) * clear * (1.0 - contour);
                c.rgb = (params.lensRim9.w > 0.0)
                    ? half3(clamp(linearToSrgb(srgbToLinear(clamp(body, 0.0, 1.0)) + line), 0.0, 1.0))
                    : half3(clamp(body + line, 0.0, 1.0));
                color = c;
            }
        } else if (nDist >= params.edgeWidth) {
            float mag = max(params.mergeParams.z, 1.0);
            float2 magC = float2(0.5, 0.5 + params.magCenterY / params.viewSize.y);
            float2 baseUV = (in.texCoord - magC) / mag + magC;
            // The interior must sample the blurred backdrop, or blur.radius is a no-op.
            color = blurredTexture.sample(textureSampler, baseUV);
            if (params.lensRim7.w > 0.0) {
                constexpr sampler averageSampler(
                    mag_filter::linear,
                    min_filter::linear,
                    mip_filter::linear,
                    address::clamp_to_edge
                );
                color = blurredTexture.sample(averageSampler, baseUV, level(params.lensRim7.w));
            }
            if (params.interiorSharpness > 0.001) {
                // Lateral chromatic aberration of the magnified content: R and B separate radially about the loupe axis.
                half4 sharpColor;
                float caAmt = CHROMATIC_SPREAD * params.chromaticSpread;
                if (caAmt > 0.0001) {
                    float2 field = in.texCoord - float2(0.5, 0.5);
                    float2 caOffset = field * length(field) * (caAmt * 1.0);
                    sharpColor.r = sourceTexture.sample(textureSampler, baseUV + caOffset).r;
                    sharpColor.g = sourceTexture.sample(textureSampler, baseUV).g;
                    sharpColor.b = sourceTexture.sample(textureSampler, baseUV - caOffset).b;
                    sharpColor.a = 1.0h;
                } else {
                    sharpColor = sourceTexture.sample(textureSampler, baseUV);
                }
                color = mix(color, sharpColor, half(clamp(params.interiorSharpness, 0.0, 1.0)));
            }

            color.rgb = applyBody(color.rgb, params);

            if (tintColor.a > 0.001h) {
                color = tintOver(color, tintColor, params, params.tintWeights.x);
            }

            float iridescence = params.tintWeights.w;
            if (iridescence > 0.001) {
                float2 g = (mergeCount > 0)
                    ? combinedShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, mergeShapes, mergeCount, mergeK)
                    : lensShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, params.lensRim5.y, params.lensRim5.w);
                if (dot(g, g) > 0.0001) {
                    float2 filmDir = normalize(g) * (params.edgeWidth * 0.35) / params.viewSize;
                    half3 smear;
                    smear.r = sourceTexture.sample(textureSampler, baseUV + filmDir * 0.55).r;
                    smear.g = sourceTexture.sample(textureSampler, baseUV + filmDir * 1.0).g;
                    smear.b = sourceTexture.sample(textureSampler, baseUV + filmDir * 1.45).b;
                    float smearLum = dot(float3(smear), float3(0.299, 0.587, 0.114));
                    // Fringe mask from the raw smear, before the desaturation: dispersion shows only where the channels diverge.
                    float smearMaxI = max(max(float(smear.r), float(smear.g)), float(smear.b));
                    float smearMinI = min(min(float(smear.r), float(smear.g)), float(smear.b));
                    float fringeMaskI = clamp((smearMaxI - smearMinI) / max(smearMaxI, 0.02) * 2.0, 0.0, 1.0);
                    smear = mix(half3(half(smearLum)), smear, 0.55h);
                    // 0.1 keeps offset glyph copies below visibility; the mask cannot save thin strokes.
                    float gain = iridescence * 0.1 * smoothstep(0.18, 0.6, smearLum) * fringeMaskI;
                    color.rgb += (half3(1.0h) - color.rgb) * smear * half(clamp(gain, 0.0, 1.0));
                }
            }
        } else {
            float2 shapeGrad = (mergeCount > 0)
                ? combinedShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, mergeShapes, mergeCount, mergeK)
                : lensShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, params.lensRim5.y, params.lensRim5.w);
            float2 normal = shapeGrad;

            // Bevel height h(x) = T (1 - (1 - x)^4)^(1/4); Snell on its slope gives
            // displacement = h(x) * tan(phi - asin(sin phi / eta)) outward, in scaled px.
            float bevelW = max(params.edgeWidth, 1.0);
            float xNorm = clamp(nDist / bevelW, 0.0, 1.0);   // 0 at the rim, 1 at the interior
            float u = 1.0 - xNorm;
            float u4 = (u * u) * (u * u);
            float thickness = max(params.mergeParams.w, bevelW);
            float hgt = thickness * pow(max(1.0 - u4, 0.0), 0.25);
            float slope = (thickness / bevelW) * (u * u * u) / pow(max(1.0 - u4, 1e-4), 0.75);
            float phi = atan(slope);
            float sinPhi = sin(phi);
            float sinThetaT = clamp(sinPhi / max(params.iorFactor, 1.001), -1.0, 1.0);
            float dispPx = hgt * tan(phi - asin(sinThetaT));
            float bevelPresence = smoothstep(0.005, 0.03, sinPhi);

            float2 viewDir = float2(0.0, 1.0);  // Top-down view
            float rim = rimIntensity(normal, viewDir);
            float rimEdgeFactor = 1.0 - (nDist / params.edgeWidth);
            // Lifted toward uniform: the ring samples the dark exterior and would otherwise read as dome shading.
            rim = mix(rim, 1.0, 0.85) * pow(rimEdgeFactor, 5.0) * params.rimGlow;

            float specGeoFactor = pow(max(sinPhi, 0.0), 1.0 + params.specularFocus * 2.0);

            float2 filmRefractionOffset = float2(0.0);

            if (params.mirrorMode > 0.5) {
                float halfThickness = params.edgeWidth * 0.5;

                if (nDist < halfThickness) {
                    float2 direction = normalize(normal);

                    float t = nDist / halfThickness;
                    float curvedT = sin(t * PI / 2.0);

                    float pixelOffset = params.edgeWidth - 2.0 * curvedT * halfThickness;
                    float2 mirrorOffset = -direction * pixelOffset / params.viewSize * params.iorFactor;

                    color = sampleWithAberration(
                        blurredTexture,
                        textureSampler,
                        in.texCoord,
                        mirrorOffset,
                        params.chromaticSpread
                    );

                } else {
                    color = blurredTexture.sample(textureSampler, in.texCoord);
                }

            } else {
                // Samples outward; the reach is clamped to the shape.padding apron so taps stay inside the drawable.
                float maxReachPx = max(min(params.shapePadding.x, params.shapePadding.y) - 2.0, 0.0);
                float reach = min(dispPx, maxReachPx);
                float2 uvOffset = normalize(normal) * reach / params.viewSize;

                // The loupe pull fades out across the bevel, handing off to the magnified interior and the exterior.
                float magE = max(params.mergeParams.z, 1.0);
                float2 magCE = float2(0.5, 0.5 + params.magCenterY / params.viewSize.y);
                float2 magBaseUV = (in.texCoord - magCE) / magE + magCE;
                // 1 - (1 - x)^2 holds the pull through the ring and releases it at the rim, so the fold lands on the outermost band.
                float pullFade = 1.0 - (1.0 - xNorm) * (1.0 - xNorm);
                float2 loupePull = (magBaseUV - in.texCoord) * pullFade;
                float2 ringBaseUV = in.texCoord + loupePull;
                filmRefractionOffset = loupePull + uvOffset;

                half4 refractedColor = sampleWithAberration(
                    blurredTexture,
                    textureSampler,
                    ringBaseUV,
                    uvOffset,
                    params.chromaticSpread
                );

                half4 sourceColor = sourceTexture.sample(textureSampler, ringBaseUV);

                // Sub-pixel displacements pass the source through, so the bevel-interior handoff has no seam.
                float blendFactor = smoothstep(0.5, 2.0, reach);
                color = mix(sourceColor, refractedColor, half(blendFactor));
            }

            color.rgb = applyBody(color.rgb, params);

            if (tintColor.a > 0.001h) {
                color = tintOver(color, tintColor, params, params.tintWeights.x);
            }

            float effectStrength = bevelPresence;
            bool applyEffects = (effectStrength > 0.001) || (params.mirrorMode > 0.5);

            if (applyEffects) {
                float scaledEffectStrength = (params.mirrorMode > 0.5) ? 1.0 : effectStrength;

                color = tintOver(color, tintColor, params, params.tintWeights.y * scaledEffectStrength);

                float highlightW = params.tintWeights.z * float(tintColor.a);

                float iridescence = params.tintWeights.w;
                if (iridescence > 0.001) {
                    // 0.35 of the band keeps the three channel taps hugging the strokes.
                    float2 smearDir = normalize(normal) * (params.edgeWidth * 0.35) / params.viewSize;
                    // Smear the refracted content, not the unwarped backdrop: that pastes a legible copy of the page onto the ring.
                    float2 filmUV = in.texCoord + filmRefractionOffset;
                    half3 smear;
                    smear.r = blurredTexture.sample(textureSampler, filmUV + smearDir * 0.55).r;
                    smear.g = blurredTexture.sample(textureSampler, filmUV + smearDir * 1.0).g;
                    smear.b = blurredTexture.sample(textureSampler, filmUV + smearDir * 1.45).b;
                    float smearLum = dot(float3(smear), float3(0.299, 0.587, 0.114));
                    // Fringe mask from the raw smear, before the desaturation: dispersion shows only where the channels diverge.
                    float smearMax = max(max(float(smear.r), float(smear.g)), float(smear.b));
                    float smearMin = min(min(float(smear.r), float(smear.g)), float(smear.b));
                    float fringeMask = clamp((smearMax - smearMin) / max(smearMax, 0.02) * 2.0, 0.0, 1.0);
                    smear = mix(half3(half(smearLum)), smear, 0.55h);
                    float gain = iridescence * rimEdgeFactor * 0.8
                        * scaledEffectStrength
                        * smoothstep(0.18, 0.6, smearLum)
                        * fringeMask;
                    color.rgb += (half3(1.0h) - color.rgb) * smear * half(clamp(gain, 0.0, 1.0));
                }

                half rimHighlight = half(rim * scaledEffectStrength * 0.6);
                half3 rimTarget = half3(1.0h);
                if (highlightW > 0.001) {
                    rimTarget = okRecolor(rimTarget, tintColor.rgb, highlightW);
                }
                color.rgb = mix(color.rgb, rimTarget, rimHighlight);

                float specular = edgeReflection(normal, viewDir);

                specular *= specGeoFactor * params.specularIntensity;

                float lightDot = dot(normalize(normal), normalize(LIGHT_VECTOR));
                bool isFarside = lightDot < 0.0;

                if (isFarside) {
                    specular *= params.oppositeFalloff;
                }

                half4 specularColor = isFarside ? half4(params.farSpecularColor) : half4(params.nearSpecularColor);
                if (highlightW > 0.001) {
                    specularColor.rgb = okRecolor(specularColor.rgb, tintColor.rgb, highlightW);
                }
                if (specularColor.a > 0.001h) {
                    color = mix(color, specularColor, half(specular * scaledEffectStrength));
                }
            }
        }
    } else {
        color = blurredTexture.sample(textureSampler, in.texCoord);
    }

    if (params.cornerRadius > 0.0 && dist >= -INNER_VIGNETTE_SPREAD && dist < 0.0) {
        float2 vignetteGrad = (mergeCount > 0)
            ? combinedShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, mergeShapes, mergeCount, mergeK)
            : lensShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, params.lensRim5.y, params.lensRim5.w);
        float vignetteDir = clamp(pow(max(0.0, dot(vignetteGrad, normalize(INNER_VIGNETTE_BIAS))), GLOW_FOCUS), 0.0, 1.0);
        float vignetteFactor = (1.0 - smoothstep(0.0, INNER_VIGNETTE_SPREAD * INNER_VIGNETTE_FALLOFF, -dist)) * INNER_VIGNETTE_STRENGTH * vignetteDir;
        if (vignetteFactor > 0.001) {
            color.rgb = mix(color.rgb, half3(GLOW_TINT), half(vignetteFactor));
        }
    }

    if ((params.flexGlow.x > 0.0 || params.flexGlow.y > 0.0) && (params.cornerRadius == 0.0 || dist < 0.5 * feather)) {
        color.rgb = half3(flexGlow(float3(color.rgb), pixelPos, params));
    }

    if (params.cornerRadius != 0.0) {
        if (dist < 0.5 * feather) {
            if (feather > 0.0) {
                color.a *= half(clamp(0.5 - dist / feather, 0.0, 1.0));
            }
        } else if (params.glassRim.x > 0.0) {
            float dropD = glassFrameDistance(scaledPixelPos - float2(0.0, params.glassShadow.w), scaledCenter, halfSize, params, mergeShapes, mergeCount, mergeK);
            float shade = glassDropShadow(dropD, params.glassShadow.z, params.glassShadow.y);
            color = half4(0.0h, 0.0h, 0.0h, half(shade));
        } else if (params.cornerRadius < 0.0 && params.lensRim8.x > 0.0) {
            float offset = params.lensRim8.y;
            float radius = max(params.lensRim8.z, 1.0);
            float shiftedDist = lensShapeDistance(scaledPixelPos - float2(0.0, offset), scaledCenter, halfSize, params.cornerRadius, params.lensRim5.y, params.lensRim5.w);
            float shade = params.lensRim8.x * exp(-0.5 * (shiftedDist * shiftedDist) / (radius * radius));
            if (shade > 0.001) {
                color.rgb = half3(GLOW_TINT);
                color.a = half(shade);
            } else {
                color.a = 0.0;
            }
        } else if (dist < ((params.cornerRadius < 0.0) ? LENS_SHADOW_SPREAD : OUTER_GLOW_SPREAD)) {
            bool isLens = params.cornerRadius < 0.0;
            float glowSpread = isLens ? LENS_SHADOW_SPREAD : OUTER_GLOW_SPREAD;
            float glowStrength = (params.shapeEdge.x >= 0.0) ? params.shapeEdge.x : (isLens ? LENS_SHADOW_STRENGTH : OUTER_GLOW_STRENGTH);
            float2 grad = (mergeCount > 0)
                ? combinedShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, mergeShapes, mergeCount, mergeK)
                : lensShapeGradient(scaledPixelPos, scaledCenter, halfSize, params.cornerRadius, params.lensRim5.y, params.lensRim5.w);

            float2 glowDir = normalize(GLOW_BIAS);
            float dirFactor = dot(grad, glowDir);
            dirFactor = clamp(pow(max(0.0, dirFactor), GLOW_FOCUS), 0.0, 1.0);

            float glowFactor = 1.0 - smoothstep(0.0, glowSpread * OUTER_GLOW_FALLOFF, dist);
            glowFactor *= glowStrength * dirFactor;

            if (glowFactor > 0.001) {
                color.rgb = half3(GLOW_TINT);
                color.a = half(glowFactor);
            } else {
                color.a = 0.0;
            }
        } else {
            color.a = 0.0;
        }
    }

    color.a *= half(params.opacity);

    return color;
}

