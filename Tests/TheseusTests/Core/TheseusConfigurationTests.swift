import XCTest
@testable import Theseus

final class TheseusConfigurationTests: XCTestCase {

    // MARK: - Default Values

    func testDefaultValues() {
        let config = TheseusConfiguration()
        XCTAssertEqual(config.blur.radius, 1.0)
        XCTAssertEqual(config.shape.cornerRadius, 18.0)
        XCTAssertEqual(config.opacity, 1.0)
        XCTAssertEqual(config.lensFill, 0)
        XCTAssertEqual(config.lensFillColor, .white)
        XCTAssertEqual(config.lensRimScale, -1)
        XCTAssertEqual(config.refraction.intensity, 1.45)
        XCTAssertEqual(config.refraction.edgeWidth, 15.0)
        XCTAssertEqual(config.refraction.thickness, 45.0)
        XCTAssertEqual(config.refraction.interiorSharpness, 0.0)
        XCTAssertEqual(config.refraction.interiorAverage, 0.0)
        XCTAssertEqual(config.refraction.magnificationCenterY, 0.0)
        XCTAssertEqual(config.edgeEffects.rimGlow, 0.5)
        XCTAssertEqual(config.edgeEffects.glareIntensity, 1.0)
        XCTAssertEqual(config.morph.scale.x, 1.0)
        XCTAssertEqual(config.morph.scale.y, 1.0)
        XCTAssertEqual(config.morph.tension, 0.18)
        XCTAssertEqual(config.morph.friction, 0.88)
        XCTAssertEqual(config.captureMethod, .surfaceBased)
        XCTAssertNil(config.blur.sigma)
        XCTAssertNil(config.quality)
    }

    // MARK: - Computed Properties

    func testEffectiveSigma() {
        var config = TheseusConfiguration()
        config.blur.radius = 9.0
        // effectiveSigma = radius * 0.3
        XCTAssertEqual(config.effectiveSigma, 9.0 * 0.3, accuracy: 0.0001)

        // Override takes precedence
        config.blur.sigma = 5.0
        XCTAssertEqual(config.effectiveSigma, 5.0)
    }

    // `capturePadding` is a deprecated no-op; its maths stays pinned as public API.
    @available(*, deprecated)
    func testEffectiveCapturePadding() {
        var config = TheseusConfiguration()
        XCTAssertNil(config.capturePadding)
        config.blur.radius = 10.0
        config.shape.padding = CGPoint(x: 2, y: 3)
        // defaultPadding = blur.radius * 1.2 = 12.0
        // result = (12.0 + 2, 12.0 + 3) = (14, 15)
        var padding = config.effectiveCapturePadding
        XCTAssertEqual(padding.x, 14.0)
        XCTAssertEqual(padding.y, 15.0)

        // Override takes precedence
        config.capturePadding = CGPoint(x: 5, y: 6)
        // result = (5 + 2, 6 + 3) = (7, 9)
        padding = config.effectiveCapturePadding
        XCTAssertEqual(padding.x, 7.0)
        XCTAssertEqual(padding.y, 9.0)
    }

    // MARK: - Glass Presets and Tint (iOS 27 parity API)

    func testRegularPresetDrawsNativeGlass() {
        let regular = TheseusConfiguration.regular
        let defaults = TheseusConfiguration()
        XCTAssertEqual(regular.opacity, defaults.opacity)
        XCTAssertEqual(regular.refraction.intensity, defaults.refraction.intensity)
        XCTAssertEqual(regular.theme.tintColor, defaults.theme.tintColor)
        XCTAssertEqual(regular.lensChain, .glass)
        XCTAssertEqual(regular.glassRim, .regular)
        XCTAssertEqual(regular.shape.widthInset, -0.8)
        XCTAssertGreaterThanOrEqual(regular.shape.padding.y, TheseusConfiguration.nativeGlassPadding.y)
        XCTAssertNil(defaults.glassRim)
    }

    func testNativeGlassKeepsALargerPadding() {
        var config = TheseusConfiguration()
        config.shape.padding = CGPoint(x: 24, y: 30)
        config.drawsAsNativeGlass(chain: .glass, rim: .regular)
        XCTAssertEqual(config.shape.padding, CGPoint(x: 24, y: 30))
    }

