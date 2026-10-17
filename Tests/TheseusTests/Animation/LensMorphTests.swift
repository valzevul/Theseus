import XCTest
import QuartzCore
@testable import Theseus

final class LensMorphTests: XCTestCase {
    func testRectMappingScalesAboutTheCentreThenTranslates() {
        let glass = CGRect(x: 10, y: 20, width: 59.333, height: 39.667)
        let knob = CGRect(x: 21.333, y: 28, width: 37, height: 24)
        let transform = LensMorph.transform(mapping: glass, onto: knob)
        XCTAssertEqual(transform.m11, knob.width / glass.width, accuracy: 1e-6)
        XCTAssertEqual(transform.m22, knob.height / glass.height, accuracy: 1e-6)
        XCTAssertEqual(transform.m41, knob.midX - glass.midX, accuracy: 1e-6)
        XCTAssertEqual(transform.m42, knob.midY - glass.midY, accuracy: 1e-6)
        let back = LensMorph.transform(mapping: knob, onto: glass)
        let roundTrip = CATransform3DConcat(transform, back)
        XCTAssertEqual(roundTrip.m11, 1, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m22, 1, accuracy: 1e-6)
    }

    func testLerpInterpolatesTheFourAnimatedComponents() {
        let a = CATransform3DIdentity
        let b = LensMorph.transform(mapping: CGRect(x: 0, y: 0, width: 10, height: 10), onto: CGRect(x: 5, y: 5, width: 20, height: 30))
        let mid = LensMorph.lerp(a, b, 0.5)
        XCTAssertEqual(mid.m11, (1 + b.m11) / 2, accuracy: 1e-6)
        XCTAssertEqual(mid.m22, (1 + b.m22) / 2, accuracy: 1e-6)
        XCTAssertEqual(mid.m41, b.m41 / 2, accuracy: 1e-6)
        XCTAssertEqual(mid.m42, b.m42 / 2, accuracy: 1e-6)
    }

    func testCriticallyDampedSpringStartsAtRestAndSettles() {
        XCTAssertEqual(LensMorph.criticallyDamped(0, omega: 22), 0)
        XCTAssertEqual(LensMorph.criticallyDamped(0.013, omega: 22), 0.034, accuracy: 0.005)
        XCTAssertEqual(LensMorph.criticallyDamped(0.090, omega: 22), 0.59, accuracy: 0.02)
        XCTAssertEqual(LensMorph.criticallyDamped(0.5, omega: 22), 1.0, accuracy: 0.001)
        let samples = stride(from: 0.0, through: 0.5, by: 0.01).map { LensMorph.criticallyDamped($0, omega: 22) }
        XCTAssertEqual(samples, samples.sorted())
    }

    func testUnderdampedSpringOvershootsByTheFittedAmount() {
        let peak = (1...60).map { LensMorph.underdamped(Double($0) * 0.005, stiffness: 1330, damping: 40) }.max() ?? 0
        XCTAssertEqual(peak, 1.127, accuracy: 0.01)
        XCTAssertEqual(LensMorph.underdamped(0, stiffness: 1330, damping: 40), 0)
        XCTAssertEqual(LensMorph.underdamped(1.0, stiffness: 1330, damping: 40), 1.0, accuracy: 0.001)
        XCTAssertEqual(LensMorph.underdamped(0.1, stiffness: 900, damping: 60), LensMorph.criticallyDamped(0.1, omega: 30), accuracy: 1e-9)
    }

    func testEasingCurvesMatchCoreAnimation() {
        XCTAssertEqual(LensMorph.easeOut(0), 0)
        XCTAssertEqual(LensMorph.easeOut(1), 1)
        XCTAssertEqual(LensMorph.easeOut(0.256), 0.386, accuracy: 0.01)
        XCTAssertEqual(LensMorph.easeOut(0.5), 0.685, accuracy: 0.01)
        XCTAssertEqual(LensMorph.easeInOut(0.5), 0.5, accuracy: 0.01)
        XCTAssertEqual(LensMorph.easeInOut(0.25), 0.129, accuracy: 0.01)
        XCTAssertEqual(LensMorph.easeInOut(0.75), 0.871, accuracy: 0.01)
    }

    func testFadeHoldsTheStartValueUntilItsDelay() {
        let layer = CALayer()
        layer.opacity = 1
        LensMorph.fade(layer, from: 1, to: 0, duration: 0.1, delay: 0.2)
        let animation = layer.animation(forKey: "opacity") as? CABasicAnimation
        XCTAssertEqual(layer.opacity, 0)
        XCTAssertEqual(animation?.fillMode, .backwards)
        XCTAssertEqual(animation?.fromValue as? CGFloat, 1)
        XCTAssertGreaterThan(animation?.beginTime ?? 0, 0)
    }
}
