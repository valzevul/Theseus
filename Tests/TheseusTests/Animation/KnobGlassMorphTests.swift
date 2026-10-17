import XCTest
@testable import Theseus

final class KnobGlassMorphTests: XCTestCase {

    private func run(_ morph: inout KnobGlassMorph, for seconds: TimeInterval) -> (peak: CGFloat, low: CGFloat) {
        var peak = morph.lens
        var low = morph.lens
        var time: TimeInterval = 0
        while time < seconds {
            morph.step(by: 1.0 / 120.0)
            peak = max(peak, morph.lens)
            low = min(low, morph.lens)
            time += 1.0 / 120.0
        }
        return (peak, low)
    }

    func testHeldPressOvershootsAndSettlesOnTheGlass() {
        var morph = KnobGlassMorph(springs: KnobGlassMorph.switchSprings)
        morph.press()
        let run = run(&morph, for: 0.6)
        XCTAssertEqual(run.peak, 1.12, accuracy: 0.03)
        XCTAssertEqual(morph.lens, 1, accuracy: 0.01)
        XCTAssertEqual(morph.fill, 0, accuracy: 0.01)
    }

    func testReleaseUndershootsTheKnobAndWhitens() {
        var morph = KnobGlassMorph(springs: KnobGlassMorph.switchSprings)
        morph.press()
        _ = run(&morph, for: 0.8)
        morph.release()
        let run = run(&morph, for: 0.6)
        XCTAssertEqual(run.low, -0.047, accuracy: 0.02)
        XCTAssertEqual(morph.fill, 1, accuracy: 0.01)
        XCTAssertGreaterThan(morph.releasedFor, 0.59)
    }

    func testIOS26ReleaseWhitensWithTheShrink() {
        var morph = KnobGlassMorph(springs: KnobGlassMorph.switchSprings26)
        morph.press()
        _ = run(&morph, for: 0.8)
        morph.release()
        var maximum: CGFloat = 0
        for _ in 0..<72 {
            morph.step(by: 1.0 / 120.0)
            XCTAssertEqual(morph.fill, 1 - morph.lens, accuracy: 1e-9)
            maximum = max(maximum, morph.fill)
        }
        XCTAssertEqual(maximum, 1.047, accuracy: 0.02)
    }

    func testQuickTapStillInflatesTheGlass() {
        var morph = KnobGlassMorph(springs: KnobGlassMorph.switchSprings)
        morph.press()
        morph.step(by: 1.0 / 60.0)
        morph.release()
        let run = run(&morph, for: 0.4)
        XCTAssertGreaterThan(run.peak, 0.5)
        XCTAssertLessThan(morph.lens, 0.05)
    }

    func testPressOnAReleasingGlassKeepsItsState() {
        var morph = KnobGlassMorph(springs: KnobGlassMorph.switchSprings)
        morph.press()
        _ = run(&morph, for: 0.8)
        morph.release()
        _ = run(&morph, for: 0.05)
        let lens = morph.lens
        morph.press()
        XCTAssertEqual(morph.lens, lens, accuracy: 0.0001)
        XCTAssertEqual(morph.phase, .pressing)
    }
}
