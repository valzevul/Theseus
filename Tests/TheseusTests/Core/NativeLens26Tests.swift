import XCTest
@testable import Theseus

final class NativeLens26Tests: XCTestCase {

    private func assertRows(_ rows: [SIMD4<Float>], _ expected: [Float], file: StaticString = #filePath, line: UInt = #line) {
        let flat = rows.flatMap { [$0.x, $0.y, $0.z, $0.w] }
        for (value, target) in zip(flat, expected) {
            XCTAssertEqual(value, target, accuracy: 0.002, file: file, line: line)
        }
    }

    func testTintMatrixMatchesTheNativeKnobHighlights() {
        assertRows(NativeLens26.tintMatrix(SIMD4(0, 0.533, 1, 1)), [2.0173, -1.2875, -0.1298, -0.6000, -0.2496, 0.7256, -0.0848, -0.0435, -0.1914, -0.6436, 1.1350, 0.2000])
        assertRows(NativeLens26.tintMatrix(SIMD4(0.204, 0.780, 0.349, 1)), [1.6756, -1.0695, -0.1078, -0.3290, -0.2149, 0.6249, -0.0730, 0.1013, -0.2838, -0.9542, 1.6827, -0.1860])
        assertRows(NativeLens26.tintMatrix(SIMD4(0.796, 0.188, 0.878, 1)), [1.1232, -0.7169, -0.0723, 0.1092, -0.3220, 0.9364, -0.1094, -0.3465, -0.2038, -0.6853, 1.2085, 0.1482])
        assertRows(NativeLens26.tintMatrix(SIMD4(1.0, 0.553, 0.157, 1)), [1.0087, -0.6438, -0.0649, 0.2000, -0.2464, 0.7165, -0.0837, -0.0303, -0.3309, -1.1127, 1.9622, -0.3831])
    }

    func testTintMatrixReadsTheTranslucentOffTrack() {
        assertRows(NativeLens26.tintMatrix(SIMD4(60.0 / 255, 60.0 / 255, 67.0 / 255, 0.298)), [2.8881, -1.8433, -0.1858, -1.2906, -0.5478, 1.5929, -0.1861, -1.2906, -0.5137, -1.7273, 3.0461, -1.1470])
        assertRows(NativeLens26.tintMatrix(SIMD4(235.0 / 255, 235.0 / 255, 245.0 / 255, 0.298)), [1.0808, -0.6898, -0.0695, 0.1428, -0.2050, 0.5961, -0.0696, 0.1428, -0.1980, -0.6658, 1.1742, 0.1724])
    }

    func testShadowFillMatchesTheNativeKnobs() {
        let cases: [(SIMD4<Float>, SIMD3<Float>)] = [
            (SIMD4(60.0 / 255, 60.0 / 255, 67.0 / 255, 0.298), SIMD3(0.4438, 0.4438, 0.4562)),
            (SIMD4(235.0 / 255, 235.0 / 255, 245.0 / 255, 0.298), SIMD3(0.4125, 0.4125, 0.4875)),
            (SIMD4(0.259, 0.831, 0.318, 1), SIMD3(0.3793, 0.5207, 0.3939)),
            (SIMD4(0, 0.533, 1, 1), SIMD3(0.3375, 0.4575, 0.5625)),
            (SIMD4(0.796, 0.188, 0.878, 1), SIMD3(0.5133, 0.3668, 0.5332)),
            (SIMD4(1.0, 0.553, 0.157, 1), SIMD3(0.5625, 0.4432, 0.3375))
        ]
        for (tint, fill) in cases {
            let value = NativeLens26.shadowFill(tint)
            XCTAssertEqual(value.x, fill.x, accuracy: 0.002)
            XCTAssertEqual(value.y, fill.y, accuracy: 0.002)
            XCTAssertEqual(value.z, fill.z, accuracy: 0.002)
        }
    }

    func testKnobRecipeFollowsTheNativeSizeLaws() {
        let lens = NativeLens26.knob(height: 38.333, tint: .systemGreen, traits: UITraitCollection(userInterfaceStyle: .light))
        XCTAssertEqual(lens.aberration, 2.017544, accuracy: 0.0001)
        XCTAssertEqual(lens.aberrationOffset, 21.2963, accuracy: 0.001)
        XCTAssertEqual(lens.edgeStart, -7.666667, accuracy: 0.0001)
        XCTAssertEqual(lens.highlights.count, 2)
        XCTAssertEqual(lens.highlights[0].key.x, -0.70711, accuracy: 0.0001)
        XCTAssertEqual(lens.highlights[0].key.y, -0.70711, accuracy: 0.0001)
        XCTAssertEqual(lens.highlights[0].remap, 0, accuracy: 0.0001)
        XCTAssertEqual(lens.highlights[1].remap, 2, accuracy: 0.0001)
        XCTAssertEqual(lens.shadowReach.y, 23)
    }

    func testTabLensRecipeUsesTheFillLightForBothKeys() {
        let lens = NativeLens26.tabLens(height: 70, traits: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertEqual(lens.aberration, 70.0 / 19, accuracy: 0.0001)
        XCTAssertEqual(lens.edgeStart, -14, accuracy: 0.0001)
        XCTAssertEqual(lens.faceBlack, 0)
        XCTAssertEqual(lens.blurRadius, 0)
        XCTAssertEqual(lens.shadowOpacity, 0.1)
        XCTAssertEqual(lens.shadowFaceOpacity, 1.1114286, accuracy: 0.000001)
        XCTAssertEqual(lens.highlights.map(\.matrix), [NativeLens26.fillMatrixDark, NativeLens26.fillMatrixDark])
        XCTAssertEqual(lens.baseHeight, 70)
    }
}
