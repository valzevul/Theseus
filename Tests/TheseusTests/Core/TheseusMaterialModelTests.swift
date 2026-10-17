import XCTest
@testable import Theseus

final class TheseusMaterialModelTests: XCTestCase {

    private func value(_ input: CGFloat, isDark: Bool, configuration: TheseusConfiguration = .regular) -> CGFloat {
        TheseusMaterialModel.bodyValue(input, configuration: configuration, isDark: isDark, spectrum: 0.5) * 255
    }

    func testLightRegularMatchesNativeGreys() {
        XCTAssertEqual(value(10 / 255, isDark: false), 140, accuracy: 3)
        XCTAssertEqual(value(128 / 255, isDark: false), 195, accuracy: 3)
        XCTAssertEqual(value(245 / 255, isDark: false), 250, accuracy: 3)
    }

    private func value(_ input: CGFloat, isDark: Bool, spectrum: CGFloat, style: TheseusSettings.GlassStyle) -> CGFloat {
        TheseusMaterialModel.bodyValue(input, configuration: .regular, isDark: isDark, spectrum: spectrum, style: style) * 255
    }

    func testTintAmountMovesRegularGlassLikeIOS27() {
        XCTAssertEqual(value(0, isDark: false, spectrum: 0, style: .iOS27), 102, accuracy: 2)
        XCTAssertEqual(value(176 / 255, isDark: false, spectrum: 0, style: .iOS27), 208, accuracy: 2)
        XCTAssertEqual(value(0, isDark: false, spectrum: 1, style: .iOS27), 178, accuracy: 2)
        XCTAssertEqual(value(176 / 255, isDark: false, spectrum: 1, style: .iOS27), 231, accuracy: 2)
        XCTAssertEqual(value(176 / 255, isDark: true, spectrum: 0, style: .iOS27), value(176 / 255, isDark: true, spectrum: 0.5, style: .iOS27), accuracy: 0.01)
        XCTAssertEqual(value(1, isDark: true, spectrum: 1, style: .iOS27), 103, accuracy: 3)
        XCTAssertEqual(value(176 / 255, isDark: true, spectrum: 1, style: .iOS27), 93, accuracy: 3)
        XCTAssertEqual(value(1, isDark: true, spectrum: 0.75, style: .iOS27), 135, accuracy: 3)
    }

    func testClearAndTintedMatchIOS26() {
        XCTAssertEqual(value(0, isDark: false, spectrum: 0, style: .iOS26), 174, accuracy: 2)
        XCTAssertEqual(value(174 / 255, isDark: false, spectrum: 0, style: .iOS26), 228, accuracy: 2)
        XCTAssertEqual(value(0, isDark: false, spectrum: 1, style: .iOS26), 210, accuracy: 2)
        XCTAssertEqual(value(174 / 255, isDark: false, spectrum: 1, style: .iOS26), 237, accuracy: 2)
        XCTAssertEqual(value(0, isDark: true, spectrum: 0, style: .iOS26), 29, accuracy: 2)
        XCTAssertEqual(value(254 / 255, isDark: true, spectrum: 0, style: .iOS26), 89, accuracy: 2)
        XCTAssertEqual(value(254 / 255, isDark: true, spectrum: 1, style: .iOS26), 75, accuracy: 2)
    }

    func testTintAmountLeavesClearGlassAlone() {
        let clear = TheseusConfiguration.clear
        let low = TheseusMaterialModel.bodyValue(0.4, configuration: clear, isDark: false, spectrum: 0, style: .iOS27)
        let high = TheseusMaterialModel.bodyValue(0.4, configuration: clear, isDark: false, spectrum: 1, style: .iOS27)
        XCTAssertEqual(low, high, accuracy: 0.0001)
    }

    func testDarkRegularMatchesNativeGreys() {
        XCTAssertEqual(value(10 / 255, isDark: true), 41, accuracy: 2)
        XCTAssertEqual(value(80 / 255, isDark: true), 100, accuracy: 2)
        XCTAssertEqual(value(128 / 255, isDark: true), 131, accuracy: 2)
        XCTAssertEqual(value(176 / 255, isDark: true), 154, accuracy: 2)
        XCTAssertEqual(value(245 / 255, isDark: true), 174, accuracy: 2)
    }

    func testClearIsGainPlusLiftInBothAppearances() {
        let clear = TheseusConfiguration.clear
        for isDark in [false, true] {
            XCTAssertEqual(value(10 / 255, isDark: isDark, configuration: clear), 41, accuracy: 3)
            XCTAssertEqual(value(128 / 255, isDark: isDark, configuration: clear), 153, accuracy: 3)
        }
    }

