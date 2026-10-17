import XCTest
@testable import Theseus

final class GlassRimTests: XCTestCase {

    private func grey(_ level: CGFloat, _ face: TheseusConfiguration.GlassRim.Face) -> CGFloat {
        face.apply([level / 255, level / 255, level / 255])[1] * 255
    }

    func testRegularFaceMatchesNativeGreysInBothAppearances() {
        let light = TheseusConfiguration.GlassRim.regular.face(isDark: false, tintAmount: 0.5)
        XCTAssertEqual(grey(10, light), 138, accuracy: 1)
        XCTAssertEqual(grey(128, light), 195, accuracy: 1)
        XCTAssertEqual(grey(245, light), 249, accuracy: 1)
        let dark = TheseusConfiguration.GlassRim.regular.face(isDark: true, tintAmount: 0.5)
        XCTAssertEqual(grey(10, dark), 41, accuracy: 1)
        XCTAssertEqual(grey(80, dark), 100, accuracy: 1)
        XCTAssertEqual(grey(128, dark), 131, accuracy: 1)
        XCTAssertEqual(grey(176, dark), 154, accuracy: 1)
        XCTAssertEqual(grey(245, dark), 174, accuracy: 1)
    }

    func testRegularFaceKeepsNativeChroma() {
        let orange: [CGFloat] = [200 / 255, 80 / 255, 40 / 255]
        let light = TheseusConfiguration.GlassRim.regular.face(isDark: false, tintAmount: 0.5).apply(orange).map { $0 * 255 }
        XCTAssertEqual(light[0], 255, accuracy: 1)
        XCTAssertEqual(light[1], 162, accuracy: 1)
        XCTAssertEqual(light[2], 124, accuracy: 1)
        let dark = TheseusConfiguration.GlassRim.regular.face(isDark: true, tintAmount: 0.5).apply(orange).map { $0 * 255 }
        XCTAssertEqual(dark[0], 226, accuracy: 1)
        XCTAssertEqual(dark[1], 91, accuracy: 1)
        XCTAssertEqual(dark[2], 46, accuracy: 1)
    }

    func testClearFaceIsGainPlusLift() {
        let face = TheseusConfiguration.GlassRim.clear.face(isDark: true, tintAmount: 0.5)
        XCTAssertEqual(grey(32, face), 0.955 * 32 + 31.9, accuracy: 0.5)
        XCTAssertEqual(grey(200, face), 0.955 * 200 + 31.9, accuracy: 0.5)
    }

    func testTintAmountMovesTheFillAndTheFrost() {
        let rim = TheseusConfiguration.GlassRim.regular
        XCTAssertEqual(rim.face(isDark: false, tintAmount: 0).fill.w, 0)
        XCTAssertEqual(rim.face(isDark: false, tintAmount: 1).fill.w, 0.5, accuracy: 1e-6)
        XCTAssertEqual(rim.face(isDark: true, tintAmount: 0).maxLuma, 0.5775, accuracy: 1e-9)
        XCTAssertEqual(rim.frost(tintAmount: 0).blend, 0.675, accuracy: 1e-9)
        XCTAssertEqual(rim.frost(tintAmount: 0.75).cover, 0.75, accuracy: 1e-9)
        XCTAssertEqual(TheseusConfiguration.GlassRim.clear.frost(tintAmount: 0.5).cover, 0)
        XCTAssertEqual(TheseusConfiguration.GlassRim.clear.frost(tintAmount: 1).cover, 1)
    }

    func testOuterRefractionFollowsTheShortSide() {
        let small = TheseusConfiguration.GlassRim.outerRefraction(shortSide: 40)
        XCTAssertEqual(small.amount, 16)
        XCTAssertEqual(small.height, 16)
        let large = TheseusConfiguration.GlassRim.outerRefraction(shortSide: 100)
        XCTAssertEqual(large.amount, 25)
        XCTAssertEqual(large.height, 20)
    }

    private func assertRows(_ matrix: TheseusConfiguration.GlassRim.TintMatrix, _ expected: [[Float]], file: StaticString = #filePath, line: UInt = #line) {
        for (row, values) in zip([matrix.red, matrix.green, matrix.blue], expected) {
            let lumaShare = values[0] / 0.2126
            XCTAssertEqual(row.x, values[0], accuracy: 1e-4, file: file, line: line)
            XCTAssertEqual(row.y, values.count == 2 ? lumaShare * 0.7152 : values[1], accuracy: values.count == 2 ? 3e-4 : 1e-4, file: file, line: line)
            XCTAssertEqual(row.w, values.last!, accuracy: 1e-4, file: file, line: line)
        }
    }