    func testNativeDropShadowBlurGrowsPastA64PointSide() {
        typealias Rim = TheseusConfiguration.GlassRim
        XCTAssertEqual(Rim.dropShadowSigma(shortSide: 30), 0.699 * 4, accuracy: 1e-9)
        XCTAssertEqual(Rim.dropShadowSigma(shortSide: 70), 0.699 * 5.25, accuracy: 1e-9)
        XCTAssertEqual(Rim.dropShadowSigma(shortSide: 100), 0.699 * 11.5, accuracy: 1e-9)
        XCTAssertEqual(Rim.dropShadowSigma(shortSide: 400), 0.699 * 24, accuracy: 1e-9)
    }

    func testClearPresetIsMoreTransparentThanRegular() {
        let clear = TheseusConfiguration.clear
        let regular = TheseusConfiguration.regular
        XCTAssertEqual(clear.opacity, 1)
        XCTAssertGreaterThan(clear.glassRim!.detailSigma(tintAmount: 0.5), regular.glassRim!.detailSigma(tintAmount: 0.5))
        XCTAssertEqual(clear.glassRim!.detailSigma(tintAmount: 0), TheseusConfiguration.GlassRim.blurSoftness)
        XCTAssertEqual(clear.lensChain?.frost, 0)
        XCTAssertEqual(clear.glassRim, .clear)
        XCTAssertEqual(clear.glassRim?.dropShadowAmount(isDark: false, shortSide: 70), 0)
        XCTAssertLessThan(clear.refraction.intensity, regular.refraction.intensity)
        XCTAssertEqual(clear.theme.neutralBodyScale, 0.0)
        XCTAssertEqual(clear.theme.luminanceLift, 31.0 / 255.0)
        XCTAssertEqual(clear.theme.backdropGain, 0.95)
        XCTAssertEqual(clear.theme.backdropSaturation, 1.11)
    }

    func testTintSetsColorAndIntensity() {
        let config = TheseusConfiguration.regular.tint(.systemBlue, intensity: 0.5)
        XCTAssertEqual(config.theme.tintColor, .systemBlue)
        XCTAssertEqual(config.theme.tintOpacity, 0.5)
    }

    func testTintDefaultsToFullIntensity() {
        let config = TheseusConfiguration.regular.tint(.systemRed)
        XCTAssertEqual(config.theme.tintOpacity, 1.0)
    }

    func testTintNilClearsColor() {
        let config = TheseusConfiguration.regular
            .tint(.systemBlue, intensity: 0.5)
            .tint(nil)
        XCTAssertEqual(config.theme.tintColor, .clear)
    }

    func testTintClampsIntensity() {
        XCTAssertEqual(TheseusConfiguration.regular.tint(.red, intensity: 2.0).theme.tintOpacity, 1.0)
        XCTAssertEqual(TheseusConfiguration.regular.tint(.red, intensity: -1.0).theme.tintOpacity, 0.0)
    }

    func testTintDoesNotMutateOtherSettings() {
        var base = TheseusConfiguration()
        base.blur.radius = 7.0
        base.shape.cornerRadius = 33.0
        let tinted = base.tint(.systemGreen, intensity: 0.4)
        XCTAssertEqual(tinted.blur.radius, 7.0)
        XCTAssertEqual(tinted.shape.cornerRadius, 33.0)
    }

    // MARK: - Tint Weights (uniforms for calibration)

    func testTintWeightDefaultsMatchReference() {
        let theme = TheseusTheme()
        XCTAssertEqual(theme.surfaceTintWeight, 1.0)
        XCTAssertEqual(theme.luminanceLift, 0.0)
        XCTAssertEqual(theme.edgeTintWeight, 0.0)
        XCTAssertEqual(theme.highlightTintPreservation, 0.5)
        XCTAssertEqual(theme.edgeIridescence, 0.0)
        XCTAssertEqual(theme.backdropSaturation, 1.0)
        XCTAssertEqual(theme.backdropGain, 1.0)
    }

    // MARK: - Lens Preset (reference lens material)