    func testVeilMatchesALiftedDarkBarAtItsBackdropMean() {
        var configuration = TheseusConfiguration()
        configuration.theme.neutralBodyScale = 1.0
        configuration.theme.backdropGain = 1.02
        configuration.theme.luminanceLift = 0.047
        let backdrop: CGFloat = 0.19
        let veil = TheseusMaterialModel.veilColor(configuration: configuration, isDark: true, spectrum: 0.5, backdropLuminance: backdrop)
        var white: CGFloat = 0, alpha: CGFloat = 0
        veil.getWhite(&white, alpha: &alpha)
        let composited = (1 - alpha) * backdrop + alpha * white
        XCTAssertEqual(composited, TheseusMaterialModel.bodyValue(backdrop, configuration: configuration, isDark: true, spectrum: 0.5), accuracy: 0.005)
        XCTAssertLessThanOrEqual(white, 1.001)
    }

    func testVeilLinearisesTheBodyAroundTheBackdrop() {
        let veil = TheseusMaterialModel.veilColor(configuration: .regular, isDark: true, spectrum: 0.5, backdropLuminance: 0.2)
        var white: CGFloat = 0, alpha: CGFloat = 0
        veil.getWhite(&white, alpha: &alpha)
        let backdrop: CGFloat = 0.2
        let composited = (1 - alpha) * backdrop + alpha * white
        XCTAssertEqual(composited, TheseusMaterialModel.bodyValue(backdrop, configuration: .regular, isDark: true, spectrum: 0.5), accuracy: 0.01)
    }

    func testChromaScaleFollowsAppearanceAndFadesWithTheBody() {
        XCTAssertEqual(TheseusMaterialModel.chromaScale(configuration: .regular, isDark: false, spectrum: 0.5), 0.937, accuracy: 0.001)
        XCTAssertEqual(TheseusMaterialModel.chromaScale(configuration: .regular, isDark: true, spectrum: 0.5), 1.043, accuracy: 0.001)
        XCTAssertEqual(TheseusMaterialModel.chromaScale(configuration: .clear, isDark: true, spectrum: 0.5), 1.11, accuracy: 0.001)
    }

    func testBodyStrengthIsOneAtTheSystemDefault() {
        XCTAssertEqual(TheseusMaterialModel.bodyStrength(configuration: .regular, spectrum: 0.5), 1.0, accuracy: 0.0001)
        XCTAssertEqual(TheseusMaterialModel.bodyStrength(configuration: .clear, spectrum: 0.5), 0.0, accuracy: 0.0001)
    }

    private func tinted(_ tint: [CGFloat], backdrop: CGFloat, isDark: Bool, alpha: CGFloat = 0.8, spectrum: CGFloat = 0.5) -> [CGFloat] {
        let body = TheseusMaterialModel.bodyValue(backdrop / 255, configuration: .regular, isDark: isDark, spectrum: spectrum, style: .iOS27)
        return TheseusMaterialModel.tinted(
            tint.map { $0 / 255 },
            alpha: alpha,
            body: [body, body, body],
            model: TheseusMaterialModel.tintModel(isDark: isDark)
        ).map { $0 * 255 }
    }

    private func assertClose(_ values: [CGFloat], _ native: [CGFloat], accuracy: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        for (value, expected) in zip(values, native) {
            XCTAssertEqual(value, expected, accuracy: accuracy, file: file, line: line)
        }
    }

    func testDarkTintClosesOnItsStrongestChannelOverABrightBody() {
        assertClose(tinted([255, 66, 69], backdrop: 10, isDark: true), [212, 61, 64], accuracy: 3)
        assertClose(tinted([255, 66, 69], backdrop: 245, isDark: true), [236, 113, 115], accuracy: 9)
        assertClose(tinted([142, 142, 147], backdrop: 245, isDark: true), [159, 159, 163], accuracy: 7)
    }

    func testLightTintDarkensWithTheBodysShortfallFromWhite() {
        assertClose(tinted([52, 199, 89], backdrop: 10, isDark: false), [56, 156, 81], accuracy: 5)
        assertClose(tinted([255, 204, 0], backdrop: 10, isDark: false), [195, 160, 28], accuracy: 5)
        assertClose(tinted([255, 56, 60], backdrop: 245, isDark: false), [253, 93, 96], accuracy: 3)
    }

    func testTintKeepsItsShapeAcrossAlphaAndTintAmount() {
        assertClose(tinted([0, 136, 255], backdrop: 0, isDark: false, alpha: 0.4), [83, 126, 166], accuracy: 5)
        assertClose(tinted([0, 136, 255], backdrop: 0, isDark: false, spectrum: 1), [36, 130, 216], accuracy: 6)
        assertClose(tinted([0, 145, 255], backdrop: 255, isDark: true, spectrum: 1), [32, 140, 223], accuracy: 6)
    }
}