    private func tint(_ hex: UInt32, dark: Bool) -> TheseusConfiguration.GlassRim.TintMatrix {
        TheseusConfiguration.GlassRim.tintMatrix(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            isDark: dark
        )
    }

    func testLightTintMatchesNativeMatrices() {
        assertRows(tint(0xFF0000, dark: false), [[0.0850, 0.6000], [0, 0], [0, 0]])
        assertRows(tint(0x3399FF, dark: false), [[0.0500, -0.0353], [0.0600, 0.3176], [0.0520, 0.7553]])
        assertRows(tint(0xE6F2FF, dark: false), [[0.2118, -0.0941], [0.0998, 0.4796], [0, 1]])
        assertRows(tint(0x34C759, dark: false), [[0.0291, 0.0673], [0.0694, 0.4538], [0.0392, 0.1646]])
    }

    func testDarkTintMatchesNativeMatrices() {
        assertRows(tint(0xFF0000, dark: true), [[-0.0080, 1.0056], [0.0434, -0.0306], [0.0434, -0.0306]])
        assertRows(tint(0xCC0000, dark: true), [[0.0206, 0.7855], [0.0078, -0.0055], [0.0078, -0.0055]])
        assertRows(tint(0xE6F2FF, dark: true), [[0.0347, 0.8775], [0.0181, 0.9363], [0, 1]])
        assertRows(tint(0x0088FF, dark: true), [[0.0434, -0.0306], [0.0160, 0.5220], [-0.0080, 1.0056]])
    }

    func testGreyTintScalesEachChannel() {
        for dark in [false, true] {
            let white = tint(0xFFFFFF, dark: dark)
            XCTAssertEqual(white.red, SIMD4<Float>(0.3125, 0, 0, 0.9375))
            XCTAssertEqual(white.blue, SIMD4<Float>(0, 0, 0.3125, 0.9375))
            let black = tint(0x000000, dark: dark)
            XCTAssertEqual(black.green, SIMD4<Float>(0, 0.3125, 0, -0.25))
            let mid = tint(0x808080, dark: dark)
            XCTAssertEqual(mid.red.x, 0.3086, accuracy: 1e-4)
            XCTAssertEqual(mid.red.w, 0.3418, accuracy: 1e-4)
        }
    }

    func testTintMatrixKeepsHeadroomAboveWhite() {
        XCTAssertEqual(tint(0xE6F2FF, dark: true).apply([1, 1, 1])[0], 1.0409, accuracy: 1e-3)
        XCTAssertEqual(tint(0xE6F2FF, dark: false).apply([0, 0, 0])[0], 0)
    }

    func testIOS26FaceMatchesNativeGreysAndColours() {
        let rim = TheseusConfiguration.GlassRim.regular
        XCTAssertEqual(grey(128, rim.face(isDark: false, tintAmount: 0, style: .iOS26)), 213, accuracy: 1)
        XCTAssertEqual(grey(128, rim.face(isDark: false, tintAmount: 1, style: .iOS26)), 230, accuracy: 1)
        XCTAssertEqual(grey(128, rim.face(isDark: true, tintAmount: 0, style: .iOS26)), 60, accuracy: 1)
        XCTAssertEqual(grey(128, rim.face(isDark: true, tintAmount: 1, style: .iOS26)), 47, accuracy: 1)
        let warm = rim.face(isDark: true, tintAmount: 1, style: .iOS26).apply([192.0 / 255, 64.0 / 255, 32.0 / 255]).map { $0 * 255 }
        XCTAssertEqual(warm[0], 119, accuracy: 1.5)
        XCTAssertEqual(warm[1], 19, accuracy: 1)
        let clearWarm = TheseusConfiguration.GlassRim.clear.face(isDark: false, tintAmount: 0, style: .iOS26).apply([192.0 / 255, 64.0 / 255, 32.0 / 255]).map { $0 * 255 }
        XCTAssertEqual(clearWarm[0], 217, accuracy: 1)
        XCTAssertEqual(clearWarm[2], 53, accuracy: 1)
        XCTAssertEqual(rim.face(isDark: false, tintAmount: 0.3, style: .iOS27), rim.face(isDark: false, tintAmount: 0.3))
        XCTAssertEqual(TheseusConfiguration.GlassRim.frostAmount(spectrum: 1, style: .iOS26), 0.5)
        XCTAssertEqual(TheseusConfiguration.GlassRim.frostAmount(spectrum: 0.8, style: .iOS27), 0.8)
    }