    func testLensPresetIsClearMagnifier() {
        let lens = TheseusConfiguration.lens
        XCTAssertEqual(lens.blur.radius, 2.0)
        XCTAssertEqual(lens.refraction.edgeWidth, 8.0)
        XCTAssertEqual(lens.refraction.intensity, 1.1)
        XCTAssertEqual(lens.refraction.dispersion, 1.9)
        XCTAssertEqual(lens.refraction.magnification, 1.2)
        XCTAssertEqual(lens.refraction.thickness, 24.0)
        XCTAssertEqual(lens.refraction.interiorSharpness, 1.0)
        XCTAssertEqual(lens.edgeEffects.rimGlow, 0.25)
        XCTAssertEqual(lens.edgeEffects.glareIntensity, 0.12)
        var farWhite: CGFloat = 0, farAlpha: CGFloat = 0
        lens.edgeEffects.farColor.getWhite(&farWhite, alpha: &farAlpha)
        XCTAssertEqual(farWhite, 1.0)
        XCTAssertEqual(farAlpha, 0.5, accuracy: 0.0001)
        XCTAssertEqual(lens.edgeEffects.oppositeFalloff, 0.85)
        XCTAssertEqual(lens.edgeEffects.glareFocus, 0.15)
        XCTAssertEqual(lens.theme.neutralBodyScale, 0.0)
        XCTAssertEqual(lens.theme.edgeIridescence, 0.0)
    }

    // MARK: - Shape Merging

    func testMergedShapesDefaultEmpty() {
        let shape = TheseusShape()
        XCTAssertTrue(shape.mergedShapes.isEmpty)
        XCTAssertEqual(shape.mergeSmoothing, 12.0)
    }

    func testMergedShapeStoresFrameAndRadius() {
        let merged = TheseusMergedShape(
            frame: CGRect(x: 10, y: 20, width: 100, height: 50),
            cornerRadius: 25
        )
        var shape = TheseusShape()
        shape.mergedShapes = [merged]
        XCTAssertEqual(shape.mergedShapes[0].frame.midX, 60)
        XCTAssertEqual(shape.mergedShapes[0].cornerRadius, 25)
    }

    // MARK: - Shader Struct Layout (must match TheseusShaders.metal)

    func testGlassParamsLayoutMatchesShader() {
        // 1152 = sizeof(GlassParams) in TheseusShaders.metal.
        XCTAssertEqual(MemoryLayout<GlassParams>.size, 1152)
        XCTAssertEqual(MemoryLayout<GlassParams>.stride, 1152)
    }

    func testMergeShapeParamsLayoutMatchesShader() {
        // 32 = sizeof(MergeShape) in TheseusShaders.metal; the shader indexes a fixed array of 8.
        XCTAssertEqual(MemoryLayout<MergeShapeParams>.size, 32)
        XCTAssertEqual(MemoryLayout<MergeShapeParams>.stride, 32)
        XCTAssertEqual(MergeShapeLimits.maxShapes, 8)
    }

    func testLensConfigurationsKeepNearClearBody() {
        XCTAssertEqual(TheseusConfiguration().theme.neutralBodyScale, 1.0)
        var lensTheme = TheseusTheme()
        lensTheme.neutralBodyScale = 0.15
        XCTAssertEqual(lensTheme.neutralBodyScale, 0.15)
    }

    // MARK: - Blur Radius Clamping by Quality

    func testEffectiveBlurRadiusClampedByQuality() {
        var config = TheseusConfiguration()
        config.blur.radius = 50.0

        // Low quality maxBlurRadius = 16
        XCTAssertEqual(config.effectiveBlurRadius(for: .low), 16)

        // Medium quality maxBlurRadius = 32
        XCTAssertEqual(config.effectiveBlurRadius(for: .medium), 32)

        // High quality maxBlurRadius = 64
        XCTAssertEqual(config.effectiveBlurRadius(for: .high), 50)

        // Ultra quality maxBlurRadius = 100
        config.blur.radius = 80.0
        XCTAssertEqual(config.effectiveBlurRadius(for: .ultra), 80)

        // Small value shouldn't be clamped
        config.blur.radius = 5.0
        XCTAssertEqual(config.effectiveBlurRadius(for: .low), 5)
    }
}
