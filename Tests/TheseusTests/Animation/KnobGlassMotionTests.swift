import XCTest
@testable import Theseus

final class KnobGlassMotionTests: XCTestCase {

    func testGlassTrailsAMovingFingerLikeNative() {
        var motion = KnobGlassMotion(at: 0)
        let speed: CGFloat = 33.3
        var time: CGFloat = 0
        var most: CGFloat = 0
        while time < 1.0 {
            time += 1.0 / 60.0
            motion.target = speed * time
            motion.step(by: 1.0 / 60.0)
            most = max(most, motion.stretch)
        }
        XCTAssertEqual(motion.target - motion.position, 3.6, accuracy: 0.4)
        XCTAssertEqual(most, 0.004, accuracy: 0.003)
    }

    func testGlassSettlesOnAStillFinger() {
        var motion = KnobGlassMotion(at: 0)
        motion.target = 10
        for _ in 0..<120 {
            motion.step(by: 1.0 / 60.0)
        }
        XCTAssertEqual(motion.position, 10, accuracy: 0.05)
        XCTAssertTrue(motion.isSettled)
        XCTAssertEqual(motion.scale.x, 1, accuracy: 0.001)
    }

    func testStoppingSquashesTheGlass() {
        var motion = KnobGlassMotion(at: 0)
        for frame in 1...30 {
            motion.target = CGFloat(frame) * 4
            motion.step(by: 1.0 / 60.0)
        }
        var least: CGFloat = 0
        for _ in 0..<40 {
            motion.step(by: 1.0 / 60.0)
            least = min(least, motion.stretch)
        }
        XCTAssertLessThan(least, -0.002)
    }

    func testReleaseSwingMatchesTheNativeFlight() {
        let distance: CGFloat = 31.17
        XCTAssertEqual(KnobGlassMotion.releaseStretch(at: 0.03, distance: distance), 0)
        XCTAssertEqual(KnobGlassMotion.releaseStretch(at: 0.233, distance: distance), 0.039, accuracy: 0.006)
        XCTAssertEqual(KnobGlassMotion.releaseStretch(at: 0.466, distance: distance), -0.028, accuracy: 0.006)
        XCTAssertEqual(KnobGlassMotion.releaseStretch(at: 0.75, distance: distance), 0)
        XCTAssertEqual(
            KnobGlassMotion.releaseStretch(at: 0.216, distance: 9.5),
            KnobGlassMotion.releaseStretch(at: 0.216, distance: -9.5)
        )
    }

    func testAnchoredStretchHoldsTheLeadingEdge() {
        let width: CGFloat = 37
        let transform = KnobGlassMotion.anchoredStretch(-0.0287, width: width, direction: -1)
        let leading = -width / 2 * transform.m11 + transform.m41
        let trailing = width / 2 * transform.m11 + transform.m41
        XCTAssertEqual(leading, -width / 2, accuracy: 0.0001)
        XCTAssertEqual(trailing, width / 2 - 1.062, accuracy: 0.01)
        XCTAssertEqual(transform.m22, 1.0287, accuracy: 0.0001)
    }
}