    func testDropShadowFollowsTheNativeSizeLaws() {
        let rim = TheseusConfiguration.GlassRim.regular
        XCTAssertEqual(rim.dropShadowAmount(isDark: false, shortSide: 40), 0.012, accuracy: 1e-9)
        XCTAssertEqual(rim.dropShadowAmount(isDark: false, shortSide: 70), 0.01875, accuracy: 1e-9)
        XCTAssertEqual(rim.dropShadowAmount(isDark: true, shortSide: 70), 0.0225, accuracy: 1e-9)
        XCTAssertEqual(rim.dropShadowAmount(isDark: false, shortSide: 200), 0.12, accuracy: 1e-9)
        XCTAssertEqual(rim.dropShadowAmount(isDark: true, shortSide: 160), 0.18, accuracy: 1e-9)
        let iOS26 = rim.styled(.iOS26)
        XCTAssertEqual(iOS26.dropShadowAmount(isDark: true, shortSide: 50), 0.07, accuracy: 1e-9)
        XCTAssertEqual(iOS26.dropShadowAmount(isDark: false, shortSide: 70), 0.105, accuracy: 1e-9)
        XCTAssertEqual(iOS26.dropShadowAmount(isDark: true, shortSide: 85), 0.0795, accuracy: 1e-9)
        XCTAssertEqual(iOS26.dropShadowAmount(isDark: true, shortSide: 300), 0.155, accuracy: 1e-9)
        XCTAssertEqual(TheseusConfiguration.GlassRim.clear.dropShadowAmount(isDark: false, shortSide: 100), 0)
        XCTAssertEqual(TheseusConfiguration.GlassRim.clear.styled(.iOS26).dropShadowAmount(isDark: false, shortSide: 100), 0)
    }

    func testDrawableGrowsUntilTheDropShadowFits() {
        let regular = TheseusConfiguration.regular
        XCTAssertEqual(regular.drawPadding(for: CGSize(width: 170, height: 70), style: .iOS27), regular.shape.padding)
        XCTAssertEqual(regular.drawPadding(for: CGSize(width: 240, height: 160), style: .iOS27), CGPoint(x: 35, y: 43))
        XCTAssertEqual(regular.drawPadding(for: CGSize(width: 170, height: 70), style: .iOS26), CGPoint(x: 35, y: 43))
        let clear = TheseusConfiguration.clear
        XCTAssertEqual(clear.drawPadding(for: CGSize(width: 170, height: 70), style: .iOS26), clear.shape.padding)
    }

    func testIOS26StyleSwapsInIOS26Glass() {
        let rim = TheseusConfiguration.GlassRim.regular.styled(.iOS26)
        XCTAssertEqual(rim.generation, .iOS26)
        XCTAssertEqual(rim.ringShadowOpacity, 0)
        XCTAssertEqual(rim.frost(tintAmount: 1).cover, 0)
        XCTAssertEqual(rim.blurRadiusDeep, 1)
        XCTAssertEqual(rim.highlight(isDark: false), SIMD3<Float>(0.1, 15, 0.9))
        XCTAssertEqual(rim.highlight(isDark: true).x, 1.35, accuracy: 1e-6)
        let inner = rim.innerRefraction(shortSide: 70)
        XCTAssertEqual(inner?.amount ?? 0, 56, accuracy: 1e-9)
        XCTAssertEqual(inner?.height ?? 0, 17.5, accuracy: 1e-9)
        XCTAssertEqual(rim.outerRefraction(shortSide: 70).amount, 14, accuracy: 1e-9)
        XCTAssertEqual(TheseusConfiguration.GlassRim.clear.styled(.iOS26).innerRefraction(shortSide: 70)?.amount ?? 0, 60, accuracy: 1e-9)
        XCTAssertEqual(TheseusConfiguration.GlassRim.regular.styled(.iOS27), TheseusConfiguration.GlassRim.regular)
    }
}
