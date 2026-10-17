import XCTest
@testable import Theseus

final class FlexGlowTests: XCTestCase {

    private func levels(_ c: SIMD3<Float>) -> SIMD3<Float> {
        c * 255
    }

    func testMatrixMatchesTheNativeBigGlow() {
        let expected: [[Float]] = [
            [1.1575, -0.1431, -0.0144, 0.05],
            [-0.0425, 1.0570, -0.0145, 0.05],
            [-0.0426, -0.1430, 1.1856, 0.05]
        ]
        for (row, target) in zip(FlexGlow.matrix, expected) {
            XCTAssertEqual(row.x, target[0], accuracy: 0.0002)
            XCTAssertEqual(row.y, target[1], accuracy: 0.0002)
            XCTAssertEqual(row.z, target[2], accuracy: 0.0002)
            XCTAssertEqual(row.w, target[3], accuracy: 0.0002)
        }
    }

    func testBigGlowLiftsTheLightGlyphsAsNativeDoes() {
        let glow = FlexGlow(amount: FlexGlow.alpha)
        let glyph = levels(glow.applied(to: SIMD3(37, 20, 28) / 255, spot: 0))
        XCTAssertEqual(glyph.x, 50, accuracy: 0.6)
        XCTAssertEqual(glyph.y, 30, accuracy: 0.6)
        XCTAssertEqual(glyph.z, 39, accuracy: 0.6)
    }

    func testBigGlowLiftsTheDarkBody() {
        let glow = FlexGlow(amount: FlexGlow.alpha)
        let body = levels(glow.applied(to: SIMD3(36, 33, 45) / 255, spot: 0))
        XCTAssertEqual(body.x, 47.0, accuracy: 0.3)
        XCTAssertEqual(body.y, 43.5, accuracy: 0.3)
        XCTAssertEqual(body.z, 57.5, accuracy: 0.3)
    }

    func testSpotLaysPlainWhiteOverTheGlass() {
        let glow = FlexGlow()
        let c = SIMD3<Float>(0.2, 0.1, 0.15)
        let lit = glow.applied(to: c, spot: 0.04)
        XCTAssertEqual(lit.x, 0.2 + 0.04 * 0.8, accuracy: 1e-6)
        XCTAssertEqual(lit.y, 0.1 + 0.04 * 0.9, accuracy: 1e-6)
        XCTAssertEqual(lit.z, 0.15 + 0.04 * 0.85, accuracy: 1e-6)
    }

    func testSpotCoverageIsTheBlurredDisc() {
        let glow = FlexGlow(spotAmount: FlexGlow.spotAlpha, spotCenter: CGPoint(x: 100, y: 30), spotRadius: 93)
        XCTAssertEqual(glow.spotCoverage(at: CGPoint(x: 100, y: 30)), FlexGlow.spotAlpha * FlexGlow.spotPeak, accuracy: 1e-9)
        let width = FlexGlow.spotWidth * 93
        XCTAssertEqual(glow.spotCoverage(at: CGPoint(x: 100 + width, y: 30)), FlexGlow.spotAlpha * FlexGlow.spotPeak * exp(-0.5), accuracy: 1e-9)
    }

    func testSpotHalvesOnceTheFingerTravels() {
        XCTAssertEqual(FlexGlow.spotAlpha / 2, 0.142, accuracy: 0.0005)
        XCTAssertEqual(FlexGlow.alpha * 0.336, FlexGlow.spotAlpha, accuracy: 0.0005)
        XCTAssertEqual(FlexGlow.spotTravel, 50)
        XCTAssertEqual(FlexGlow.spotReleaseScale, 4)
    }
}
